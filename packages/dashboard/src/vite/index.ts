/* Re-export of `@spree/dashboard-core/vite` so host apps that already depend
 * on the `@spree/dashboard` umbrella package can keep importing from
 * `@spree/dashboard/vite`. The plugin's implementation lives in
 * `@spree/dashboard-core` so custom dashboards built on `dashboard-core` +
 * `dashboard-ui` (without the `dashboard` app shell) can use it too.
 */
export type { SpreeDashboardPluginOptions } from '@spree/dashboard-core/vite'
export { spreeDashboardPlugin } from '@spree/dashboard-core/vite'
