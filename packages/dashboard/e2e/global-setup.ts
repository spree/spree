import { type ChildProcess, spawn, spawnSync } from 'node:child_process'
import { unlinkSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { createAdminClient } from '@spree/admin-sdk'
import { deployConfig, loadConfig, renderReport, reportHasFailures } from '@spree/cli/config'
import {
  FIXTURE_BULK_CATEGORY_PERMALINK,
  FIXTURE_BULK_CHANNEL_CODE,
  FIXTURE_BULK_PRODUCT_A,
  FIXTURE_BULK_PRODUCT_N,
  FIXTURE_INVENTORY_PRODUCT,
  FIXTURE_INVENTORY_RESERVED,
  FIXTURE_INVENTORY_SKU,
  FIXTURE_LEDGER_OWED_AMOUNT,
  FIXTURE_LEDGER_PAYOUT_AMOUNT,
  FIXTURE_LEDGER_SELLER,
  FIXTURE_PROMO_CUSTOMER_EMAIL,
  FIXTURE_PROMO_CUSTOMER_FIRST_NAME,
  FIXTURE_PROMO_CUSTOMER_FULL_NAME,
  FIXTURE_PROMO_CUSTOMER_GROUP,
  FIXTURE_PROMO_PRODUCT,
  FIXTURE_PROMO_SKU,
  FIXTURE_PROMO_TAXON_PERMALINK,
  FIXTURE_SUPPLIER,
  FIXTURE_TRANSFER_DESTINATION,
  FIXTURE_TRANSFER_PRODUCT,
  FIXTURE_TRANSFER_SKU,
  FIXTURE_TRANSFER_SOURCE,
} from './helpers'
import { ASYNC_JOBS_INITIALIZER, CREDENTIALS_FILE, E2E_DIR, RAILS_PID_FILE } from './paths'

const API_GEM_DIR = resolve(E2E_DIR, '../../../spree/api')
const PORT = process.env.E2E_RAILS_PORT || '3010'
// Mirrors `spec/dummy/config/database.yml`.
const TEST_SQLITE = resolve(API_GEM_DIR, 'spec/dummy/db/spree_test.sqlite3')
const STORE_CONFIG = resolve(E2E_DIR, 'fixtures/store.yml')

const RAILS_ENV = { ...process.env, RAILS_ENV: 'test', PORT, DASHBOARD_E2E: '1' }

// The last name follows from the full name, so the fixture file and the
// `full_name` assertion in promotions.spec stay in step.
const FIXTURE_PROMO_CUSTOMER_LAST_NAME = FIXTURE_PROMO_CUSTOMER_FULL_NAME.replace(
  `${FIXTURE_PROMO_CUSTOMER_FIRST_NAME} `,
  '',
)

// What has no Admin API by design (docs/plans/6.0-store-context-and-first-run-setup.md):
// the seeds, the first admin, and a secret key for the deploy that follows.
const BOOTSTRAP_RUBY = [
  "load Rails.root.join('db', 'schema.rb').to_s",
  'Spree::Seeds::All.call',
  'require "json"',
  's = Spree::Store.default',
  'admin = Spree.admin_user_class.first || Spree.admin_user_class.create!(email: "admin@example.com", password: "spree123", password_confirmation: "spree123")',
  'admin.update!(password: "spree123", password_confirmation: "spree123")',
  's.add_user(admin, Spree::Role.default_admin_role(s)) unless s.role_users.exists?(user: admin)',
  // The deploy key: write_all so every section of the fixture file can be
  // written, printed once and never persisted anywhere else.
  'deploy_key = s.api_keys.create!(name: "e2e configurator", key_type: "secret", scopes: ["write_all"])',
  'port = ENV.fetch("PORT", 3010)',
  'puts JSON.generate(api_url: "http://localhost:#{port}", admin_email: admin.email, admin_password: "spree123", store_id: s.prefixed_id, store_name: s.name, deploy_token: deploy_key.plaintext_token)',
].join('; ')

// Transaction data the fixture file cannot carry (orders, payouts, transfers,
// a checkout's reservation): written directly once the configured records
// exist, keyed on the same natural keys the file declares.
const transactionsRuby = (ledgerSellerSlug: string) =>
  [
    's = Spree::Store.default',
    // A seller with one settled earning and one payout still owed, so the
    // marketplace ledger screens have rows to read and a settlement to mark
    // paid. Both are produced by fulfilment and the payout sweep, neither of
    // which an E2E run can reach.
    `ledger_seller = s.sellers.find_by!(slug: '${ledgerSellerSlug}')`,
    // Approved directly: the approve workflow wants a seller who has started
    // onboarding, and a ledger fixture never signs in.
    "ledger_seller.update!(status: 'approved') unless ledger_seller.approved?",
    `ledger_payout = ledger_seller.seller_payouts.where(amount: ${FIXTURE_LEDGER_PAYOUT_AMOUNT}).first_or_create!(store: s, currency: s.default_currency, provider: Spree::PayoutProvider::System.provider_key, status: 'pending')`,
    `ledger_seller.seller_payouts.where(amount: ${FIXTURE_LEDGER_OWED_AMOUNT}).first_or_create!(store: s, currency: s.default_currency, provider: Spree::PayoutProvider::System.provider_key, status: 'pending')`,
    `ledger_order = s.orders.where(seller: ledger_seller).first || Spree::Order.create!(store: s, seller: ledger_seller, currency: s.default_currency, email: 'e2e-ledger@example.com', status: 'placed', completed_at: Time.current)`,
    `ledger_seller.seller_transfers.first_or_create!(store: s, order: ledger_order, payout: ledger_payout, amount: ${FIXTURE_LEDGER_PAYOUT_AMOUNT}, currency: s.default_currency, kind: 'earning', provider: Spree::PayoutProvider::System.provider_key, status: 'completed')`,
    // The Inventory page's SKU, held by one checkout at the destination. The
    // hold is a reservation row written directly — the row keeps the level's
    // counter itself — because a real checkout needs reservations switched on
    // store-wide, which the order specs must not inherit.
    `inventory_variant = Spree::Variant.find_by!(sku: '${FIXTURE_INVENTORY_SKU}')`,
    `transfer_destination = s.stock_locations.find_by!(name: '${FIXTURE_TRANSFER_DESTINATION}')`,
    'inventory_level = transfer_destination.stock_levels.where(variant: inventory_variant).first_or_create!',
    `unless inventory_level.stock_reservations.exists?; inventory_cart = Spree::Cart.create!(store: s, currency: s.default_currency, email: 'e2e-inventory@example.com'); inventory_line = inventory_cart.line_items.create!(variant: inventory_variant, quantity: ${FIXTURE_INVENTORY_RESERVED}); inventory_level.stock_reservations.create!(cart: inventory_cart, line_item: inventory_line, quantity: ${FIXTURE_INVENTORY_RESERVED}, expires_at: 10.years.from_now); end`,
  ].join('; ')

function rmIfExists(path: string) {
  try {
    unlinkSync(path)
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code !== 'ENOENT') throw e
  }
}

function railsRunner(script: string, label: string): string {
  // Pass the script via argv to sidestep shell quoting (the Ruby contains
  // both single and double quotes).
  const result = spawnSync('bundle', ['exec', 'spec/dummy/bin/rails', 'runner', script], {
    cwd: API_GEM_DIR,
    encoding: 'utf-8',
    timeout: 120_000,
    maxBuffer: 10 * 1024 * 1024,
    env: RAILS_ENV,
  })
  if (result.status !== 0) {
    throw new Error(`${label} failed:\n${result.stderr}\n${result.stdout}`)
  }
  return result.stdout
}

async function waitForServer(url: string, timeoutMs = 30_000): Promise<void> {
  const start = Date.now()
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(url)
      if (res.status < 500) return
    } catch {
      /* not ready */
    }
    await new Promise((r) => setTimeout(r, 500))
  }
  throw new Error(`Server did not start within ${timeoutMs}ms at ${url}`)
}

type StoreConfig = ReturnType<typeof loadConfig>['config']

/**
 * The specs reference fixtures through the constants in `helpers.ts`; the
 * file is what creates them. Refuse to start when they disagree, which is
 * cheaper than a spec failing on a record that was never seeded. Checked on
 * the keys the specs and the Ruby block below resolve by.
 */
function assertFixturesDeclared(config: StoreConfig): void {
  const expected: [keyof StoreConfig, string, string][] = [
    ['channels', 'code', FIXTURE_BULK_CHANNEL_CODE],
    ['categories', 'permalink', FIXTURE_PROMO_TAXON_PERMALINK],
    ['categories', 'permalink', FIXTURE_BULK_CATEGORY_PERMALINK],
    ['customer_groups', 'name', FIXTURE_PROMO_CUSTOMER_GROUP],
    ['customers', 'email', FIXTURE_PROMO_CUSTOMER_EMAIL],
    ['customers', 'first_name', FIXTURE_PROMO_CUSTOMER_FIRST_NAME],
    ['customers', 'last_name', FIXTURE_PROMO_CUSTOMER_LAST_NAME],
    ['suppliers', 'name', FIXTURE_SUPPLIER],
    ['sellers', 'name', FIXTURE_LEDGER_SELLER],
    ['stock_locations', 'name', FIXTURE_TRANSFER_SOURCE],
    ['stock_locations', 'name', FIXTURE_TRANSFER_DESTINATION],
    ['products', 'name', FIXTURE_PROMO_PRODUCT],
    ['products', 'sku', FIXTURE_PROMO_SKU],
    ['products', 'name', FIXTURE_BULK_PRODUCT_A],
    ['products', 'name', FIXTURE_BULK_PRODUCT_N],
    ['products', 'name', FIXTURE_TRANSFER_PRODUCT],
    ['products', 'sku', FIXTURE_TRANSFER_SKU],
    ['products', 'name', FIXTURE_INVENTORY_PRODUCT],
    ['products', 'sku', FIXTURE_INVENTORY_SKU],
  ]
  const missing = expected
    .filter(([section, attribute, value]) => {
      const entries = (config[section] ?? []) as Record<string, unknown>[]
      return !entries.some((entry) => entry[attribute] === value)
    })
    .map(([section, attribute, value]) => `${section} with ${attribute} "${value}"`)
  if (missing.length) {
    throw new Error(
      `e2e/fixtures/store.yml does not declare: ${missing.join(', ')} (helpers.ts and the fixture file drifted apart)`,
    )
  }
}

/** The ledger seller's slug as the file states it, for the Ruby block that adds its payouts. */
function ledgerSellerSlug(config: StoreConfig): string {
  const seller = (config.sellers ?? []).find(
    (candidate) => candidate.name === FIXTURE_LEDGER_SELLER,
  )
  if (!seller)
    throw new Error(`e2e/fixtures/store.yml does not declare seller "${FIXTURE_LEDGER_SELLER}"`)
  return seller.slug
}

let serverProcess: ChildProcess | null = null

export default async function globalSetup() {
  rmIfExists(TEST_SQLITE)

  // The dummy test env pins ActiveJob to the :test adapter (RSpec asserts on
  // enqueues), but e2e flows like CSV import only progress when jobs actually
  // run — execute them in-process for the e2e server only. Removed in
  // global-teardown; the DASHBOARD_E2E guard keeps a leftover file inert for
  // regular spec runs.
  writeFileSync(
    ASYNC_JOBS_INITIALIZER,
    [
      '# Written by packages/dashboard/e2e/global-setup.ts — safe to delete.',
      "ActiveJob::Base.queue_adapter = :async if ENV['DASHBOARD_E2E'] == '1'",
      '',
    ].join('\n'),
  )

  const { config } = loadConfig(STORE_CONFIG)
  assertFixturesDeclared(config)

  const bootstrap = railsRunner(BOOTSTRAP_RUBY, 'Bootstrap runner')
  const jsonMatch = bootstrap.match(/\{.*\}\s*$/)
  if (!jsonMatch) {
    throw new Error(`Failed to parse credentials from runner output:\n${bootstrap}`)
  }
  const { deploy_token: deployToken, ...credentials } = JSON.parse(jsonMatch[0]) as Record<
    string,
    string
  >
  writeFileSync(CREDENTIALS_FILE, JSON.stringify(credentials))

  serverProcess = spawn(
    'bundle',
    ['exec', 'spec/dummy/bin/rails', 'server', '-p', PORT, '-e', 'test'],
    { cwd: API_GEM_DIR, stdio: ['ignore', 'pipe', 'pipe'], env: RAILS_ENV },
  )

  serverProcess.stderr?.on('data', (data: Buffer) => {
    const msg = data.toString()
    if (msg.includes('Error') || msg.includes('error')) console.error('[rails]', msg)
  })

  if (serverProcess.pid) writeFileSync(RAILS_PID_FILE, String(serverProcess.pid))

  await waitForServer(`http://localhost:${PORT}/api/v3/admin/me`)

  // The fixtures, through the same Admin API write paths the dashboard uses,
  // so every CI run exercises them before the first spec starts. Prune keeps
  // the products list exactly what the file says across reruns.
  const client = createAdminClient({
    baseUrl: credentials.api_url,
    secretKey: deployToken,
    retry: false,
  })
  const report = await deployConfig(config, client, { prune: ['products'] })
  if (reportHasFailures(report)) {
    throw new Error(`Deploying e2e/fixtures/store.yml failed:\n${renderReport(report)}`)
  }

  railsRunner(transactionsRuby(ledgerSellerSlug(config)), 'Transaction fixtures runner')
}
