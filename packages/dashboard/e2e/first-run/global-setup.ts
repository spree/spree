import { writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { FIRST_RUN_CREDENTIALS_FILE, FIRST_RUN_RAILS_PID_FILE } from '../paths'
import { API_GEM_DIR, rmIfExists, runRailsBootstrap, startRails } from '../rails'

export const FIRST_RUN_RAILS_PORT = process.env.E2E_FIRST_RUN_RAILS_PORT || '3011'
export const FIRST_RUN_VITE_PORT = process.env.E2E_FIRST_RUN_VITE_PORT || '5176'

// A database of its own: setup only opens while no admin exists, and the main
// suite's database always has one.
const SQLITE = resolve(API_GEM_DIR, 'spec/dummy/db/spree_test_first_run.sqlite3')

const RAILS_ENV = {
  ...process.env,
  RAILS_ENV: 'test',
  PORT: FIRST_RUN_RAILS_PORT,
  DATABASE_URL: `sqlite3:${SQLITE}`,
  // The setup link is built from this, so the spec opens exactly the link an
  // install prints rather than one it assembles itself.
  SPREE_DASHBOARD_URL: `http://localhost:${FIRST_RUN_VITE_PORT}`,
}

// Seeds the way a fresh install does, which leaves no admin and a setup token
// on the default store.
const BOOTSTRAP_RUBY = [
  "load Rails.root.join('db', 'schema.rb').to_s",
  'Spree::Seeds::All.call',
  'require "json"',
  'raise "the seed created an admin, so setup is closed" if Spree.admin_user_class.exists?',
  'puts JSON.generate(setup_url: Spree::Store.default.setup_url)',
].join('; ')

export default async function globalSetup() {
  rmIfExists(SQLITE)

  writeFileSync(FIRST_RUN_CREDENTIALS_FILE, runRailsBootstrap(BOOTSTRAP_RUBY, RAILS_ENV))

  await startRails(FIRST_RUN_RAILS_PORT, RAILS_ENV, FIRST_RUN_RAILS_PID_FILE)
}
