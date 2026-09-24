import { execa } from 'execa'
import type { PackageManager } from './types.js'
import { runCommand } from './utils.js'

/**
 * Scaffold an admin SPA into `apps/<component>/` by delegating to the
 * project-local CLI: `spree add <component>`. The generated project already
 * depends on `@spree/cli` (installed with the root deps, before this phase),
 * and the CLI bundles each starter template with version pins matching its
 * release — one template source, no copy in this package. The command reads
 * the API port from the project's `.env` and writes the app's `.env.local`
 * itself (API URL only — never credentials).
 */
async function scaffoldApp(
  projectDir: string,
  component: 'dashboard' | 'seller-dashboard',
  opts: { install: boolean; packageManager: PackageManager },
): Promise<void> {
  // --quiet: the scaffold's own summary cards cover these — the command's
  // own "… added!" note would just duplicate them.
  const args = ['spree', 'add', component, '--quiet']
  if (!opts.install) args.push('--no-install')
  await execa(runCommand(opts.packageManager), args, { cwd: projectDir, stdio: 'inherit' })
}

/**
 * Scaffold both admin SPAs: the Dashboard at `apps/dashboard/` and the
 * marketplace Seller Panel at `apps/seller-dashboard/`. Both ship in every
 * project so the starter's Dockerfile finds them and bakes both into the
 * image — a marketplace that never invites a seller simply leaves /sellers
 * unvisited.
 */
export async function scaffoldDashboard(
  projectDir: string,
  opts: { install: boolean; packageManager: PackageManager },
): Promise<void> {
  await scaffoldApp(projectDir, 'dashboard', opts)
  await scaffoldApp(projectDir, 'seller-dashboard', opts)
}
