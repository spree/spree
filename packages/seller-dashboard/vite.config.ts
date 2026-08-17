import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
// Self-import of the shell's own Vite integration — the same composition
// hosts get from `@spree/seller-dashboard/vite`. It wraps the TanStack Router
// generator, so the shell's committed routeTree.gen.ts is produced by the
// exact machinery hosts use, which is what makes the shell's own routes
// typecheck against the tree they compose into.
import { spreeSellerDashboardPlugin } from './src/vite'

export default defineConfig({
  plugins: [spreeSellerDashboardPlugin({ root: import.meta.dirname }), react()],
})
