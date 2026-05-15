/**
 * Global setup — runs once before all integration test files.
 * Seeds the database, boots a Rails server, and provides credentials.
 */
import { type ChildProcess, execSync, spawn } from 'node:child_process'
import { writeFileSync } from 'node:fs'
import { resolve } from 'node:path'

const API_GEM_DIR = resolve(__dirname, '../../../../spree/api')
const RAILS = 'bundle exec spec/dummy/bin/rails'
const PORT = process.env.INTEGRATION_PORT || '3010'
const CREDENTIALS_FILE = resolve(__dirname, '.credentials.json')

const execOpts = {
  cwd: API_GEM_DIR,
  encoding: 'utf-8' as const,
  timeout: 120_000,
  maxBuffer: 10 * 1024 * 1024,
  env: { ...process.env, RAILS_ENV: 'test', PORT },
}

const CREDENTIALS_RUBY = [
  'require "json"',
  's = Spree::Store.default',
  'k = s.api_keys.active.publishable.first',
  'pm = Spree::Gateway::Bogus.where(name: "Credit Card (Test)").first_or_create!(stores: [s], active: true, display_on: "both")',
  'check = Spree::PaymentMethod::Check.where(name: "Check (Test)").first_or_create!(stores: [s], active: true, display_on: "both")',
  'u = Spree.user_class.where.not(email: nil).where("email NOT LIKE ?", "%@spree.com").first',
  'u.update!(password: "spree123", password_confirmation: "spree123")',
  'sec = Spree::Api::Config[:jwt_secret_key].presence || Rails.application.credentials.jwt_secret_key || ENV["JWT_SECRET_KEY"] || Rails.application.secret_key_base',
  'jwt = JWT.encode({ user_id: u.id, user_type: "customer", jti: SecureRandom.uuid, iss: "spree", aud: "store_api", exp: 1.hour.from_now.to_i }, sec, "HS256")',
  'p = s.products.available.first',
  'c = s.taxonomies.first&.root&.children&.first',
  'port = ENV.fetch("PORT", 3010)',
  'puts JSON.generate(base_url: "http://localhost:#{port}", publishable_key: k.token, jwt_token: jwt, user_email: u.email, user_password: "spree123", product_slug: p&.slug, product_id: p&.prefixed_id, variant_id: p&.default_variant&.prefixed_id, category_id: c&.prefixed_id, category_permalink: c&.permalink, country_iso: "US", store_name: s.name, bogus_payment_method_id: pm.prefixed_id, check_payment_method_id: check.prefixed_id)',
].join('; ')

let serverProcess: ChildProcess | null = null

function waitForServer(url: string, timeoutMs = 30_000): Promise<void> {
  const start = Date.now()
  return new Promise((resolve, reject) => {
    const check = async () => {
      try {
        const res = await fetch(url)
        if (res.ok || res.status === 401) {
          resolve()
          return
        }
      } catch {
        /* not ready */
      }
      if (Date.now() - start > timeoutMs) {
        reject(new Error(`Server did not start within ${timeoutMs}ms`))
        return
      }
      setTimeout(check, 500)
    }
    check()
  })
}

export async function setup() {
  // 1. Seed + load sample data
  execSync(`${RAILS} runner "Spree::Seeds::All.call; Spree::SampleData::Loader.call"`, execOpts)

  // 2. Extract credentials and write to temp file (shared with test files)
  const output = execSync(`${RAILS} runner '${CREDENTIALS_RUBY}'`, execOpts)
  const jsonMatch = output.match(/\{.*\}\s*$/)
  if (!jsonMatch) throw new Error(`Failed to parse credentials:\n${output}`)
  writeFileSync(CREDENTIALS_FILE, jsonMatch[0])

  // 3. Boot Rails server
  serverProcess = spawn(
    'bundle',
    ['exec', 'spec/dummy/bin/rails', 'server', '-p', PORT, '-e', 'test'],
    {
      cwd: API_GEM_DIR,
      stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, RAILS_ENV: 'test', PORT },
    },
  )

  serverProcess.stderr?.on('data', (data: Buffer) => {
    const msg = data.toString()
    if (msg.includes('Error') || msg.includes('error')) console.error('[rails]', msg)
  })

  await waitForServer(`http://localhost:${PORT}/api/v3/store/products`)
}

export async function teardown() {
  if (serverProcess) {
    serverProcess.kill('SIGTERM')
    serverProcess = null
  }
}
