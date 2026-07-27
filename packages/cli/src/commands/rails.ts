import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExecOrRun } from '../docker.js'

// Run any Rails command. Short for `spree exec bin/rails …`.
//   spree rails runner 'puts Rails.env'
//   spree rails db:migrate
//   spree rails routes -g products
export function registerRailsCommand(program: Command): void {
  program
    .command('rails')
    .description('Run a Rails command (`bin/rails …`) inside the web container')
    .argument('<args...>', 'arguments to pass to bin/rails')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      const ctx = detectProject()
      await dockerComposeExecOrRun(['bin/rails', ...args], ctx.projectDir)
    })
}
