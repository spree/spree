import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

// Two related but independent commands: db:reset (destructive) and db:console
// (read-only). Registered as flat commands rather than under a `spree db`
// parent because Rails uses the same flat style (`rails db:reset`).
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

      // Single Rails invocation chaining all four tasks so any failure short-circuits.
      await dockerComposeExec(
        ['bin/rails', 'db:drop', 'db:create', 'db:migrate', 'db:seed'],
        ctx.projectDir,
      )
    })

  program
    .command('db:console')
    .description('Open a psql session against the dev database')
    .action(async () => {
      const ctx = detectProject()
      // Targets the postgres service, not web. The dev compose sets
      // POSTGRES_HOST_AUTH_METHOD=trust so no password is needed.
      await dockerComposeExec(['psql', '-U', 'postgres', 'spree_development'], ctx.projectDir, {
        service: 'postgres',
      })
    })
}
