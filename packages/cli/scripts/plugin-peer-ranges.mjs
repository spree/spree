import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const packagesDir = join(dirname(fileURLToPath(import.meta.url)), '../..')

// Workspace packages a scaffolded dashboard plugin peer-depends on, keyed by
// the template variable that carries each range.
const PEERS = {
  spree_admin_sdk_range: 'admin-sdk',
  spree_dashboard_core_range: 'dashboard-core',
  spree_dashboard_ui_range: 'dashboard-ui',
}

/**
 * Caret ranges on the versions currently in the workspace, so `spree plugin
 * new` scaffolds peers that match the dashboard released alongside this CLI.
 * Injected at build time (tsup) and test time (vitest).
 *
 * @returns {Record<string, string>}
 */
export function pluginPeerRanges() {
  return Object.fromEntries(
    Object.entries(PEERS).map(([variable, dir]) => {
      const { version } = JSON.parse(readFileSync(join(packagesDir, dir, 'package.json'), 'utf8'))
      return [variable, `^${version}`]
    }),
  )
}
