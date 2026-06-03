import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

// `bin/rails routes [-g pattern] [-c controller] [--expanded]` passthrough.
//   spree routes
//   spree routes -g products
//   spree routes -c Spree::Api::V3::Store::ProductsController
export function registerRoutesCommand(program: Command): void {
  program
    .command('routes')
    .description('Show Rails routes (`bin/rails routes`)')
    .argument('[args...]', 'arguments to pass to bin/rails routes')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      const ctx = detectProject()
      await dockerComposeExec(['bin/rails', 'routes', ...args], ctx.projectDir)
    })
}
