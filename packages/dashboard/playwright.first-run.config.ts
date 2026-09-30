import { defineConfig, devices } from '@playwright/test'
import { FIRST_RUN_RAILS_PORT, FIRST_RUN_VITE_PORT } from './e2e/first-run/global-setup'

const PREVIEW = process.env.E2E_PREVIEW === '1'

// First-run setup only opens on an installation with no admin, and the main
// suite's stack always has one. This suite gets its own Rails, database and
// Vite on their own ports, so it can run next to the main suite. Completing
// setup closes it for good, so every run starts from a fresh database.
export default defineConfig({
  testDir: './e2e/first-run',
  fullyParallel: false,
  workers: 1,

  // Own output folders: CI runs this after the main suite on the same machine
  // and uploads both reports.
  reporter: process.env.CI
    ? [['github'], ['html', { open: 'never', outputFolder: 'playwright-report-first-run' }]]
    : 'list',
  outputDir: 'test-results-first-run',
  // A retry would meet a database that setup has already closed.
  retries: 0,
  timeout: 60_000,
  expect: { timeout: 10_000 },

  use: {
    baseURL: `http://localhost:${FIRST_RUN_VITE_PORT}`,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],

  globalSetup: './e2e/first-run/global-setup.ts',
  globalTeardown: './e2e/first-run/global-teardown.ts',

  webServer: {
    command: PREVIEW
      ? `pnpm preview --port ${FIRST_RUN_VITE_PORT} --strictPort`
      : `pnpm dev --port ${FIRST_RUN_VITE_PORT} --strictPort`,
    url: `http://localhost:${FIRST_RUN_VITE_PORT}`,
    reuseExistingServer: false,
    timeout: 60_000,
    stdout: 'ignore',
    stderr: 'pipe',
    env: { VITE_API_PROXY_TARGET: `http://localhost:${FIRST_RUN_RAILS_PORT}` },
  },
})
