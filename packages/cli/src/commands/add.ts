import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execa } from 'execa'
import pc from 'picocolors'
import { DASHBOARD_PORT } from '../constants.js'
import { detectProject } from '../context.js'
import type { ProjectContext } from '../types.js'

interface AddDashboardOptions {
  /** Git URL or local directory to copy the starter from. */
  template: string
  /** Run the package-manager install after scaffolding. */
  install: boolean
}

// `spree add <thing>` — bolt an optional component onto an existing project.
// Dashboard only for now; storefront parity is planned (see
// docs/plans/5.6-project-layout-and-dashboard.md).
export function registerAddCommand(program: Command) {
  program
    .command('add')
    .description('Add an optional component to your project')
    .argument('<thing>', 'Component to add (currently: dashboard)')
    .option(
      '--template <src>',
      'Starter template: git URL or local path (default: the template bundled with the CLI; env SPREE_DASHBOARD_TEMPLATE overrides)',
    )
    .option('--no-install', 'Skip dependency install')
    .action(async (thing: string, flags: { template?: string; install: boolean }) => {
      if (thing !== 'dashboard') {
        console.error(`\n${pc.red('Error:')} Unknown component: ${thing}. Try: dashboard\n`)
        process.exit(2)
      }

      p.intro(pc.bgCyan(pc.black(' Spree Dashboard ')))
      const ctx = detectProject()
      await addDashboard(ctx, {
        template:
          flags.template ?? process.env.SPREE_DASHBOARD_TEMPLATE ?? resolveBundledTemplate(),
        install: flags.install,
      })
      p.outro('Done!')
    })
}

/**
 * Clone the dashboard starter into `apps/dashboard/` and point it at the
 * project's API. Writes no credentials — the dashboard authenticates admins
 * interactively (email/password → JWT + refresh cookie), and `VITE_`-prefixed
 * env values are compiled into the client bundle, so a key here would ship
 * to every browser.
 *
 * Idempotent: an existing `apps/dashboard/` is left untouched (recovery mode
 * rewrites a missing `.env.local` only).
 */
export async function addDashboard(ctx: ProjectContext, opts: AddDashboardOptions): Promise<void> {
  const dashboardDir = path.join(ctx.projectDir, 'apps', 'dashboard')
  const envPath = path.join(dashboardDir, '.env.local')

  if (fs.existsSync(dashboardDir)) {
    if (fs.existsSync(envPath)) {
      p.log.warn(`${pc.bold('apps/dashboard/')} already exists. Nothing to do.`)
      return
    }
    // Recovery: directory present but env missing (interrupted earlier run).
    writeDashboardEnv(envPath, ctx.port)
    p.log.info(`Wrote missing ${pc.bold('apps/dashboard/.env.local')}. Nothing else to do.`)
    return
  }

  const s = p.spinner()
  s.start('Fetching dashboard starter...')
  try {
    await fetchTemplate(opts.template, dashboardDir)
    restoreGitignore(dashboardDir)
  } catch (err) {
    s.stop('Fetch failed.')
    p.log.error(err instanceof Error ? err.message : String(err))
    process.exit(1)
  }
  s.stop(`Created ${pc.cyan('apps/dashboard/')}`)

  writeDashboardEnv(envPath, ctx.port)

  if (opts.install) {
    const pm = detectPackageManager(ctx.projectDir, dashboardDir)
    s.start(`Installing dependencies with ${pm}...`)
    try {
      await execa(pm, ['install'], { cwd: dashboardDir })
      s.stop('Dependencies installed.')
    } catch (err) {
      s.stop(pc.yellow(`${pm} install failed — run it manually in apps/dashboard/.`))
      p.log.warn(err instanceof Error ? err.message : String(err))
    }
  }

  p.note(
    [
      `Start it with:`,
      `  ${pc.cyan('cd apps/dashboard && ' + (opts.install ? '' : 'pnpm install && ') + 'pnpm dev')}`,
      '',
      `Then open ${pc.bold(`http://localhost:${DASHBOARD_PORT}`)} and sign in`,
      `with your admin email and password.`,
    ].join('\n'),
    'Dashboard added!',
  )
}

/**
 * The dashboard-starter template bundled inside this package. Generated at
 * build time from the monorepo's `packages/dashboard-starter` (workspace
 * deps rewritten to the published versions — see
 * `scripts/sync-dashboard-starter.mjs`) and shipped in `dist/templates/`.
 * Bundling it with the CLI keeps the template and the `@spree/dashboard*`
 * versions it pins in lockstep with every release — there is no separate
 * template repo to drift.
 */
function resolveBundledTemplate(): string {
  const here = path.dirname(fileURLToPath(import.meta.url))
  // dev: src/commands/add.ts → ../../templates/dashboard-starter
  // built: dist/index.js → dist/templates/dashboard-starter
  const candidates = [
    path.resolve(here, '../../templates/dashboard-starter'),
    path.resolve(here, 'templates/dashboard-starter'),
  ]
  for (const candidate of candidates) {
    if (fs.existsSync(path.join(candidate, 'package.json'))) return candidate
  }
  console.error(
    `\n${pc.red('Error:')} Bundled dashboard template not found. In the monorepo, ` +
      `run ${pc.cyan('pnpm build')} in packages/cli first (it generates the template), ` +
      'or pass --template <path|git-url>.\n',
  )
  process.exit(1)
}

/**
 * The bundled template ships its `.gitignore` as `gitignore.template`
 * (npm never packs `.gitignore` files) — restore the real name on scaffold.
 */
function restoreGitignore(dir: string): void {
  const template = path.join(dir, 'gitignore.template')
  if (fs.existsSync(template)) fs.renameSync(template, path.join(dir, '.gitignore'))
}

/** Git-clone a URL template, or copy a local directory (used in tests/CI). */
async function fetchTemplate(template: string, dst: string): Promise<void> {
  if (fs.existsSync(template) && fs.statSync(template).isDirectory()) {
    fs.cpSync(template, dst, {
      recursive: true,
      filter: (src) => {
        const base = path.basename(src)
        return base !== 'node_modules' && base !== 'dist' && base !== '.git'
      },
    })
    return
  }

  await execa('git', ['clone', '--depth', '1', '--', template, dst])
  fs.rmSync(path.join(dst, '.git'), { recursive: true, force: true })
}

function writeDashboardEnv(envPath: string, port: number): void {
  fs.writeFileSync(
    envPath,
    [
      '# URL of your Spree API server. No credentials belong in this file —',
      '# every VITE_-prefixed value is compiled into the client bundle.',
      `VITE_SPREE_API_URL=http://localhost:${port}`,
      '',
    ].join('\n'),
  )
}

/** Prefer the project's own package manager (by lockfile); default to pnpm. */
function detectPackageManager(projectDir: string, dashboardDir: string): string {
  for (const dir of [dashboardDir, projectDir]) {
    if (fs.existsSync(path.join(dir, 'pnpm-lock.yaml'))) return 'pnpm'
    if (fs.existsSync(path.join(dir, 'yarn.lock'))) return 'yarn'
    if (fs.existsSync(path.join(dir, 'package-lock.json'))) return 'npm'
  }
  return 'pnpm'
}
