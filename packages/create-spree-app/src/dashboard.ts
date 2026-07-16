import { execa } from 'execa'
import type { PackageManager } from './types.js'
import { runCommand } from './utils.js'

/**
 * Scaffold the React Dashboard into `apps/dashboard/` by delegating to the
 * project-local CLI: `spree add dashboard`. The generated project already
 * depends on `@spree/cli` (installed with the root deps, before this phase),
 * and the CLI bundles the dashboard-starter template with version pins
 * matching its release — one template source, no copy in this package. The
 * command reads the API port from the project's `.env` and writes
 * `apps/dashboard/.env.local` itself (API URL only — never credentials).
 */
export async function scaffoldDashboard(
  projectDir: string,
  opts: { install: boolean; packageManager: PackageManager },
): Promise<void> {
  // --quiet: the scaffold's own summary cards cover the dashboard — the
  // command's "Dashboard added!" note would just duplicate them.
  const args = ['spree', 'add', 'dashboard', '--quiet']
  if (!opts.install) args.push('--no-install')
  await execa(runCommand(opts.packageManager), args, { cwd: projectDir, stdio: 'inherit' })
}
