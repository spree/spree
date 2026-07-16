import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execa } from 'execa'
import pc from 'picocolors'
import { isNotFound } from '../config.js'
import { DASHBOARD_PORT } from '../constants.js'
import { detectProject } from '../context.js'
import type { ProjectContext } from '../types.js'

interface AddDashboardOptions {
  /** Git URL or local directory to copy the starter from. */
  template: string
  /** Run the package-manager install after scaffolding. */
  install: boolean
  /** Skip the final summary note — create-spree-app prints its own. */
  quiet?: boolean
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
    .option('--quiet', 'Skip the final summary note (for wrapping tools that print their own)')
    .action(
      async (thing: string, flags: { template?: string; install: boolean; quiet?: boolean }) => {
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
 * Idempotent: an existing `apps/dashboard/` is left untouched (recovery mode
 * rewrites a missing `.env.local` only).
 */
export async function addDashboard(ctx: ProjectContext, opts: AddDashboardOptions): Promise<void> {
  const dashboardDir = path.join(ctx.projectDir, 'apps', 'dashboard')
  const envPath = path.join(dashboardDir, '.env.local')

  if (fs.existsSync(dashboardDir)) {
    // Recovery: write a missing .env.local (interrupted earlier run) or
    // repair a broken one (old scaffold output) — one gatekeeper for both.
    const env = ensureDashboardDevEnv(ctx.projectDir, ctx.port)
    if (env === 'untouched') {
      p.log.warn(`${pc.bold('apps/dashboard/')} already exists. Nothing to do.`)
      return
    }
    ensureRenderBlueprintService(ctx.projectDir, detectPackageManager(ctx.projectDir, dashboardDir))
    p.log.info(
      `${env === 'written' ? 'Wrote missing' : 'Repaired'} ${pc.bold('apps/dashboard/.env.local')}. Nothing else to do.`,
    )
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

  const pm = detectPackageManager(ctx.projectDir, dashboardDir)
  const blueprint = ensureRenderBlueprintService(ctx.projectDir, pm)
  if (blueprint === 'amended') {
    p.log.info(
      `Amended ${pc.bold('render.yaml')}: the backend service now builds the dashboard ` +
        `and serves it at ${pc.cyan('/dashboard')} — same origin, nothing else to configure.`,
    )
  } else if (blueprint === 'unrecognized') {
    p.log.warn(
      `${pc.bold('render.yaml')} exists but doesn't match the starter Blueprint — ` +
        `left untouched. See the dashboard deployment docs to wire it up manually.`,
    )
  }

  if (opts.install) {
    s.start(`Installing dependencies with ${pm}...`)
    try {
      await execa(pm, ['install'], { cwd: dashboardDir })
      s.stop('Dependencies installed.')
    } catch (err) {
      s.stop(pc.yellow(`${pm} install failed — run it manually in apps/dashboard/.`))
      p.log.warn(err instanceof Error ? err.message : String(err))
    }
  }

  if (opts.quiet) return
  p.note(
    [
      `Start it with:`,
      `  ${pc.cyan(`cd apps/dashboard && ${opts.install ? '' : 'pnpm install && '}pnpm dev`)}`,
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
 * Fold the dashboard into the project's Render Blueprint as **single node**:
 * the backend web service builds `apps/dashboard` in its own build step
 * (Render's Ruby runtime includes Node; the repo is fully cloned even with
 * `rootDir: backend`, so `../apps/dashboard` is reachable) and serves it at
 * /dashboard via `SPREE_DASHBOARD_DIST_PATH`. Same origin as the API — no
 * CORS entries, no `VITE_SPREE_API_URL`, nothing manual after deploy.
 *
 * The amendment anchors on the starter Blueprint's shape (a `buildCommand:`
 * running `bundle install`, followed by that service's `envVars:`). A
 * hand-customized Blueprint where those anchors are missing is left
 * untouched — returns 'unrecognized' so the caller can point at the
 * deployment docs instead of guessing.
 *
 * Idempotent: a Blueprint already carrying SPREE_DASHBOARD_DIST_PATH is
 * left as-is.
 */
export function ensureRenderBlueprintService(
  projectDir: string,
  pm: string,
): 'amended' | 'present' | 'no-blueprint' | 'unrecognized' {
  const renderYamlPath = path.join(projectDir, 'render.yaml')
  if (!fs.existsSync(renderYamlPath)) return 'no-blueprint'

  const content = fs.readFileSync(renderYamlPath, 'utf-8')
  if (content.includes('SPREE_DASHBOARD_DIST_PATH')) return 'present'

  const dashboardBuild =
    pm === 'pnpm'
      ? 'corepack enable pnpm && pnpm install && VITE_BASE_PATH=/dashboard/ pnpm build'
      : pm === 'yarn'
        ? 'yarn install && VITE_BASE_PATH=/dashboard/ yarn build'
        : 'npm install && VITE_BASE_PATH=/dashboard/ npm run build'

  // 1. Extend the Rails build to also build the dashboard (subshell keeps the
  //    working directory intact for any commands appended later).
  const buildCommandRe = /^([ \t]*)buildCommand:.*bundle install.*$/m
  const buildMatch = buildCommandRe.exec(content)
  if (!buildMatch) return 'unrecognized'

  let next = content.replace(
    buildCommandRe,
    (line) => `${line} && (cd ../apps/dashboard && ${dashboardBuild})`,
  )

  // 2. Point the server at the built dist. Anchor on the first `envVars:`
  //    after the build command — the same service's env block. The path is
  //    resolved relative to the service's working directory (rootDir).
  const envVarsRe = /^([ \t]*)envVars:[ \t]*$/m
  const afterBuild = next.slice(next.indexOf('buildCommand:'))
  const envMatch = envVarsRe.exec(afterBuild)
  if (!envMatch) return 'unrecognized'

  const envIndent = `${envMatch[1]}  `
  const envEntry = `${envIndent}# Serve the dashboard built above at /dashboard (single node — same\n${envIndent}# origin as the API, so no CORS or cookie configuration).\n${envIndent}- key: SPREE_DASHBOARD_DIST_PATH\n${envIndent}  value: ../apps/dashboard/dist\n`
  const envVarsIndex = next.indexOf('buildCommand:') + envMatch.index + envMatch[0].length
  next = `${next.slice(0, envVarsIndex)}\n${envEntry.replace(/\n$/, '')}${next.slice(envVarsIndex)}`

  fs.writeFileSync(renderYamlPath, next)
  return 'amended'
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
export function ensureDashboardDevEnv(
  projectDir: string,
  port: number,
): 'written' | 'repaired' | 'untouched' {
  const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
  if (!fs.existsSync(path.join(dashboardDir, 'package.json'))) return 'untouched'

  const envPath = path.join(dashboardDir, '.env.local')
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
export function detectPackageManager(projectDir: string, dashboardDir: string): string {
  for (const dir of [dashboardDir, projectDir]) {
    if (fs.existsSync(path.join(dir, 'pnpm-lock.yaml'))) return 'pnpm'
    if (fs.existsSync(path.join(dir, 'yarn.lock'))) return 'yarn'
    if (fs.existsSync(path.join(dir, 'package-lock.json'))) return 'npm'
  }
  return 'pnpm'
}
