import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execa } from 'execa'
import pc from 'picocolors'
import { isNotFound } from '../config.js'
import { DASHBOARD_PORT, SELLER_DASHBOARD_PORT } from '../constants.js'
import { detectProject } from '../context.js'
import type { ProjectContext } from '../types.js'

/**
 * The two admin SPAs `spree add` can scaffold. They differ only in where they
 * live, which bundled template they come from, and which port they serve on —
 * everything else (env file, install, recovery) is identical, so they share
 * one implementation rather than two that drift.
 */
interface AppSpec {
  /** Directory under `apps/`. */
  dir: string
  /** Template directory name inside the CLI's bundled `templates/`. */
  template: string
  /** Env var overriding the bundled template. */
  templateEnvVar: string
  /** Dev-server port, for the closing summary. */
  port: number
  /** Human name used in prompts and messages. */
  label: string
}

const APPS: Record<string, AppSpec> = {
  dashboard: {
    dir: 'dashboard',
    template: 'dashboard-starter',
    templateEnvVar: 'SPREE_DASHBOARD_TEMPLATE',
    port: DASHBOARD_PORT,
    label: 'Dashboard',
  },
  'seller-dashboard': {
    dir: 'seller-dashboard',
    template: 'seller-dashboard-starter',
    templateEnvVar: 'SPREE_SELLER_DASHBOARD_TEMPLATE',
    port: SELLER_DASHBOARD_PORT,
    label: 'Seller Panel',
  },
}

interface AddDashboardOptions {
  /** Git URL or local directory to copy the starter from. */
  template: string
  /** Run the package-manager install after scaffolding. */
  install: boolean
  /** Skip the final summary note — create-spree-app prints its own. */
  quiet?: boolean
}

// `spree add <thing>` — bolt an optional component onto an existing project.
// Dashboard and seller panel for now; storefront parity is planned (see
// docs/plans/5.6-project-layout-and-dashboard.md).
export function registerAddCommand(program: Command) {
  program
    .command('add')
    .description('Add an optional component to your project')
    .argument('<thing>', 'Component to add: dashboard or seller-dashboard')
    .option(
      '--template <src>',
      'Starter template: git URL or local path (default: the template bundled with the CLI; env SPREE_DASHBOARD_TEMPLATE / SPREE_SELLER_DASHBOARD_TEMPLATE overrides)',
    )
    .option('--no-install', 'Skip dependency install')
    .option('--quiet', 'Skip the final summary note (for wrapping tools that print their own)')
    .action(
      async (thing: string, flags: { template?: string; install: boolean; quiet?: boolean }) => {
        const app = APPS[thing]
        if (!app) {
          console.error(
            `\n${pc.red('Error:')} Unknown component: ${thing}. Try: ${Object.keys(APPS).join(', ')}\n`,
          )
          process.exit(2)
        }

        p.intro(pc.bgCyan(pc.black(` Spree ${app.label} `)))
        const ctx = detectProject()
        await addApp(ctx, app, {
          template:
            flags.template ?? process.env[app.templateEnvVar] ?? resolveBundledTemplate(app),
          install: flags.install,
          quiet: flags.quiet,
        })
        p.outro('Done!')
      },
    )
}

/**
 * Clone the dashboard starter into `apps/dashboard/` and point it at the
 * project's API. Writes no credentials — the dashboard authenticates admins
 * interactively (email/password → JWT + refresh cookie), and `VITE_`-prefixed
 * env values are compiled into the client bundle, so a key here would ship
 * to every browser.
 *
 * Idempotent: an existing `apps/<dir>/` is left untouched (recovery mode
 * rewrites a missing `.env.local` only).
 */
export async function addApp(
  ctx: ProjectContext,
  app: AppSpec,
  opts: AddDashboardOptions,
): Promise<void> {
  const appDir = path.join(ctx.projectDir, 'apps', app.dir)
  const envPath = path.join(appDir, '.env.local')

  if (fs.existsSync(appDir)) {
    // Recovery: write a missing .env.local (interrupted earlier run) or
    // repair a broken one (old scaffold output) — one gatekeeper for both.
    const env = ensureAppDevEnv(ctx.projectDir, app.dir, ctx.port)
    if (env === 'untouched') {
      p.log.warn(`${pc.bold(`apps/${app.dir}/`)} already exists. Nothing to do.`)
      return
    }
    p.log.info(
      `${env === 'written' ? 'Wrote missing' : 'Repaired'} ${pc.bold(`apps/${app.dir}/.env.local`)}. Nothing else to do.`,
    )
    return
  }

  const s = p.spinner()
  s.start(`Fetching ${app.label.toLowerCase()} starter...`)
  try {
    await fetchTemplate(opts.template, appDir)
    restoreGitignore(appDir)
  } catch (err) {
    s.stop('Fetch failed.')
    p.log.error(err instanceof Error ? err.message : String(err))
    process.exit(1)
  }
  s.stop(`Created ${pc.cyan(`apps/${app.dir}/`)}`)

  writeDashboardEnv(envPath, ctx.port)

  const pm = detectPackageManager(ctx.projectDir, appDir)

  if (opts.install) {
    s.start(`Installing dependencies with ${pm}...`)
    try {
      await execa(pm, ['install'], { cwd: appDir })
      s.stop('Dependencies installed.')
      await generateRouteTree(appDir)
    } catch (err) {
      s.stop(pc.yellow(`${pm} install failed — run it manually in apps/${app.dir}/.`))
      p.log.warn(err instanceof Error ? err.message : String(err))
    }
  }

  if (opts.quiet) return
  p.note(
    [
      `Start it with:`,
      `  ${pc.cyan(`${pm === 'npm' ? 'npx' : pm} spree dev`)}`,
      `  ${pc.dim('# runs the API and the dashboard together')}`,
      ...(opts.install
        ? []
        : [`  ${pc.dim(`# install dependencies first: cd apps/${app.dir} && ${pm} install`)}`]),
      '',
      `Then open ${pc.bold(`http://localhost:${app.port}`)} and sign in.`,
    ].join('\n'),
    `${app.label} added!`,
  )
}

/**
 * A starter template bundled inside this package. Generated at build time
 * from the monorepo's `packages/<name>` (workspace deps rewritten to the
 * published versions — see `scripts/sync-starter.mjs`) and shipped in
 * `dist/templates/`. Bundling them with the CLI keeps each template and the
 * `@spree/*` versions it pins in lockstep with every release — there is no
 * separate template repo to drift.
 */
function resolveBundledTemplate(app: AppSpec): string {
  const here = path.dirname(fileURLToPath(import.meta.url))
  // dev: src/commands/add.ts → ../../templates/<name>
  // built: dist/index.js → dist/templates/<name>
  const candidates = [
    path.resolve(here, '../../templates', app.template),
    path.resolve(here, 'templates', app.template),
  ]
  for (const candidate of candidates) {
    if (fs.existsSync(path.join(candidate, 'package.json'))) return candidate
  }
  console.error(
    `\n${pc.red('Error:')} Bundled ${app.label.toLowerCase()} template not found. In the monorepo, ` +
      `run ${pc.cyan('pnpm build')} in packages/cli first (it generates the templates), ` +
      'or pass --template <path|git-url>.\n',
  )
  process.exit(1)
}

/**
 * Writes the app's `src/routeTree.gen.ts` for the packages just installed.
 *
 * The template's copy was generated in the monorepo, so the first dev start
 * would rewrite it — and Vite reloads the open page when it notices, which is
 * the setup screen a new project opens straight into. Loading the app's own
 * Vite config runs the same generator, with the same extensions, without
 * starting a server, so that first start finds nothing to change.
 */
async function generateRouteTree(appDir: string): Promise<void> {
  // Best effort: the dev server generates the file on start regardless.
  await execa(
    'node',
    [
      '--input-type=module',
      '-e',
      "const { resolveConfig } = await import('vite'); await resolveConfig({}, 'serve')",
    ],
    { cwd: appDir, reject: false },
  )
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

// Old scaffolds wrote the SDK's absolute-URL switch pointed at localhost —
// requests then bypassed the dev proxy and died on CORS + the SameSite=Lax
// cookie. A localhost value can only be that scaffold output, never a real
// cross-origin production URL, so it's safe to migrate in place.
const BROKEN_SCAFFOLD_ENV = /^VITE_SPREE_API_URL=(https?:\/\/localhost\S*)$/m

/**
 * Writes or repairs `apps/dashboard/.env.local` so dashboard dev works out
 * of the box. Idempotent and cheap — called from `spree add dashboard`,
 * first-run setup, and every `spree dev` boot, covering fresh clones (the
 * file is gitignored) and old scaffolds (see {@link BROKEN_SCAFFOLD_ENV};
 * only that line is rewritten — everything else in the file is user-managed
 * and preserved).
 */
export function ensureAppDevEnv(
  projectDir: string,
  appDirName: string,
  port: number,
): 'written' | 'repaired' | 'untouched' {
  const appDir = path.join(projectDir, 'apps', appDirName)
  if (!fs.existsSync(path.join(appDir, 'package.json'))) return 'untouched'

  const envPath = path.join(appDir, '.env.local')
  let existing: string
  try {
    existing = fs.readFileSync(envPath, 'utf-8')
  } catch (error) {
    if (!isNotFound(error)) throw error // unreadable ≠ missing — never clobber
    writeDashboardEnv(envPath, port)
    return 'written'
  }

  if (!BROKEN_SCAFFOLD_ENV.test(existing)) return 'untouched'
  fs.writeFileSync(
    envPath,
    existing.replace(BROKEN_SCAFFOLD_ENV, `VITE_API_PROXY_TARGET=http://localhost:${port}`),
  )
  return 'repaired'
}

/** Every SPA under `apps/` that `spree dev` and first-run setup keep in sync. */
export const APP_DIRS = Object.values(APPS).map((app) => app.dir)

/**
 * Refresh the dev env file for every scaffolded SPA. Apps that aren't present
 * report 'untouched', so this is safe to call unconditionally.
 */
export function ensureDashboardDevEnv(
  projectDir: string,
  port: number,
): 'written' | 'repaired' | 'untouched' {
  let result: 'written' | 'repaired' | 'untouched' = 'untouched'
  for (const dir of APP_DIRS) {
    const outcome = ensureAppDevEnv(projectDir, dir, port)
    if (outcome !== 'untouched') result = outcome
  }
  return result
}

function writeDashboardEnv(envPath: string, port: number): void {
  fs.writeFileSync(
    envPath,
    [
      '# Dev-server proxy target — where Vite forwards /api and /rails (your',
      '# Rails backend). The SPA stays same-origin with the API: the SDK uses',
      '# relative URLs and the proxy bridges the port gap.',
      '#',
      '# Do NOT set VITE_SPREE_API_URL for local dev — it switches the SDK to',
      '# absolute cross-origin URLs, which breaks on CORS and the SameSite=Lax',
      '# auth cookie. Set it only when building for a deploy where the',
      '# dashboard is hosted on a different origin than the API.',
      '#',
      '# No credentials belong in this file — every VITE_-prefixed value is',
      '# compiled into the client bundle.',
      `VITE_API_PROXY_TARGET=http://localhost:${port}`,
      '',
    ].join('\n'),
  )
}

/** Prefer the project's own package manager (by lockfile); default to pnpm. */
export function detectPackageManager(projectDir: string, appDir: string): string {
  for (const dir of [appDir, projectDir]) {
    if (fs.existsSync(path.join(dir, 'pnpm-lock.yaml'))) return 'pnpm'
    if (fs.existsSync(path.join(dir, 'yarn.lock'))) return 'yarn'
    if (fs.existsSync(path.join(dir, 'package-lock.json'))) return 'npm'
  }
  return 'pnpm'
}
