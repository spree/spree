import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { warnDeprecated } from '../deprecation.js'
import { dockerComposeExecOrRun } from '../docker.js'

export function registerRoutesCommand(program: Command): void {
  program
    .command('routes', { hidden: true })
    .description('Deprecated: use `spree api endpoints`')
    .argument('[args...]', 'arguments to pass to bin/rails routes')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      warnDeprecated('spree routes', 'spree api endpoints')
      const ctx = detectProject()
      await dockerComposeExecOrRun(['bin/rails', 'routes', ...args], ctx.projectDir)
    })
}
