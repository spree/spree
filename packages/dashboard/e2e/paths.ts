import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const E2E_DIR = dirname(fileURLToPath(import.meta.url))
export const CREDENTIALS_FILE = resolve(E2E_DIR, '.credentials.json')
export const RAILS_PID_FILE = resolve(E2E_DIR, '.rails.pid')
// Written by global-setup into the (generated, gitignored) dummy app and
// removed in global-teardown — see the comment inside the file it writes.
export const ASYNC_JOBS_INITIALIZER = resolve(
  E2E_DIR,
  '../../../spree/api/spec/dummy/config/initializers/zz_dashboard_e2e_async_jobs.rb',
)
// The first-run setup suite runs its own Rails against its own database, so
// its state files live apart from the main suite's.
export const FIRST_RUN_CREDENTIALS_FILE = resolve(E2E_DIR, '.first-run.json')
export const FIRST_RUN_RAILS_PID_FILE = resolve(E2E_DIR, '.first-run-rails.pid')
