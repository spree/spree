import { execa } from 'execa'
import type { PackageManager } from './types.js'
import { runCommand } from './utils.js'

export type AdminApp = 'dashboard' | 'seller-dashboard'

/**
 * Scaffold an admin SPA into `apps/<component>/` by delegating to the
 * project-local CLI: `spree add <component>`. The generated project already
 * depends on `@spree/cli` (installed with the root deps, before this phase),
 * and the CLI bundles each starter template with version pins matching its
 * release — one template source, no copy in this package. The command reads
 * the API port from the project's `.env` and writes the app's `.env.local`
 * itself (API URL only — never credentials).
 *
 * The Dashboard is the admin and ships in every project. The Seller Panel is
 * for marketplaces only; a project without `apps/seller-dashboard/` still gets
 * the stock panel baked into its production image by the starter's Dockerfile.
 */
export async function scaffoldApp(
  projectDir: string,
  component: AdminApp,
  opts: { install: boolean; packageManager: PackageManager },
): Promise<void> {
  // --quiet: the scaffold's own summary cards cover these — the command's
  // own "… added!" note would just duplicate them.
  const args = ['spree', 'add', component, '--quiet']
  if (!opts.install) args.push('--no-install')
  await execa(runCommand(opts.packageManager), args, { cwd: projectDir, stdio: 'inherit' })
}
