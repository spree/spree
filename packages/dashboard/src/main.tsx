import { createRoot } from 'react-dom/client'
// The shell module runs the i18n/nav/search bootstrap on import — it must
// execute before the virtual plugin module below so plugins can call i18n.t
// at load time. (Side-effect imports are ordering barriers; Biome won't
// reorder across them.)
import { createDashboardRouter, Dashboard } from './index'
// Activate installed dashboard plugins. Synthesized by `spreeDashboardPlugin()`
// in vite.config.ts from the auto-discovered plugin list (package.json deps
// carrying the `spree.dashboard.plugin` marker) — installing a plugin needs
// no edit here.
import 'virtual:spree-dashboard-plugins'
import './styles.css'
import { routeTree } from './routeTree.gen'

// basepath mirrors Vite's `base` so sub-path mounts (/dashboard on the
// single-node topology) route correctly; '/' in dev and root deploys.
const router = createDashboardRouter(routeTree, { basepath: import.meta.env.BASE_URL })

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router
  }
}

createRoot(document.getElementById('root')!).render(<Dashboard router={router} />)
