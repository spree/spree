import type { Command } from 'commander'
import pc from 'picocolors'
import { runGeneratorCommand } from '../backend.js'
import { detectProject } from '../context.js'
import { dockerComposeExecOrRun, dockerComposeStream } from '../docker.js'
import { ejectFirst } from '../lib/eject-first.js'
import { formatGeneratorSummary, GeneratorOutput } from '../lib/generator-output.js'

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
    .option('--verbose', "Print the generator's full output instead of a summary")
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (name: string, args: string[], flags: { yes?: boolean; verbose?: boolean }) => {
      const ctx = detectProject()
      const generator =
        name.includes(':') || RAILS_BUILTIN_GENERATORS.has(name) ? name : `spree:${name}`

      // A generator's help writes nothing, so it needs no eject. Options after
      // the generator name belong to the generator, so `--yes` only counts
      // before it — the retry command puts it there.
      const help = args.some((arg) => arg === '--help' || arg === '-h')
      if (!help) {
        await ejectFirst(ctx.projectDir, {
          task: 'Running a generator',
          retry: ['spree', 'generate', '--yes', name, ...args].map(shellQuote).join(' '),
          yes: Boolean(flags.yes),
        })
      }

      const command = runGeneratorCommand(generator, args)
      if (help || flags.verbose) {
        await dockerComposeExecOrRun(command, ctx.projectDir)
      } else {
        await generateWithSummary(generator, command, ctx.projectDir)
      }
    })
}

// How long a line without a newline sits before it counts as a prompt.
const PROMPT_DELAY_MS = 150

/**
 * Run the generator with its output captured, then print only what it
 * created and changed and what to run next. Rails boot and Docker output stay
 * hidden unless the generator fails, when everything it printed is shown.
 */
async function generateWithSummary(
  generator: string,
  command: string[],
  projectDir: string,
): Promise<void> {
  const output = new GeneratorOutput()
  let promptTimer: NodeJS.Timeout | undefined
  const showPrompt = () => {
    if (output.hasPartialLine()) process.stdout.write(output.takePrompt())
  }

  try {
    await dockerComposeStream(command, projectDir, {
      onOutput: (chunk, stream) => {
        output.write(chunk, stream)
        clearTimeout(promptTimer)
        if (output.hasPartialLine()) promptTimer = setTimeout(showPrompt, PROMPT_DELAY_MS)
      },
    })
  } catch (error) {
    clearTimeout(promptTimer)
    output.replay(process)
    const exitCode = (error as { exitCode?: number }).exitCode
    if (typeof exitCode !== 'number') throw error
    console.error(pc.red(`\n${generator} failed (exit code ${exitCode}).`))
    process.exit(exitCode || 1)
  }
  clearTimeout(promptTimer)

  console.log(formatGeneratorSummary(generator, output.result()))
}

function shellQuote(arg: string): string {
  return /^[\w@%+=:,./-]+$/.test(arg) ? arg : `'${arg.replaceAll("'", `'\\''`)}'`
}
