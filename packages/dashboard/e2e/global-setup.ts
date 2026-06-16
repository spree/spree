import { type ChildProcess, spawn, spawnSync } from 'node:child_process'
import { unlinkSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import {
  FIXTURE_BULK_CATEGORY,
  FIXTURE_BULK_CHANNEL_CODE,
  FIXTURE_BULK_CHANNEL_NAME,
  FIXTURE_BULK_PRODUCT_A,
  FIXTURE_BULK_PRODUCT_B,
  FIXTURE_BULK_PRODUCT_C,
  FIXTURE_BULK_PRODUCT_D,
  FIXTURE_BULK_PRODUCT_E,
  FIXTURE_BULK_PRODUCT_F,
  FIXTURE_BULK_PRODUCT_G,
  FIXTURE_BULK_PRODUCT_H,
  FIXTURE_BULK_PRODUCT_I,
  FIXTURE_BULK_PRODUCT_J,
  FIXTURE_BULK_PRODUCT_K,
  FIXTURE_BULK_PRODUCT_L,
  FIXTURE_BULK_PRODUCT_M,
  FIXTURE_BULK_PRODUCT_N,
  FIXTURE_PROMO_CUSTOMER_EMAIL,
  FIXTURE_PROMO_CUSTOMER_FIRST_NAME,
  FIXTURE_PROMO_CUSTOMER_FULL_NAME,
  FIXTURE_PROMO_CUSTOMER_GROUP,
  FIXTURE_PROMO_PRODUCT,
  FIXTURE_PROMO_TAXON,
} from './helpers'
import { CREDENTIALS_FILE, E2E_DIR, RAILS_PID_FILE } from './paths'

const API_GEM_DIR = resolve(E2E_DIR, '../../../spree/api')
const PORT = process.env.E2E_RAILS_PORT || '3010'
// Mirrors `spec/dummy/config/database.yml`.
const TEST_SQLITE = resolve(API_GEM_DIR, 'spec/dummy/db/spree_test.sqlite3')

const RAILS_ENV = { ...process.env, RAILS_ENV: 'test', PORT }

// Customer's last name is derived from the full name so the seeder and the
// matching `full_name` assertion in promotions.spec stay in sync.
const FIXTURE_PROMO_CUSTOMER_LAST_NAME = FIXTURE_PROMO_CUSTOMER_FULL_NAME.replace(
  `${FIXTURE_PROMO_CUSTOMER_FIRST_NAME} `,
  '',
)

const BOOTSTRAP_RUBY = [
  "load Rails.root.join('db', 'schema.rb').to_s",
  'Spree::Seeds::All.call',
  'require "json"',
  's = Spree::Store.default',
  'admin = Spree.admin_user_class.first || Spree.admin_user_class.create!(email: "admin@example.com", password: "spree123", password_confirmation: "spree123")',
  'admin.update!(password: "spree123", password_confirmation: "spree123")',
  's.add_user(admin, Spree::Role.default_admin_role) unless s.role_users.exists?(user: admin)',
  // Idempotent fixtures for promotion rule/action editor specs. Customer
  // groups have no admin UI yet, so this is the only path to seed one.
  `taxonomy = s.taxonomies.find_or_create_by!(name: 'Categories')`,
  `category = taxonomy.taxons.where(name: '${FIXTURE_PROMO_TAXON}').first_or_create!(parent: taxonomy.root)`,
  `shipping_category = Spree::ShippingCategory.first || Spree::ShippingCategory.create!(name: 'Default')`,
  `product = Spree::Product.where(name: '${FIXTURE_PROMO_PRODUCT}').first_or_create!(price: 19.99, shipping_category: shipping_category, stores: [s], status: 'active')`,
  `product.taxons << category unless product.taxons.include?(category)`,
  // Stock the promo product on the store's default stock location so
  // order-creation tests can add it to a draft order without the
  // +"Quantity not available"+ validation kicking in.
  `default_location = s.default_stock_location`,
  `product.variants_including_master.each { |v| default_location.stock_items.where(variant: v).first_or_create!.update!(count_on_hand: 100, backorderable: true) }`,
  // Disjoint product fixtures for products-bulk.spec.ts. Each test owns its
  // own pair (A/B → status, C/D → categories, E/F → tags, G/H → delete,
  // I → row-action clone/delete) so the serial suite can mutate them in any
  // order without poisoning siblings. All start `active` so the status spec
  // sees a clean transition.
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_A}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_B}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_C}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_D}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_E}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_F}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_G}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_H}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_I}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_J}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_K}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_L}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_M}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  `Spree::Product.where(name: '${FIXTURE_BULK_PRODUCT_N}').first_or_create!(price: 9.99, shipping_category: shipping_category, stores: [s], status: 'active').update!(status: 'active')`,
  // Second channel beyond the seeded default; the channels bulk-action
  // and filter specs need a non-default channel to add/remove against.
  `bulk_channel = s.channels.where(code: '${FIXTURE_BULK_CHANNEL_CODE}').first_or_create!(name: '${FIXTURE_BULK_CHANNEL_NAME}')`,
  // Pre-list M/N on the bulk channel so the remove-from-channels test
  // has something to undo.
  `bulk_channel.add_products([Spree::Product.find_by(name: '${FIXTURE_BULK_PRODUCT_M}').id, Spree::Product.find_by(name: '${FIXTURE_BULK_PRODUCT_N}').id])`,
  // Category used by the bulk-add-to-categories test. Sits in the same
  // `Categories` taxonomy as the promo taxon above.
  `taxonomy.taxons.where(name: '${FIXTURE_BULK_CATEGORY}').first_or_create!(parent: taxonomy.root)`,
  `Spree.user_class.where(email: '${FIXTURE_PROMO_CUSTOMER_EMAIL}').first_or_create! { |u| u.password = 'customer123'; u.password_confirmation = 'customer123'; u.first_name = '${FIXTURE_PROMO_CUSTOMER_FIRST_NAME}'; u.last_name = '${FIXTURE_PROMO_CUSTOMER_LAST_NAME}' }`,
  `s.customer_groups.where(name: '${FIXTURE_PROMO_CUSTOMER_GROUP}').first_or_create!`,
  // Make the store multi-currency so the money-entry forms (store credit,
  // refunds, manual prices) offer EUR alongside the USD default. Markets own
  // currency + locale (the legacy Store#supported_currencies column is dead),
  // and in markets mode the supported-currency list is exactly the markets'
  // currencies. The store already has a default US/USD market via
  // Store#ensure_default_market, so we add a EUR market here, anchored to
  // Germany. `MarketCountry#country_unique_per_store` forbids reusing a
  // country across markets — the markets specs draw from other EU countries
  // (see the note atop markets.spec.ts).
  `germany = Spree::Country.find_by(iso: 'DE')`,
  `s.markets.find_or_create_by!(name: 'Europe') { |m| m.currency = 'EUR'; m.default_locale = 'de'; m.countries = [germany] } if germany && !s.markets.exists?(currency: 'EUR')`,
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
