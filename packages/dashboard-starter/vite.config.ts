import { spreeDashboardPlugin } from '@spree/dashboard/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  // spreeDashboardPlugin bundles Tailwind, injects @source directives for
  // every Spree dashboard package, auto-discovers installed dashboard
  // plugins (package.json deps carrying the `spree.dashboard.plugin`
  // marker), and serves the `virtual:spree-dashboard-plugins` module that
  // src/main.tsx imports to activate them. No TanStack Router plugin needed:
  // the route tree ships pre-generated inside @spree/dashboard.
  plugins: [spreeDashboardPlugin(), react()],
  // Proxy /api to the Rails server so the SPA is same-origin with the API in
  // dev — keeps the refresh-token cookie working under SameSite=Lax without
  // HTTPS. /rails covers Active Storage's Disk-service presigned URLs.
  server: {
    proxy: {
      '/api': {
        target: process.env.VITE_SPREE_API_URL || 'http://localhost:3000',
        changeOrigin: true,
      },
      '/rails': {
        target: process.env.VITE_SPREE_API_URL || 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
})
