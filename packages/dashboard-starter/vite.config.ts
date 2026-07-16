import { spreeDashboardPlugin } from '@spree/dashboard/vite'
import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ mode }) => {
  // loadEnv, not process.env: Vite doesn't load .env files before evaluating
  // this config, and .env.local is where `spree` writes the proxy target.
  const env = loadEnv(mode, process.cwd(), 'VITE_')
  const proxyTarget = env.VITE_API_PROXY_TARGET || 'http://localhost:3000'

  return {
    // Sub-path mounting for the single-node topology (Rails serves the build
    // at /dashboard): build with VITE_BASE_PATH=/dashboard/ so asset URLs
    // resolve. Unset (dev, CDN root deploys) Vite defaults to '/'.
    base: process.env.VITE_BASE_PATH,
    // spreeDashboardPlugin bundles Tailwind, injects @source directives for
    // every Spree dashboard package, auto-discovers installed dashboard
    // plugins (package.json deps carrying the `spree.dashboard.plugin`
    // marker), serves the `virtual:spree-dashboard-plugins` module that
    // src/main.tsx imports to activate them, and composes the shell's and
    // every plugin's file routes into src/routeTree.gen.ts on each dev
    // start/build — commit that file; its diff shows what an upgrade added.
    plugins: [spreeDashboardPlugin(), react()],
    // Proxy /api to the Rails server so the SPA is same-origin with the API
    // in dev — keeps the refresh-token cookie working under SameSite=Lax
    // without HTTPS. /rails covers Active Storage's presigned URLs. Proxy
    // target, not VITE_SPREE_API_URL — that switches the SDK to absolute
    // cross-origin URLs and bypasses this proxy (see .env.example).
    server: {
      proxy: {
        '/api': { target: proxyTarget, changeOrigin: true },
        '/rails': { target: proxyTarget, changeOrigin: true },
      },
    },
  }
})
