import type { Command } from 'commander'
import { runGeneratorCommand, SUPPORTED_GENERATORS } from '../backend.js'
import { detectProject } from '../context.js'
import { warnDeprecated } from '../deprecation.js'
import { dockerComposeExecOrRun } from '../docker.js'

// Rails's own generators, forwarded as-is during the deprecation window so
// `spree generate migration AddX` keeps hitting Rails rather than the
// non-existent `spree:migration`.
const RAILS_BUILTIN_GENERATORS = new Set([
  'migration',
  'controller',
  'scaffold',
  'scaffold_controller',
  'mailer',
  'job',
  'channel',
  'helper',
  'resource',
  'integration_test',
  'system_test',
  'task',
  'generator',
  'benchmark',
])

export function registerGenerateCommand(program: Command): void {
  program
    .command('generate')
    .alias('g')
    .description(
      'Scaffold a Store + Admin API resource (`spree generate api_resource Brand name:string`)',
    )
    .argument('<name>', `generator name (${SUPPORTED_GENERATORS.join(', ')})`)
    .argument('[args...]', 'arguments to pass to the generator')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (name: string, args: string[]) => {
      const ctx = detectProject()
      const generator =
        name.includes(':') || RAILS_BUILTIN_GENERATORS.has(name) ? name : `spree:${name}`

      if (!SUPPORTED_GENERATORS.includes(name.replace(/^spree:/, ''))) {
        warnDeprecated(
          `spree generate ${name}`,
          name.endsWith(':install')
            ? `spree add ${name.slice(0, -':install'.length)}`
            : `spree exec bin/rails generate ${[generator, ...args].join(' ')}`,
        )
      }

      await dockerComposeExecOrRun(runGeneratorCommand(generator, args), ctx.projectDir)
    })
}
