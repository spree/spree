// The shell module runs the i18n/nav/search bootstrap on import — it must
// execute before the plugin imports below so plugins can call i18n.t at
// module load. (Side-effect imports are ordering barriers.)
import { Dashboard } from '@spree/dashboard'
import { createRoot } from 'react-dom/client'
// Activate installed dashboard plugins — synthesized by spreeDashboardPlugin()
// from your package.json deps. `pnpm add <plugin>` + dev-server restart is the
// whole install; this line never changes.
import 'virtual:spree-dashboard-plugins'
// Your own customizations (nav entries, routes, slot widgets, table columns).
import './plugins'
import './styles.css'

createRoot(document.getElementById('root')!).render(<Dashboard />)
