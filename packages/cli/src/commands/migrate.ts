import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { detectProject } from '../context.js'
import { dockerComposeExec, dockerComposeExecOrRun, isServiceRunning } from '../docker.js'

export function registerMigrateCommand(program: Command): void {
  program
    .command('migrate')
    .description(
      'Install pending Spree migrations from gems, then run them (`spree:install:migrations` + `db:migrate`)',
    )
    .argument('[args...]', 'extra args forwarded to db:migrate')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      const ctx = detectProject()

      // Both Rails tasks are silent when there's nothing to do, which leaves
      // the operator wondering whether anything ran. Print a visible header
      // for each step and a footer summarising the outcome.
      if (await isServiceRunning('web', ctx.projectDir)) {
        console.log(`\n${pc.bold('→ Installing pending Spree migrations from gems...')}`)
        await dockerComposeExec(['bin/rails', 'spree:install:migrations'], ctx.projectDir)

        console.log(`\n${pc.bold('→ Running db:migrate...')}`)
        await dockerComposeExec(['bin/rails', 'db:migrate', ...args], ctx.projectDir)
      } else {
        // One combined invocation on the fallback path: a one-off container
        // pays a cold Rails boot per invocation, so don't pay it twice.
        console.log(`\n${pc.bold('→ Installing + running pending Spree migrations...')}`)
        await dockerComposeExecOrRun(
          ['bin/rails', 'spree:install:migrations', 'db:migrate', ...args],
          ctx.projectDir,
          { edgeHint: 'the edge boot installs and runs pending migrations itself' },
        )
      }

      p.note(
        `Run ${pc.bold('spree migrate:status')} to inspect the migration log.`,
        'Migrations up to date',
      )
    })

  program
    .command('migrate:rollback')
    .description('Roll back the last migration (`STEP=n` to roll back n steps)')
    .argument('[args...]', 'extra args forwarded to db:rollback (e.g. STEP=2)')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      const ctx = detectProject()
      await dockerComposeExecOrRun(['bin/rails', 'db:rollback', ...args], ctx.projectDir)
    })

  program
    .command('migrate:status')
    .description('Show migration status (`bin/rails db:migrate:status`)')
    .action(async () => {
      const ctx = detectProject()
      await dockerComposeExecOrRun(['bin/rails', 'db:migrate:status'], ctx.projectDir)
    })
}
