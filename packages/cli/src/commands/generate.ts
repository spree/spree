import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

// Run a Spree generator. Auto-prefixes `spree:` so the common case stays
// short: `spree generate model Brand` → `bin/rails g spree:model Brand`.
//
// If the name already contains a colon (e.g. `spree:model`, `active_storage:install`)
// it's treated as fully-qualified and forwarded as-is. For non-Spree generators
// reach for `spree rails g <name> …` directly.
export function registerGenerateCommand(program: Command): void {
  program
    .command('generate')
    .alias('g')
    .description('Run a Spree generator (auto-prefixes `spree:`)')
    .argument('<name>', 'generator name (`model`, `model_decorator`, …)')
    .argument('[args...]', 'arguments to pass to the generator')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (name: string, args: string[]) => {
      const ctx = detectProject()
      const generator = name.includes(':') ? name : `spree:${name}`
      await dockerComposeExec(['bin/rails', 'g', generator, ...args], ctx.projectDir)
    })
}
