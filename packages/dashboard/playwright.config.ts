import { defineConfig, devices } from '@playwright/test'

// Ports kept distinct from the dev defaults (Rails :3000, Vite :5173) so an
// E2E run never clobbers a developer's running stack.
const RAILS_PORT = process.env.E2E_RAILS_PORT || '3010'
const VITE_PORT = process.env.E2E_VITE_PORT || '5174'

// `E2E_PREVIEW=1` serves the built SPA (`vite preview`) instead of the dev
// server. Every test gets a fresh browser context with an empty HTTP cache,
// so dev mode re-serves hundreds of on-demand-transformed modules on every
// `page.goto` — the production bundle is a handful of files. CI builds first
// and sets this; local runs default to `vite dev` (no build step needed).
const PREVIEW = process.env.E2E_PREVIEW === '1'

export default defineConfig({
  testDir: './e2e',
  // Sequential per machine — the global Rails server + SQLite test DB are
  // shared across specs, and the suite mutates server state (store settings,
  // the admin profile, creating + accepting invitations), so concurrent
  // workers against one backend would interfere. CI still parallelizes by
  // sharding (`--shard=n/m`): each shard is a separate machine with its own
  // Rails + DB + Vite stack, and specs are self-contained (fixtures come from
  // global-setup; dynamic records use `Date.now()` suffixes).
  fullyParallel: false,
  workers: 1,

  // `github` gives inline PR annotations; `html` is what the failure-artifact
  // upload ships (with the plain `github` reporter alone, playwright-report/
  // stays empty and the artifact is useless).
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : 'list',
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
  // pointed at that Rails. Playwright handles process lifecycle and waits
  // for both to respond to a probe before any spec runs.
  globalSetup: './e2e/global-setup.ts',
  globalTeardown: './e2e/global-teardown.ts',

  webServer: [
    {
      // Vite — proxies `/api/*` to the test Rails per `vite.config.ts`,
      // aimed at the test Rails port via `VITE_API_PROXY_TARGET` below.
      // Preview mode serves `dist/` and applies the same proxy config.
      command: PREVIEW
        ? `pnpm preview --port ${VITE_PORT} --strictPort`
        : `pnpm dev --port ${VITE_PORT} --strictPort`,
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
