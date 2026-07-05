import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

// Shortcut for `spree rake spree:<name>` — most rake tasks a Spree dev runs
// are in the `spree:` namespace, so this saves the prefix.
//   spree task search:reindex      → bin/rake spree:search:reindex
//   spree task channels:full_upgrade
//   spree task price_history:seed
export function registerTaskCommand(program: Command): void {
  program
    .command('task')
    .description('Run a Spree rake task (auto-prefixes `spree:`)')
    .argument('<name>', 'task name (without `spree:` prefix)')
    .argument('[args...]', 'arguments to pass to the task')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (name: string, args: string[]) => {
      const ctx = detectProject()
      await dockerComposeExec(['bin/rake', `spree:${name}`, ...args], ctx.projectDir)
    })
}
