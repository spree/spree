import { createRoot } from 'react-dom/client'
// The shell module runs the i18n/nav/search bootstrap on import — it must
// execute before the virtual plugin module below so plugins can call i18n.t
// at load time. (Side-effect imports are ordering barriers; Biome won't
// reorder across them.)
import { Dashboard } from './dashboard'
// Activate installed dashboard plugins. Synthesized by `spreeDashboardPlugin()`
// in vite.config.ts from the auto-discovered plugin list (package.json deps
// carrying the `spree.dashboard.plugin` marker) — installing a plugin needs
// no edit here.
import 'virtual:spree-dashboard-plugins'
import './styles.css'

createRoot(document.getElementById('root')!).render(<Dashboard />)
