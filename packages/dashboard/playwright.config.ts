import { defineConfig, devices } from '@playwright/test'

// Ports kept distinct from the dev defaults (Rails :3000, Vite :5173) so an
// E2E run never clobbers a developer's running stack.
const RAILS_PORT = process.env.E2E_RAILS_PORT || '3010'
const VITE_PORT = process.env.E2E_VITE_PORT || '5174'

export default defineConfig({
  testDir: './e2e',
  // Sequential — the global Rails server + SQLite test DB are shared, and the
  // suite mutates server state (creating invitations, accepting them).
  fullyParallel: false,
  workers: 1,

  reporter: process.env.CI ? 'github' : 'list',
  retries: process.env.CI ? 2 : 0,
  timeout: 30_000,
  expect: { timeout: 10_000 },

  use: {
    baseURL: `http://localhost:${VITE_PORT}`,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],

  // Boots Rails + the seed pipeline once before the suite starts, then Vite
  // dev pointed at that Rails. Playwright handles process lifecycle and waits
  // for both to respond to a probe before any spec runs.
  globalSetup: './e2e/global-setup.ts',
  globalTeardown: './e2e/global-teardown.ts',

  webServer: [
    {
      // Vite dev — proxies `/api/*` to the test Rails per `vite.config.ts`,
      // overridden via `VITE_SPREE_API_URL` so the proxy targets the test
      // Rails port instead of the dev default.
      command: `pnpm dev --port ${VITE_PORT}`,
      url: `http://localhost:${VITE_PORT}`,
      reuseExistingServer: false,
      timeout: 60_000,
      stdout: 'ignore',
      stderr: 'pipe',
      env: {
        // Vite proxy target — the SDK keeps relative URLs so the SPA stays
        // same-origin with the proxy, exactly like dev. Setting
        // `VITE_SPREE_API_URL` here would flip the SDK to absolute URLs and
        // break the cookie path the refresh flow depends on.
        VITE_API_PROXY_TARGET: `http://localhost:${RAILS_PORT}`,
      },
    },
  ],
})
