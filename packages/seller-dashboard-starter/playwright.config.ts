import { defineConfig, devices } from '@playwright/test'

// End-to-end tests run against your own stack: `spree dev` for the API, and
// the dev server Playwright starts below. Point them somewhere else with
// E2E_BASE_URL — a preview build, or a deployed environment.
const BASE_URL = process.env.E2E_BASE_URL || 'http://localhost:5174'

export default defineConfig({
  testDir: './e2e',
  // One worker: specs share a database, so parallel runs interfere unless
  // every spec creates its own records under a unique name.
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 2 : 0,
  timeout: 30_000,
  expect: { timeout: 10_000 },
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : 'list',

  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],

  // Starts the dashboard for the run and reuses one you already have open.
  // The API is expected to be running separately (`spree dev`).
  webServer: process.env.E2E_BASE_URL
    ? undefined
    : {
        command: 'pnpm dev --port 5174 --strictPort',
        url: BASE_URL,
        reuseExistingServer: true,
        timeout: 60_000,
      },
})
