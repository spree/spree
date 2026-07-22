import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExecOrRun } from '../docker.js'

// Run a rake task inside the web container. Variadic: anything after the
// task name is forwarded verbatim, including `KEY=value` rake args and flags.
//   spree rake spree:channels:full_upgrade
//   spree rake spree:price_history:seed
//   spree rake db:rollback STEP=2
export function registerRakeCommand(program: Command): void {
  program
    .command('rake')
    .description('Run a rake task (`bin/rake …`) inside the web container')
    .argument('<args...>', 'task name and arguments')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      const ctx = detectProject()
      await dockerComposeExecOrRun(['bin/rake', ...args], ctx.projectDir)
    })
}
