import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { warnDeprecated } from '../deprecation.js'
import { dockerComposeExecOrRun } from '../docker.js'

// Deprecated: Rails-only, so it goes through the `spree exec` escape hatch.
export function registerRailsCommand(program: Command): void {
  program
    .command('rails', { hidden: true })
    .description('Deprecated: use `spree exec bin/rails …`')
    .argument('<args...>', 'arguments to pass to bin/rails')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      warnDeprecated('spree rails', `spree exec bin/rails ${args.join(' ')}`)
      const ctx = detectProject()
      await dockerComposeExecOrRun(['bin/rails', ...args], ctx.projectDir)
    })
}
