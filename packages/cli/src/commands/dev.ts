import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from '../constants.js'
import { detectProject, hasMonorepoSpreePath } from '../context.js'
import { dockerCompose, primeBundleVolume } from '../docker.js'

export function registerDevCommand(program: Command): void {
  program
    .command('dev')
    .description('Run the app in the foreground — streams web + worker logs; Ctrl+C stops them')
    .action(async () => {
      const ctx = detectProject()

      if (hasMonorepoSpreePath(ctx.projectDir)) {
        p.cancel(
          [
            'This project uses SPREE_PATH for monorepo development.',
            `Use ${pc.bold('pnpm server:dev')} from the monorepo root instead of ${pc.bold('spree dev')}.`,
            'It loads the edge compose overlay and sets SPREE_PATH so the Spree gems resolve to the monorepo source.',
          ].join('\n'),
        )
        process.exit(1)
      }

      p.note(
        [
          '',
          pc.bold('Admin Dashboard'),
          `  ${pc.cyan(`http://localhost:${ctx.port}/admin`)}`,
          `  Email:    ${DEFAULT_ADMIN_EMAIL}`,
          `  Password: ${DEFAULT_ADMIN_PASSWORD}`,
          '',
          pc.bold('Store API'),
          `  ${pc.cyan(`http://localhost:${ctx.port}/api/v3/store`)}`,
          '',
        ].join('\n'),
        'Spree Commerce',
      )

      p.log.info(
        `Starting services — web + worker logs stream below. ${pc.bold('Ctrl+C')} stops them ` +
          `(databases keep running; ${pc.bold('spree stop')} shuts everything down).\n`,
      )

      // Foreground `up`, like `vite dev`: Ctrl+C delivers SIGINT to compose,
      // which gracefully stops web + worker. Dependency services (postgres,
      // redis, meilisearch) start via depends_on but stay up afterwards.
      // Ignore SIGINT in the CLI itself so compose owns the shutdown and we
      // live to print the outro.
      const ignoreSigint = () => {}
      process.on('SIGINT', ignoreSigint)
      let result: { exitCode?: number }
      try {
        // Prime the shared bundle_cache volume with web alone first so the
        // foreground `up web worker` below doesn't race the cold-volume
        // copy-up. web is left running and re-attached (its logs still stream);
        // only worker is newly started by the foreground up. Run INSIDE the
        // SIGINT-ignore guard so a Ctrl+C during the brief priming window can't
        // leave the volume half-populated (a partial copy-up would make the
        // next run's emptiness gate lie). On a warm volume this is a ~1s no-op.
        await primeBundleVolume(ctx.projectDir)
        result = await dockerCompose(['up', 'web', 'worker'], ctx.projectDir, {
          stdio: 'inherit',
          reject: false,
        })
      } finally {
        process.off('SIGINT', ignoreSigint)
      }

      // Ctrl+C lands in compose as SIGINT → graceful stop, exit code 130.
      // Anything else non-zero is a real failure (daemon down, bad config,
      // port conflict) — surface it instead of pretending shutdown was clean.
      const exitCode = result.exitCode ?? 0
      if (exitCode !== 0 && exitCode !== 130) {
        p.cancel(`docker compose exited with code ${exitCode} — see the output above.`)
        process.exit(exitCode)
      }

      p.outro(
        `Web + worker stopped. Databases keep running — ${pc.bold('spree stop')} shuts everything down.`,
      )
    })
}
