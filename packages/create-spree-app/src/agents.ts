import { run } from './run.js'
import type { PackageManager } from './types.js'
import { runCommand } from './utils.js'

/**
 * Set the project up for AI coding agents by delegating to the project-local
 * CLI: `spree add ai` installs the Spree agent skills and connects each agent
 * to the Spree docs MCP server — the same command existing projects run.
 *
 * @param projectDir absolute path to the generated project
 * @param opts which halves to set up, and the scaffold's package manager
 */
export async function setupAgents(
  projectDir: string,
  opts: { skills: boolean; mcp: boolean; packageManager: PackageManager },
): Promise<void> {
  const args = ['spree', 'add', 'ai', '--quiet']
  if (!opts.skills) args.push('--no-skills')
  if (!opts.mcp) args.push('--no-mcp')
  await run(runCommand(opts.packageManager), args, { cwd: projectDir, stdio: 'inherit' })
}
