import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { MIGRATE, MIGRATE_STATUS, rollbackCommand } from '../backend.js'
import { detectProject } from '../context.js'
import { warnDeprecated } from '../deprecation.js'
import { dockerComposeExecOrRun } from '../docker.js'

export function registerMigrateCommand(program: Command): void {
  program
    .command('migrate')
    .description('Install pending Spree migrations, then run them')
    .argument('[args...]')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      if (args.length > 0) {
        warnDeprecated(
          `spree migrate ${args.join(' ')}`,
          `spree migrate, or spree exec bin/rails db:migrate ${args.join(' ')}`,
        )
      }
      const ctx = detectProject()

      // The migration tasks are silent when there's nothing to do, which
      // leaves the operator wondering whether anything ran.
      console.log(`\n${pc.bold('→ Installing + running pending Spree migrations...')}`)
      await dockerComposeExecOrRun([...MIGRATE, ...args], ctx.projectDir, {
        edgeHint: 'the edge boot installs and runs pending migrations itself',
      })

      p.note(
        `Run ${pc.bold('spree migrate:status')} to inspect the migration log.`,
        'Migrations up to date',
      )
    })

  program
    .command('migrate:rollback')
    .description('Roll back the last migration (`--steps n` to roll back n)')
    .option('--steps <n>', 'number of migrations to roll back', parseSteps)
    .argument('[args...]')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[], flags: { steps?: number }) => {
      if (args.length > 0) {
        const step = args.find((arg) => arg.startsWith('STEP='))
        warnDeprecated(
          `spree migrate:rollback ${args.join(' ')}`,
          step
            ? `spree migrate:rollback --steps ${step.slice('STEP='.length)}`
            : 'spree migrate:rollback',
        )
      }
      const ctx = detectProject()
      await dockerComposeExecOrRun(rollbackCommand(flags.steps, args), ctx.projectDir)
    })

  program
    .command('migrate:status')
    .description('Show which migrations have run')
    .action(async () => {
      const ctx = detectProject()
      await dockerComposeExecOrRun(MIGRATE_STATUS, ctx.projectDir)
    })
}

function parseSteps(value: string): number {
  const steps = Number(value)
  if (!Number.isInteger(steps) || steps < 1) {
    throw new Error(`--steps must be a positive whole number, got "${value}"`)
  }
  return steps
}
