import { spreeSellerDashboardPlugin } from '@spree/seller-dashboard/vite'
import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ mode }) => {
  // loadEnv, not process.env: Vite doesn't load .env files before evaluating
  // this config, and .env.local is where the proxy target is written.
  const env = loadEnv(mode, process.cwd(), 'VITE_')
  const proxyTarget = env.VITE_API_PROXY_TARGET || 'http://localhost:3000'

  return {
    base: process.env.VITE_BASE_PATH,
    // spreeSellerDashboardPlugin bundles Tailwind, injects @source directives
    // for every Spree dashboard package, and composes the panel's file routes
    // into src/routeTree.gen.ts on each dev start/build — commit that file.
    plugins: [spreeSellerDashboardPlugin(), react()],
    // Proxy /api to Rails so the panel is same-origin with the API in dev,
    // keeping the refresh-token cookie working under SameSite=Lax without
    // HTTPS. /rails covers Active Storage's presigned URLs.
    server: {
      proxy: {
        '/api': { target: proxyTarget, changeOrigin: true },
        '/rails': { target: proxyTarget, changeOrigin: true },
      },
    },
  }
})
