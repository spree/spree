import path from 'node:path'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
// Self-import of the shell's own Vite integration — the same composition
// hosts get from `@spree/dashboard/vite`. It wraps the TanStack Router
// generator, so the shell's committed routeTree.gen.ts is produced by the
// exact machinery hosts use (with VITE_EXAMPLE_PLUGIN=true, including the
// example plugin's file routes).
import { spreeDashboardPlugin } from './src/vite'

export default defineConfig({
  // Sub-path mounting for the single-node topology: the official Docker image
  // builds with VITE_BASE_PATH=/dashboard/ so asset URLs resolve under the
  // Rails-served mount. Unset (dev, CDN root deploys) Vite defaults to '/'.
  base: process.env.VITE_BASE_PATH,
  // The plugin bundles `@tailwindcss/vite`, so we don't register it separately.
  // `cssEntry` defaults to `./src/styles.css`, which matches our entry — pass
  // it here only as a hint for readers of this config.
  //
  // Plugin selection: hosts normally omit `plugins` so auto-discovery picks up
  // every dep with the `spree.dashboard.plugin` marker. This monorepo copy
  // defaults to an explicit empty whitelist because our only marked dep is the
  // reference plugin (@spree/dashboard-plugin-example, a devDependency) —
  // opt in with VITE_EXAMPLE_PLUGIN=true to exercise the real discovery +
  // activation path end-to-end.
  plugins: [
    spreeDashboardPlugin({
      cssEntry: './src/styles.css',
      plugins: process.env.VITE_EXAMPLE_PLUGIN === 'true' ? undefined : [],
    }),
    react(),
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  // Proxy /api to the Rails server so the SPA is same-origin with the API in dev.
  // Same-origin keeps the refresh-token cookie working under SameSite=Lax without
  // needing HTTPS (production cross-origin uses SameSite=None; Secure).
  //
  // `VITE_API_PROXY_TARGET` is the proxy *target* — kept distinct from
  // `VITE_SPREE_API_URL` (which the SDK reads at build time to switch to
  // absolute URLs) so the E2E suite can keep dev's same-origin path even when
  // pointing at a different Rails port.
  server: {
    proxy: {
      '/api': {
        target:
          process.env.VITE_API_PROXY_TARGET ||
          process.env.VITE_SPREE_API_URL ||
          'http://localhost:3000',
        changeOrigin: true,
      },
      // Active Storage's Disk service issues presigned URLs against `/rails/active_storage/...`
      // on the Rails origin. Without proxying, the SPA's PUT from :5173 hits :3000
      // cross-origin and the browser blocks it ("Failed to fetch") because
      // ActiveStorage::DiskController doesn't speak CORS. Proxying keeps it same-origin.
      '/rails': {
        target:
          process.env.VITE_API_PROXY_TARGET ||
          process.env.VITE_SPREE_API_URL ||
          'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
})
