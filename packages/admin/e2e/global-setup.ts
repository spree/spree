import { type ChildProcess, spawn, spawnSync } from 'node:child_process'
import { unlinkSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { CREDENTIALS_FILE, E2E_DIR, RAILS_PID_FILE } from './paths'

const API_GEM_DIR = resolve(E2E_DIR, '../../../spree/api')
const PORT = process.env.E2E_RAILS_PORT || '3010'
// Mirrors `spec/dummy/config/database.yml`.
const TEST_SQLITE = resolve(API_GEM_DIR, 'spec/dummy/db/spree_test.sqlite3')

const RAILS_ENV = { ...process.env, RAILS_ENV: 'test', PORT }

// One runner invocation pays the Bundler/Rails boot tax once instead of three
// times. Final `puts` emits the credentials JSON the spec files read.
// Promotion rule/action editor specs need real records to pick in
// `<ResourceMultiAutocomplete>` (products, categories, customers,
// customer groups). The base seed pipeline doesn't ship any of these,
// so we provision one of each with predictable names the specs filter on.
const FIXTURE_PROMO_TAXON = 'E2E Promo Category'
const FIXTURE_PROMO_PRODUCT = 'E2E Promo Product'
const FIXTURE_PROMO_CUSTOMER_EMAIL = 'e2e-promo-customer@example.com'
const FIXTURE_PROMO_CUSTOMER_GROUP = 'E2E Promo Group'
const FIXTURE_PROMO_COUNTRY_NAME = 'United States'

const BOOTSTRAP_RUBY = [
  "load Rails.root.join('db', 'schema.rb').to_s",
  'Spree::Seeds::All.call',
  'require "json"',
  's = Spree::Store.default',
  'admin = Spree.admin_user_class.first || Spree.admin_user_class.create!(email: "admin@example.com", password: "spree123", password_confirmation: "spree123")',
  'admin.update!(password: "spree123", password_confirmation: "spree123")',
  's.add_user(admin, Spree::Role.default_admin_role) unless s.role_users.exists?(user: admin)',
  // Promotion fixtures (idempotent: each `find_or_create` lookup keys off the
  // human-readable name so re-running setup against an existing DB is a no-op).
  `taxonomy = s.taxonomies.find_or_create_by!(name: 'Categories')`,
  `category = taxonomy.taxons.where(name: '${FIXTURE_PROMO_TAXON}').first_or_create!(parent: taxonomy.root)`,
  `shipping_category = Spree::ShippingCategory.first || Spree::ShippingCategory.create!(name: 'Default')`,
  `product = Spree::Product.where(name: '${FIXTURE_PROMO_PRODUCT}').first_or_create!(price: 19.99, shipping_category: shipping_category, stores: [s], status: 'active')`,
  `product.taxons << category unless product.taxons.include?(category)`,
  `Spree.user_class.where(email: '${FIXTURE_PROMO_CUSTOMER_EMAIL}').first_or_create! { |u| u.password = 'customer123'; u.password_confirmation = 'customer123'; u.first_name = 'Promo'; u.last_name = 'Customer' }`,
  `s.customer_groups.where(name: '${FIXTURE_PROMO_CUSTOMER_GROUP}').first_or_create!`,
  'port = ENV.fetch("PORT", 3010)',
  'puts JSON.generate(api_url: "http://localhost:#{port}", admin_email: admin.email, admin_password: "spree123", store_id: s.prefixed_id, store_name: s.name)',
].join('; ')

function rmIfExists(path: string) {
  try {
    unlinkSync(path)
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code !== 'ENOENT') throw e
  }
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

let serverProcess: ChildProcess | null = null

export default async function globalSetup() {
  rmIfExists(TEST_SQLITE)

  // Pass the script via argv to sidestep shell quoting (the Ruby contains
  // both single and double quotes).
  const result = spawnSync('bundle', ['exec', 'spec/dummy/bin/rails', 'runner', BOOTSTRAP_RUBY], {
    cwd: API_GEM_DIR,
    encoding: 'utf-8',
    timeout: 120_000,
    maxBuffer: 10 * 1024 * 1024,
    env: RAILS_ENV,
  })
  if (result.status !== 0) {
    throw new Error(`Bootstrap runner failed:\n${result.stderr}\n${result.stdout}`)
  }
  const jsonMatch = result.stdout.match(/\{.*\}\s*$/)
  if (!jsonMatch) {
    throw new Error(`Failed to parse credentials from runner output:\n${result.stdout}`)
  }
  writeFileSync(CREDENTIALS_FILE, jsonMatch[0])

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
}
