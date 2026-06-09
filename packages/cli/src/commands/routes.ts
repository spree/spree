import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

/**
 * Register the `spree routes` command on the CLI program.
 *
 * Passthrough to `bin/rails routes [-g pattern] [-c controller] [--expanded]`.
 *
 *   spree routes
 *   spree routes -g products
 *   spree routes -c Spree::Api::V3::Store::ProductsController
 *
 * @param program - The Commander CLI program to register the command on.
 */
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
