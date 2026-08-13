import fs from 'node:fs'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { projectCredentialsPath, projectSetupMarkerPath, readAdminEmail } from '../config.js'
import { DASHBOARD_PORT } from '../constants.js'
import {
  detectProject,
  hasMonorepoSpreePath,
  isEjectedProject,
  readSampleDataFromEnv,
} from '../context.js'
import {
  dashboardDevRunnable,
  hasDashboardApp,
  startDashboardDevServer,
  warnDashboardNotRunnable,
} from '../dashboard-server.js'
import { appServices, dockerCompose, hasProjectContainers, primeBundleVolume } from '../docker.js'
import { ensureDashboardDevEnv } from './add.js'
import { runFirstRunSetup } from './init.js'

export function registerDevCommand(program: Command): void {
  program
    .command('dev')
    .description(
      'Run the app in the foreground — the API, plus the React Dashboard dev server when apps/dashboard exists; Ctrl+C stops them',
    )
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

      // Every boot, not just first run: cheap and idempotent, and it's how
      // projects scaffolded by older CLIs (broken .env.local) get repaired —
      // they already completed setup, so the first-run path below never
      // reaches them.
      ensureDashboardDevEnv(ctx.projectDir, ctx.port)

      // A project that was never set up gets the full first-run flow instead
      // of a bare `up`: pull a fresh image (a mutable tag cached weeks ago by
      // another project would otherwise boot an old Spree), seed the database,
      // mint API keys. This keeps create-spree-app's contract — the app just
      // works — on every path to a first boot (--no-start, an interrupted
      // scaffold, a fresh clone) without requiring anyone to run `spree init`.
      // Completed setup writes a marker (separate from credentials.json,
      // which `spree auth logout` deletes — losing auth must not look like a
      // fresh project). Credentials still count as "set up" for projects
      // initialized by older CLIs that minted them without a marker. When
      // both are missing: a project whose .env declares SPREE_SAMPLE_DATA was
      // scaffolded by a create-spree-app that persists setup state, so that
      // alone means setup never finished — even if an interrupted init
      // already created containers. For older projects the only safe signal
      // is "compose never created a container": an initialized
      // pre-credentials-era project must not be re-set-up (that would load
      // sample data into a real store). Ejected projects build the image
      // locally and manage their own lifecycle.
      if (
        !isEjectedProject(ctx.projectDir) &&
        !fs.existsSync(projectSetupMarkerPath(ctx.projectDir)) &&
        !fs.existsSync(projectCredentialsPath(ctx.projectDir))
      ) {
        let neverSetUp = readSampleDataFromEnv(ctx.projectDir) !== undefined
        if (!neverSetUp) {
          try {
            neverSetUp = !(await hasProjectContainers(ctx.projectDir))
          } catch {
            // Daemon trouble surfaces with compose's own error on the up below.
          }
        }
        if (neverSetUp) {
          p.log.info('First run detected — completing setup automatically.')
          await runFirstRunSetup({ sampleData: true, open: true })
          return
        }
      }

      // The summary and the spawn key off the same runnable check so the
      // card never advertises a dev server that can't start (deps missing).
      const withDashboard = hasDashboardApp(ctx.projectDir) && dashboardDevRunnable(ctx.projectDir)
      if (hasDashboardApp(ctx.projectDir) && !withDashboard) {
        warnDashboardNotRunnable(ctx.projectDir)
      }
      p.note(
        [
          '',
          ...(withDashboard
            ? [
                pc.bold('Admin Dashboard (React, Developer Preview)'),
                `  ${pc.cyan(`http://localhost:${DASHBOARD_PORT}`)}`,
                `  Email:    ${readAdminEmail(ctx.projectDir) ?? 'spree@example.com'}`,
                `  Password: ${pc.dim('chosen during spree init')}`,
                `  ${pc.dim('Live-reloading from apps/dashboard/')}`,
              ]
            : [
                pc.bold('Admin Dashboard'),
                `  ${pc.dim(`Not installed — add it with ${pc.bold('spree add dashboard')}`)}`,
                `  Email:    ${readAdminEmail(ctx.projectDir) ?? 'spree@example.com'}`,
                `  Password: ${pc.dim('chosen during spree init')}`,
              ]),
          '',
          pc.bold('Store API'),
          `  ${pc.cyan(`http://localhost:${ctx.port}/api/v3/store`)}`,
          '',
        ].join('\n'),
        'Spree Commerce',
      )

      p.log.info(
        `Starting services — ${withDashboard ? 'API + dashboard logs' : 'API logs'} stream below. ` +
          `${pc.bold('Ctrl+C')} stops them ` +
          `(databases keep running; ${pc.bold('spree stop')} shuts everything down).\n`,
      )

      // Foreground `up`, like `vite dev`: Ctrl+C delivers SIGINT to compose,
      // which gracefully stops web + worker. Dependency services (postgres,
      // mailpit) start via depends_on but stay up afterwards.
      // Ignore SIGINT in the CLI itself so compose owns the shutdown and we
      // live to print the outro.
      const ignoreSigint = () => {}
      process.on('SIGINT', ignoreSigint)
      let result: { exitCode?: number }
      let dashboard: ReturnType<typeof startDashboardDevServer> = null
      try {
        // Prime the shared bundle_cache volume with web alone first so the
        // foreground `up web worker` below doesn't race the cold-volume
        // copy-up. web is left running and re-attached (its logs still stream);
        // only worker is newly started by the foreground up. Run INSIDE the
        // SIGINT-ignore guard so a Ctrl+C during the brief priming window can't
        // leave the volume half-populated (a partial copy-up would make the
        // next run's emptiness gate lie). On a warm volume this is a ~1s no-op.
        await primeBundleVolume(ctx.projectDir)

        // Co-run the dashboard's Vite dev server with the Docker stack — one
        // command, the whole dev environment. Its output joins the stream
        // below with a `dashboard |` prefix; the terminal's Ctrl+C reaches it
        // alongside compose (same foreground process group), and stop() in
        // the finally covers non-signal exits.
        dashboard = withDashboard ? startDashboardDevServer(ctx.projectDir) : null

        result = await dockerCompose(
          ['up', ...(await appServices(ctx.projectDir))],
          ctx.projectDir,
          {
            stdio: 'inherit',
            reject: false,
          },
        )
      } finally {
        dashboard?.stop()
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
        `${withDashboard ? 'API + dashboard' : 'API'} stopped. Databases keep running — ${pc.bold('spree stop')} shuts everything down.`,
      )
    })
}
