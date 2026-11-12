import type { Command } from 'commander'
import { runGeneratorCommand } from '../backend.js'
import { detectProject } from '../context.js'
import { dockerComposeExecOrRun } from '../docker.js'
import { ejectFirst } from '../lib/eject-first.js'

// Forwarded as-is so `spree generate migration AddX` hits Rails's own
// generator instead of the non-existent `spree:migration`. `model` is
// intentionally absent — Spree provides `spree:model`.
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
      'Run a generator (Spree generators auto-prefixed; Rails built-ins forwarded as-is)',
    )
    .argument(
      '<name>',
      'generator name (`api_resource`, `model`, `model_decorator`, `migration`, …)',
    )
    .argument('[args...]', 'arguments to pass to the generator')
    .option('-y, --yes', 'Eject a project still on the prebuilt image without asking')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (name: string, args: string[], flags: { yes?: boolean }) => {
      const ctx = detectProject()
      const generator =
        name.includes(':') || RAILS_BUILTIN_GENERATORS.has(name) ? name : `spree:${name}`

      // A generator's help writes nothing, so it needs no eject. Options after
      // the generator name belong to the generator, so `--yes` only counts
      // before it — the retry command puts it there.
      if (!args.some((arg) => arg === '--help' || arg === '-h')) {
        await ejectFirst(ctx.projectDir, {
          task: 'Running a generator',
          retry: ['spree', 'generate', '--yes', name, ...args].map(shellQuote).join(' '),
          yes: Boolean(flags.yes),
        })
      }

      await dockerComposeExecOrRun(runGeneratorCommand(generator, args), ctx.projectDir)
    })
}

function shellQuote(arg: string): string {
  return /^[\w@%+=:,./-]+$/.test(arg) ? arg : `'${arg.replaceAll("'", `'\\''`)}'`
}
