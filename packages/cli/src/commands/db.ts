import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { detectProject, hasMonorepoSpreePath } from '../context.js'
import { dockerCompose, dockerComposeExec, dockerComposeRun, isServiceRunning } from '../docker.js'

export const RESET_TASK = [
  'bin/rails',
  'db:drop',
  'db:create',
  'spree:install:migrations',
  'db:migrate',
  'db:seed',
]

export function registerDbCommand(program: Command): void {
  program
    .command('db:reset')
    .description(
      'Drop, create, migrate, and seed the dev database (destructive; self-heals a running stack)',
    )
    .option('--yes', 'skip the confirmation prompt (for CI)')
    .action(async (flags: { yes?: boolean }) => {
      const ctx = detectProject()

      const refuse = (lines: string[]): never => {
        p.cancel(lines.join('\n'))
        process.exit(1)
      }

      // `compose run` materializes the project-local docker-compose.yml, which
      // is not the running edge config — refuse like bundle.ts / upgrade.ts.
      // The edge stack heals its own dev DB via `pnpm server:*`.
      if (hasMonorepoSpreePath(ctx.projectDir)) {
        refuse([
          'This is a monorepo edge project (SPREE_PATH set in .env).',
          `Reset the dev database from the monorepo root with ${pc.bold('pnpm server:setup')}`,
          '(or the relevant `pnpm server:*` script) — the project-local compose is not the',
          'running config here.',
        ])
      }

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

      // The long-running web (Rails) + worker (Sidekiq) containers hold pooled
      // connections to spree_development. Rails' db:drop issues a PLAIN
      // `DROP DATABASE` (no WITH FORCE), which PostgreSQL rejects while any other
      // session is connected — so a reset against a running stack deadlocks. We
      // stop both regardless of which is up (the worker alone holds up to
      // RAILS_MAX_THREADS pooled connections), so we only need to know if either
      // is running; probe them concurrently.
      let stackUp: boolean
      try {
        const [webUp, workerUp] = await Promise.all([
          isServiceRunning('web', ctx.projectDir),
          isServiceRunning('worker', ctx.projectDir),
        ])
        stackUp = webUp || workerUp
      } catch (err) {
        // `compose ps` itself failed: broken/stale compose, daemon down, unknown
        // service. Point home rather than dumping the raw env-file error (mirrors
        // upgrade.ts; backstop for a stale backend/ past detectProject re-rooting).
        // `return` is load-bearing: it tells TS `stackUp` is assigned past here.
        return refuse([
          'Could not inspect the Docker stack from this directory.',
          `  ${pc.dim(String((err as Error).message).split('\n')[0])}`,
          '',
          `Run ${pc.bold('spree db:reset')} from your project root (the directory holding the`,
          '.env with SECRET_KEY_BASE), and make sure Docker is running.',
        ])
      }

      if (stackUp) {
        const s = p.spinner()
        s.start('Stopping web + worker to release database connections...')
        await dockerCompose(['stop', 'web', 'worker'], ctx.projectDir)
        s.stop('Stopped web + worker.')
      }

      try {
        // One-off container: `run`'s depends_on cold-starts postgres (and waits
        // for service_healthy) but never restarts web/worker, so nothing reopens
        // a blocking connection. Works whether the stack was up, down, or partial.
        await dockerComposeRun(RESET_TASK, ctx.projectDir)
      } catch (err) {
        const stderr = String((err as { stderr?: string }).stderr ?? (err as Error).message ?? '')
        if (/being accessed by other users|55006/.test(stderr)) {
          // We stopped the app containers, so the remaining connection is a host
          // client we can't see or stop (TablePlus/DataGrip/psql on port 5433).
          refuse([
            'Could not drop spree_development — another client is still connected.',
            `A database client (TablePlus, DataGrip, psql) may be connected on port ${pc.bold('5433')}.`,
            'Disconnect it, then re-run `spree db:reset`.',
          ])
        }
        throw err
      }

      p.log.success('Database reset.')
      if (stackUp) {
        // We stopped the operator's running stack to free the drop — they may not
        // realize it, so tell them how to bring it back.
        p.note(`Bring the stack back up with ${pc.bold('spree dev')}.`, 'Done')
      }
    })

  program
    .command('db:console')
    .description('Open a psql session against the dev database')
    .action(async () => {
      const ctx = detectProject()

      // psql needs a live postgres. postgres usually stays warm even when web is
      // down, so guide rather than guess if it isn't running — never `compose run`
      // here, which would start an empty server racing the psql shell.
      let postgresUp: boolean
      try {
        postgresUp = await isServiceRunning('postgres', ctx.projectDir)
      } catch (err) {
        p.cancel(
          [
            'Could not inspect the Docker stack from this directory.',
            `  ${pc.dim(String((err as Error).message).split('\n')[0])}`,
            '',
            `Run ${pc.bold('spree db:console')} from your project root, and make sure Docker is running.`,
          ].join('\n'),
        )
        process.exit(1)
      }

      if (!postgresUp) {
        p.cancel(
          [
            'Postgres is not running.',
            `Start the stack with ${pc.bold('spree dev')}, then re-run ${pc.bold('spree db:console')}.`,
          ].join('\n'),
        )
        process.exit(1)
      }

      await dockerComposeExec(['psql', '-U', 'postgres', 'spree_development'], ctx.projectDir, {
        service: 'postgres',
      })
    })
}
