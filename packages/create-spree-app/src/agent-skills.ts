import { execa } from 'execa'
import { AGENT_SKILLS_REPO } from './constants.js'
import type { PackageManager } from './types.js'
import { dlxCommand } from './utils.js'

/**
 * Install every Spree agent skill into the project, for each coding agent the
 * `skills` CLI detects, without prompting.
 *
 * @param projectDir absolute path to the generated project
 * @param pm the scaffold's package manager, which runs the `skills` CLI
 */
export async function installAgentSkills(projectDir: string, pm: PackageManager): Promise<void> {
  const [command, ...runnerArgs] = dlxCommand(pm).split(' ')
  // npx asks before downloading a package it has not cached; --yes answers it.
  if (pm === 'npm') runnerArgs.push('--yes')

  await execa(
    command,
    [...runnerArgs, 'skills', 'add', AGENT_SKILLS_REPO, '--skill', '*', '--yes'],
    // A stalled download must fail, so the scaffold can warn and move on.
    { cwd: projectDir, stdio: 'ignore', timeout: 120_000 },
  )
}
