import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

export function registerDbCommand(program: Command): void {
  program
    .command('db:reset')
    .description('Drop, create, migrate, and seed the dev database (destructive)')
    .option('--yes', 'skip the confirmation prompt (for CI)')
    .action(async (flags: { yes?: boolean }) => {
      const ctx = detectProject()

      if (!flags.yes) {
        const confirmed = await p.confirm({
          message: 'This will drop the spree_development database. Continue?',
          initialValue: false,
        })
        if (p.isCancel(confirmed) || !confirmed) {
          p.cancel('Cancelled.')
          process.exit(0)
        }
      }

      await dockerComposeExec(
        ['bin/rails', 'db:drop', 'db:create', 'spree:install:migrations', 'db:migrate', 'db:seed'],
        ctx.projectDir,
      )
    })

  program
    .command('db:console')
    .description('Open a psql session against the dev database')
    .action(async () => {
      const ctx = detectProject()
      await dockerComposeExec(['psql', '-U', 'postgres', 'spree_development'], ctx.projectDir, {
        service: 'postgres',
      })
    })
}
