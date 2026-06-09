import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

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
      await dockerComposeExec(
        ['bin/rails', 'spree:install:migrations', 'db:migrate', ...args],
        ctx.projectDir,
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
      await dockerComposeExec(['bin/rails', 'db:rollback', ...args], ctx.projectDir)
    })

  program
    .command('migrate:status')
    .description('Show migration status (`bin/rails db:migrate:status`)')
    .action(async () => {
      const ctx = detectProject()
      await dockerComposeExec(['bin/rails', 'db:migrate:status'], ctx.projectDir)
    })
}
