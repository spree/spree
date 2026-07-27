import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExecOrRun } from '../docker.js'

export function registerRoutesCommand(program: Command): void {
  program
    .command('routes')
    .description('Show Rails routes (`bin/rails routes`)')
    .argument('[args...]', 'arguments to pass to bin/rails routes')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      const ctx = detectProject()
      await dockerComposeExecOrRun(['bin/rails', 'routes', ...args], ctx.projectDir)
    })
}
