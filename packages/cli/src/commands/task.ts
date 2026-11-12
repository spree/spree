import type { Command } from 'commander'
import { taskCommand } from '../backend.js'
import { detectProject } from '../context.js'
import { dockerComposeExecOrRun } from '../docker.js'

// Run a Spree maintenance task. Task names are part of the CLI's public
// contract and keep working on every backend.
//   spree task search:reindex
//   spree task channels:full_upgrade
//   spree task price_history:seed
export function registerTaskCommand(program: Command): void {
  program
    .command('task')
    .description('Run a Spree maintenance task (e.g. `search:reindex`)')
    .argument('<name>', 'task name, e.g. search:reindex')
    .argument('[args...]', 'arguments to pass to the task')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (name: string, args: string[]) => {
      const ctx = detectProject()
      await dockerComposeExecOrRun(taskCommand(name.replace(/^spree:/, ''), args), ctx.projectDir)
    })
}
