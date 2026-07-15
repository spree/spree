import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { projectCredentialsPath } from '../config.js'
import { DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from '../constants.js'
import { detectProject, hasMonorepoSpreePath, isEjectedProject } from '../context.js'
import {
  buildAdminStylesheets,
  dockerCompose,
  hasProjectContainers,
  primeBundleVolume,
  watchAdminStylesheets,
} from '../docker.js'
import { runFirstRunSetup } from './init.js'

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

      // A project that was never set up gets the full first-run flow instead
      // of a bare `up`: pull a fresh image (a mutable tag cached weeks ago by
      // another project would otherwise boot an old Spree), seed the database,
      // mint API keys. This keeps create-spree-app's contract — the app just
      // works — on every path to a first boot (--no-start, an interrupted
      // scaffold, a fresh clone) without requiring anyone to run `spree init`.
      // "Never set up" = init never minted credentials AND compose never
      // created a container, so a torn-down (`docker compose down`) but
      // initialized project boots normally. Ejected projects build the image
      // locally and manage their own lifecycle.
      if (
        !isEjectedProject(ctx.projectDir) &&
        !fs.existsSync(projectCredentialsPath(ctx.projectDir))
      ) {
        let neverBooted = false
        try {
          neverBooted = !(await hasProjectContainers(ctx.projectDir))
        } catch {
          // Daemon trouble surfaces with compose's own error on the up below.
        }
        if (neverBooted) {
          p.log.info('First run detected — completing setup automatically.')
          await runFirstRunSetup({ sampleData: true, open: true })
          return
        }
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

        // On an ejected project the ./backend bind-mount masks the admin
        // stylesheet the image baked into app/assets/builds, and `bin/rails
        // server` never (re)compiles it. First guarantee a compiled file exists
        // for the first paint (the image's is masked; a stack ejected before
        // this CLI shipped never had one), then start the Tailwind watcher so
        // admin source edits recompile live — the dev server `bin/rails server`
        // alone can't offer. Both run against the web container prime just
        // brought up. Non-ejected stacks serve the baked asset from the image,
        // so this is skipped there.
        if (isEjectedProject(ctx.projectDir)) {
          // The dev stack bind-mounts ./backend onto the container's Rails.root,
          // so the stylesheet the tailwind task writes to Rails.root/app/assets/
          // builds lands here on the host.
          const adminStylesheet = path.join(
            ctx.projectDir,
            'backend/app/assets/builds/spree/admin/application.css',
          )
          if (!fs.existsSync(adminStylesheet)) {
            const s = p.spinner()
            s.start('Compiling admin dashboard stylesheets...')
            try {
              await buildAdminStylesheets(ctx.projectDir)
              s.stop('Admin dashboard stylesheets compiled.')
            } catch {
              // Non-fatal: the foreground boot below still streams logs, and the
              // operator can rebuild explicitly. Don't abort dev over assets.
              s.stop('Could not compile admin dashboard stylesheets — admin pages may 500.')
            }
          }

          try {
            await watchAdminStylesheets(ctx.projectDir)
            p.log.info('Watching admin dashboard stylesheets — edits recompile live.')
          } catch {
            // Best-effort: the compiled file above still serves admin pages.
            // A watcher that can't start (e.g. no `listen` gem) just means no
            // live recompile, not a broken boot.
          }
        }

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
