import fs from 'node:fs'
import { platform } from 'node:os'
import path from 'node:path'
import * as p from '@clack/prompts'
import { createAdminClient } from '@spree/admin-sdk'
import type { Command } from 'commander'
import { execa, execaCommand } from 'execa'
import pc from 'picocolors'
import {
  ConfigValidationError,
  deployConfig,
  loadConfig,
  renderReport,
  reportHasFailures,
} from '../config/index.js'
import { mintProjectCredentials, writeAdminEmail, writeProjectSetupMarker } from '../config.js'
import { DASHBOARD_PORT, STOREFRONT_PORT } from '../constants.js'
import { detectProject, readSampleDataFromEnv } from '../context.js'
import {
  dashboardDevRunnable,
  hasDashboardApp,
  startDashboardDevServer,
  warnDashboardNotRunnable,
} from '../dashboard-server.js'
import { dockerCompose, primeBundleVolume, rakeTask, streamLogs } from '../docker.js'
import { detectPackageManager, ensureDashboardDevEnv } from './add.js'
import { DEFAULT_CONFIG_FILE } from './config.js'

const HEALTH_CHECK_INTERVAL_MS = 3000
const HEALTH_CHECK_TIMEOUT_MS = 120_000

export function registerInitCommand(program: Command): void {
  program
    .command('init')
    .description(
      'First-run setup: start services, seed, configure API keys, deploy spree.config.yml',
    )
    .option('--no-sample-data', 'skip loading sample data on scripted installs (see --admin-email)')
    .option('--no-open', 'skip opening browser')
    .option(
      '--admin-email <email>',
      'scripted installs only: seed an admin account instead of printing the setup link',
    )
    .option('--admin-password <password>', 'password for the admin account seeded by --admin-email')
    .action(
      async (flags: {
        sampleData: boolean
        open: boolean
        adminEmail?: string
        adminPassword?: string
      }) => {
        await runFirstRunSetup(flags)
      },
    )
}

/**
 * The whole first-run flow, callable outside the `init` command: `spree dev`
 * delegates here when it detects a project that has never been set up, so
 * create-spree-app's contract — the app just works — holds on every path
 * (--no-start, an interrupted scaffold, a fresh clone) without anyone having
 * to know `spree init` exists.
 */
export async function runFirstRunSetup(flags: {
  sampleData: boolean
  open: boolean
  adminEmail?: string
  adminPassword?: string
}): Promise<void> {
  const ctx = detectProject()

  // Never prompted: the admin account is created on the setup screen the
  // seed prints a link to, which also asks where the store is and whether to
  // load sample data. Flags are for scripted installs, which have no screen,
  // and are checked before Docker starts rather than failing minutes later.
  const { adminEmail, adminPassword } = resolveAdminCredentials(flags)

  // Sample data needs an admin to own its imports, so it loads here only on
  // a scripted install; otherwise the setup screen offers it. `--no-sample-data`
  // always wins; otherwise the choice create-spree-app persisted in .env
  // decides. Load it later any time with `spree sample-data`.
  const sampleData = flags.sampleData && (readSampleDataFromEnv(ctx.projectDir) ?? true)

  p.log.step('Pulling latest images...')
  await dockerCompose(['pull'], ctx.projectDir, { stdio: 'inherit' })

  const s = p.spinner()
  s.start('Starting Docker services...')
  // Prime the shared bundle_cache volume with web alone so the up below
  // doesn't race the cold-volume copy-up. stdio: 'ignore' keeps the spinner
  // clean — the inherited `pull` above already showed image progress.
  await primeBundleVolume(ctx.projectDir, { stdio: 'ignore' })
  await dockerCompose(['up', '-d'], ctx.projectDir)
  s.stop('Docker services started.')

  s.start('Waiting for Spree to be ready...')
  await waitForHealthy(ctx.port)
  s.stop('Spree is ready.')

  s.start('Seeding database...')
  // Omitted entirely when unresolved — the seed treats blank values as "no
  // admin" and prints a setup link instead, which we surface on the card
  // below (rakeTask captures stdout rather than streaming it).
  const seedOutput = await rakeTask(
    'db:seed',
    ctx.projectDir,
    adminEmail && adminPassword
      ? { ADMIN_EMAIL: adminEmail, ADMIN_PASSWORD: adminPassword }
      : undefined,
  )
  // Only the token travels: the seed resolves the URL inside the container,
  // where the dashboard's host and port are unknowable. The card rebuilds the
  // link against whichever dashboard it is about to point the user at.
  const setupToken = seedOutput.match(/\/setup\?token=(\S+)/)?.[1]
  s.stop('Database seeded.')
  // Recorded only when an admin was actually seeded — `spree dev` reads this
  // to name the sign-in email, and an address for an account that does not
  // exist would be worse than saying nothing.
  if (adminEmail && adminPassword) writeAdminEmail(ctx.projectDir, adminEmail)

  s.start('Configuring API keys...')
  // Sequential, not Promise.all: finish the publishable key (and its
  // storefront env write) before minting the secret, so a failure on the
  // first step never leaves a freshly minted secret stranded on disk while
  // init aborts.
  const publishableKey = await fetchApiKey(ctx.projectDir)
  updateStorefrontEnv(ctx.projectDir, publishableKey)
  const secretKey = await mintCliCredentials(ctx.projectDir, ctx.port)
  s.stop('API keys configured.')

  await deployProjectConfig(ctx.projectDir, ctx.port)

  await installAppDeps(ctx.projectDir, 'storefront')
  await installAppDeps(ctx.projectDir, 'dashboard')
  ensureDashboardDevEnv(ctx.projectDir, ctx.port)

  // Sample-data imports need an admin as their owner; without credentials
  // the seed minted none, and the setup screen offers the load instead.
  if (sampleData && adminEmail && adminPassword) {
    s.start('Loading sample data...')
    await rakeTask('spree:load_sample_data', ctx.projectDir)
    s.stop('Sample data loaded.')
  }

  s.start('Indexing products for search...')
  await rakeTask('spree:search:reindex', ctx.projectDir)
  s.stop('Search index ready.')

  writeProjectSetupMarker(ctx.projectDir)

  // With the React Dashboard chosen, its dev server IS the admin — started
  // below alongside the stack, so what the user customizes is what they use.
  // One admin block: the dev server is the only admin URL worth naming. (The
  // production image serves a built dashboard at /dashboard — a deployment
  // detail, not a dev-flow concept.) The summary, --open, and the spawn all
  // key off the same runnable check so they can't disagree — if the dev
  // server can't start (deps install failed above), the card says how to
  // install it instead of advertising a dead URL.
  const dashboardRunnable = dashboardDevRunnable(ctx.projectDir)
  if (hasDashboardApp(ctx.projectDir) && !dashboardRunnable) {
    warnDashboardNotRunnable(ctx.projectDir)
  }
  // No credentials means no admin was seeded — the operator creates one in
  // the browser through the seed's one-time setup link. Built against the
  // dashboard this card is advertising (the dev server `spree dev` starts, or
  // the bundled dashboard the API serves when there is no dev server), since
  // the URL the seed printed used the container's own idea of the host.
  const setupBase = dashboardRunnable
    ? `http://localhost:${DASHBOARD_PORT}`
    : `http://localhost:${ctx.port}/dashboard`
  const credentialLines =
    adminEmail && adminPassword
      ? [`  Email:    ${adminEmail}`, `  Password: ${adminPassword}`]
      : [
          `  ${pc.dim('Create your admin account (and load sample data, if you like):')}`,
          `  ${pc.cyan(
            setupToken
              ? `${setupBase}/setup?token=${setupToken}`
              : 'run `spree run bin/rails spree:setup:token` for the setup link',
          )}`,
        ]

  const adminBlock = dashboardRunnable
    ? [
        pc.bold('Admin Dashboard (React, Developer Preview)'),
        `  ${pc.cyan(`http://localhost:${DASHBOARD_PORT}`)}`,
        ...credentialLines,
        `  ${pc.dim('Live-reloading from apps/dashboard/')}`,
      ]
    : [
        pc.bold('Admin Dashboard'),
        `  ${pc.dim(`Not installed — add it with ${pc.bold('spree add dashboard')}`)}`,
        ...credentialLines,
      ]

  // The wholesale demo needs both the storefront env opt-in and the seeded
  // group/prices (sampleData) to be walkable end to end. The portal runs on
  // the default publishable key — the channel header selects the channel.
  const wholesaleBlock =
    sampleData && storefrontWholesaleChannel(ctx.projectDir)
      ? [
          pc.bold('Wholesale portal (B2B demo)'),
          `  ${pc.cyan(`http://localhost:${STOREFRONT_PORT}/wholesale`)} ${pc.dim('— needs the storefront dev server running')}`,
          `  ${pc.dim('Register a buyer, then approve them in the admin (add to the "Wholesale" customer group)')}`,
          '',
        ]
      : []

  p.note(
    [
      '',
      ...adminBlock,
      '',
      pc.bold('Store API'),
      `  ${pc.cyan(`http://localhost:${ctx.port}/api/v3/store`)}`,
      `  Publishable key: ${pc.cyan(publishableKey)}`,
      '',
      ...wholesaleBlock,
      pc.bold('Admin API'),
      `  ${pc.cyan(`http://localhost:${ctx.port}/api/v3/admin`)}`,
      `  Secret key:      ${pc.cyan(secretKey)}`,
      `  ${pc.dim('Saved to .spree/credentials.json')}`,
      '',
    ].join('\n'),
    'Your Spree store is ready!',
  )

  // Co-run the dashboard's Vite dev server so the admin the card names is
  // actually running. Spawned after the card so its prefixed output doesn't
  // tear through the box. The server runs in its own process group, so
  // Ctrl+C (which would otherwise kill only this CLI and orphan Vite) gets
  // an explicit handler: stop the group, then exit as SIGINT would have.
  // The finally covers non-signal failures (daemon died mid-stream).
  const dashboard = dashboardRunnable ? startDashboardDevServer(ctx.projectDir) : null
  const onSigint = () => {
    dashboard?.stop()
    process.exit(130)
  }
  process.once('SIGINT', onSigint)

  try {
    if (flags.open) {
      // With the dashboard, wait for Vite to report ready (it auto-bumps the
      // port when 5173 is taken) so the browser opens the real URL. Without
      // one there's no admin to open in development, so fall back to the
      // store itself.
      const dashboardUrl = dashboard ? await dashboard.url : null
      // No admin was seeded, so the dashboard would only show a login form
      // nobody can pass — open first-run setup instead and land the operator
      // on the account form directly.
      const target =
        setupToken && dashboardUrl
          ? `${dashboardUrl.replace(/\/$/, '')}/setup?token=${setupToken}`
          : (dashboardUrl ?? `http://localhost:${ctx.port}`)
      await openBrowser(target)
    }

    p.log.info('Streaming logs (Ctrl+C to stop)...\n')
    await streamLogs('web', ctx.projectDir)
  } finally {
    process.removeListener('SIGINT', onSigint)
    dashboard?.stop()
  }
}

// Install an optional app's dependencies when they're missing — a fresh
// clone, or a scaffold whose install step failed — mirroring
// create-spree-app's per-app install steps, so first-run setup leaves every
// app runnable with `pnpm dev`. Best-effort: a registry hiccup shouldn't
// fail backend setup.
async function installAppDeps(projectDir: string, app: 'storefront' | 'dashboard'): Promise<void> {
  const appDir = path.join(projectDir, 'apps', app)
  if (!fs.existsSync(path.join(appDir, 'package.json'))) return
  if (fs.existsSync(path.join(appDir, 'node_modules'))) return

  const pm = detectPackageManager(projectDir, appDir)
  const s = p.spinner()
  s.start(`Installing ${app} dependencies with ${pm}...`)
  try {
    await execa(pm, ['install'], { cwd: appDir })
    s.stop(`${app === 'dashboard' ? 'Dashboard' : 'Storefront'} dependencies installed.`)
  } catch (err) {
    s.stop(pc.yellow(`${pm} install failed — run it manually in apps/${app}/.`))
    p.log.warn(err instanceof Error ? err.message : String(err))
  }
}

async function waitForHealthy(port: number): Promise<void> {
  const url = `http://localhost:${port}/up`
  const start = Date.now()

  while (Date.now() - start < HEALTH_CHECK_TIMEOUT_MS) {
    try {
      const res = await fetch(url)
      if (res.ok) return
    } catch {
      // not ready yet
    }
    await new Promise((resolve) => setTimeout(resolve, HEALTH_CHECK_INTERVAL_MS))
  }

  throw new Error(`Spree did not become healthy within ${HEALTH_CHECK_TIMEOUT_MS / 1000}s`)
}

async function fetchApiKey(projectDir: string): Promise<string> {
  const stdout = await rakeTask('spree:cli:ensure_api_key', projectDir)

  const match = stdout.match(/pk_[A-Za-z0-9_-]+/)
  if (!match) {
    throw new Error(`Could not extract API key from Rails output: ${stdout}`)
  }
  return match[0]
}

/** The channel code the storefront's wholesale portal is configured for, or null when disabled. */
export function storefrontWholesaleChannel(projectDir: string): string | null {
  const envPath = path.join(projectDir, 'apps', 'storefront', '.env.local')
  // Gates a summary hint only — a missing or unreadable env file must never
  // fail setup reporting.
  try {
    return fs.readFileSync(envPath, 'utf-8').match(/^SPREE_WHOLESALE_CHANNEL=(\S+)/m)?.[1] ?? null
  } catch {
    return null
  }
}

/**
 * Mints a fresh read-only secret key into `.spree/credentials.json` so
 * `spree api` works without a first-use minting round-trip.
 *
 * Always mints, overwriting any existing file: `init` reseeds the database
 * immediately before this, so any previously stored key is presumptively
 * orphaned (e.g. after a `docker compose down -v` wipe the host file survives
 * but its DB row is gone). The lazy path in `resolveCredentials` is where a
 * stored key is reused — there the database is intact.
 */
export async function mintCliCredentials(projectDir: string, port: number): Promise<string> {
  // quiet: the init spinner owns the UI and prints the key in the setup summary.
  const { token } = await mintProjectCredentials(projectDir, port, true)
  return token
}

export function updateStorefrontEnv(projectDir: string, apiKey: string): void {
  const envPath = path.join(projectDir, 'apps', 'storefront', '.env.local')
  if (!fs.existsSync(envPath)) return

  const content = fs.readFileSync(envPath, 'utf-8')
  fs.writeFileSync(
    envPath,
    content.replace(/^SPREE_PUBLISHABLE_KEY=.*/m, `SPREE_PUBLISHABLE_KEY=${apiKey}`),
  )
}

/**
 * Deploys the project's `spree.config.yml` — the store's declared shape,
 * committed with the project — against the freshly seeded server. The
 * project's own key is read-only by design, so a write key is minted for
 * this run and revoked as soon as the deploy is over. A project without the
 * file (scaffolded by an older create-spree-app) is left alone.
 */
async function deployProjectConfig(projectDir: string, port: number): Promise<void> {
  const file = path.join(projectDir, DEFAULT_CONFIG_FILE)
  if (!fs.existsSync(file)) return

  let config: ReturnType<typeof loadConfig>['config']
  try {
    ;({ config } = loadConfig(file))
  } catch (error) {
    if (error instanceof ConfigValidationError) {
      p.log.warn(`Skipping ${DEFAULT_CONFIG_FILE}: ${error.message}`)
      return
    }
    throw error
  }

  const s = p.spinner()
  s.start(`Deploying ${DEFAULT_CONFIG_FILE}...`)
  const token = (
    await rakeTask('spree:cli:create_api_key', projectDir, {
      NAME: 'spree init (config deploy)',
      KEY_TYPE: 'secret',
      SCOPES: 'write_all',
      // A revoke that did not happen (Ctrl-C mid-deploy) must not block the
      // next run: the fixed name supersedes the leftover key.
      REPLACE: 'true',
    })
  ).match(/sk_[A-Za-z0-9_-]+/)?.[0]
  if (!token) throw new Error(`Could not mint a key to deploy ${DEFAULT_CONFIG_FILE}.`)

  const client = createAdminClient({ baseUrl: `http://localhost:${port}`, secretKey: token })
  try {
    const report = await deployConfig(config, client)
    if (reportHasFailures(report)) {
      s.stop(pc.yellow(`${DEFAULT_CONFIG_FILE} deployed with failures.`))
      p.log.warn(renderReport(report))
    } else {
      const written = report.results.length
      s.stop(
        written
          ? `${DEFAULT_CONFIG_FILE} deployed (${written} record${written === 1 ? '' : 's'} written).`
          : `${DEFAULT_CONFIG_FILE} deployed (nothing to change).`,
      )
    }
  } catch (error) {
    // Setup still stands without the deploy; the file can be applied by hand.
    s.stop(pc.yellow(`Could not deploy ${DEFAULT_CONFIG_FILE}.`))
    p.log.warn(
      `${error instanceof Error ? error.message : String(error)}\nRun \`spree config deploy\` once the app is up.`,
    )
  } finally {
    // The key exists for this deploy only; revoking it through the API needs
    // no rake round-trip and works whether or not the deploy succeeded.
    try {
      const current = await client.apiKeys.current()
      await client.apiKeys.revoke(current.id)
    } catch {
      p.log.warn(
        'Could not revoke the deploy key; revoke "spree init (config deploy)" with `spree api-key revoke`.',
      )
    }
  }
}

/**
 * Flags only. A run without them seeds no admin at all — the setup link
 * printed by the seed claims the installation instead, so an install never
 * mints a well-known password and the operator answers the store questions
 * once, on the setup screen.
 */
function resolveAdminCredentials(flags: { adminEmail?: string; adminPassword?: string }): {
  adminEmail?: string
  adminPassword?: string
} {
  const { adminEmail, adminPassword } = flags

  // Checked here rather than after Docker start and seeding, minutes later.
  if (adminEmail && !adminEmail.includes('@')) {
    p.cancel(`Invalid --admin-email: ${adminEmail}`)
    process.exit(1)
  }
  if (adminPassword && adminPassword.length < 8) {
    p.cancel('Invalid --admin-password: use at least 8 characters.')
    process.exit(1)
  }
  // One without the other cannot seed an admin; say so rather than silently
  // falling through to the setup-link path the operator did not ask for.
  if (Boolean(adminEmail) !== Boolean(adminPassword)) {
    p.cancel('Pass both --admin-email and --admin-password, or neither.')
    process.exit(1)
  }

  return { adminEmail, adminPassword }
}

async function openBrowser(url: string): Promise<void> {
  const os = platform()
  const cmd = os === 'darwin' ? 'open' : os === 'win32' ? 'start' : 'xdg-open'

  try {
    await execaCommand(`${cmd} ${url}`, { stdio: 'ignore' })
  } catch {
    // best-effort
  }
}
