import fs from 'node:fs'
import { platform } from 'node:os'
import path from 'node:path'
import { setTimeout as sleep } from 'node:timers/promises'
import * as p from '@clack/prompts'
import {
  ConfigValidationError,
  deployConfig,
  loadConfig,
  provisionStore,
  renderReport,
  reportHasFailures,
} from '@spree/config/node'
import { sampleData } from '@spree/config/sample-data'
import type { Command } from 'commander'
import { execa } from 'execa'
import pc from 'picocolors'
import { withTemporaryKey } from '../api/temporary-key.js'
import { SEED_TASK, spreeTask } from '../backend.js'
import { mintProjectCredentials, writeAdminEmail, writeProjectSetupMarker } from '../config.js'
import { DASHBOARD_PORT, STOREFRONT_PORT } from '../constants.js'
import { detectProject, isEjectedProject, readSampleDataFromEnv } from '../context.js'
import {
  dashboardDevRunnable,
  hasDashboardApp,
  startDashboardDevServer,
  warnDashboardNotRunnable,
} from '../dashboard-server.js'
import {
  captureTask,
  dockerCompose,
  prepareDatabase,
  primeBundleVolume,
  streamLogs,
} from '../docker.js'
import { loadSampleData } from '../sample-data.js'
import { detectPackageManager, ensureDashboardDevEnv } from './add.js'
import { DEFAULT_CONFIG_FILE } from './config.js'

const HEALTH_CHECK_INTERVAL_MS = 3000
const HEALTH_CHECK_TIMEOUT_MS = 120_000

export function registerInitCommand(program: Command): void {
  program
    .command('init')
    .description(
      'First-run setup: start services, seed, configure API keys, deploy spree.store.yml',
    )
    .option('--no-sample-data', 'skip loading sample data on scripted installs (see --admin-email)')
    .option('--no-open', 'skip opening browser')
    .option(
      '--admin-email <email>',
      'scripted installs only: seed an admin account instead of printing the setup link',
    )
    .option('--admin-password <password>', 'password for the admin account seeded by --admin-email')
    .option(
      '--detach',
      'scripted installs: exit once setup is done, leaving the stack running, instead of starting the dashboard dev server and streaming logs',
    )
    .action(
      async (flags: {
        sampleData: boolean
        open: boolean
        adminEmail?: string
        adminPassword?: string
        detach?: boolean
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
  detach?: boolean
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
  // A registry that is down or rate limiting (Docker Hub's anonymous limit, a
  // CI runner, a machine offline) must not stop init when the images are
  // already here: compose then starts the local copies, and only an image it
  // has never pulled fails, at `up`, with Docker's own message.
  await dockerCompose(['pull', '--ignore-pull-failures'], ctx.projectDir, { stdio: 'inherit' })

  const s = p.spinner()
  // The prebuilt image prepares its database in its entrypoint; the dev
  // compose of an ejected project does not, and its app server exits
  // without one.
  if (isEjectedProject(ctx.projectDir)) {
    s.start('Preparing the development database...')
    await prepareDatabase(ctx.projectDir)
    s.stop('Development database ready.')
  }

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
  // below (captureTask captures stdout rather than streaming it).
  const seedOutput = await captureTask(
    SEED_TASK,
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

  // A scripted install has no setup screen to deploy the store defaults.
  const provisioned = await deployStoreConfiguration(ctx.projectDir, ctx.port, {
    provision: Boolean(adminEmail && adminPassword),
  })

  for (const app of ['dashboard', 'seller-dashboard', 'storefront']) {
    await installAppDeps(ctx.projectDir, app)
  }
  ensureDashboardDevEnv(ctx.projectDir, ctx.port)

  // Sample-data imports need an admin as their owner; without credentials
  // the seed minted none, and the setup screen offers the load instead.
  // Sample data builds on the store defaults, so it waits for a store that
  // got them; `spree sample-data` loads it once `spree config provision` has.
  const sampleDataLoaded = sampleData && provisioned
  if (sampleDataLoaded) {
    await loadSampleDataInto(ctx.projectDir, ctx.port)
  } else if (sampleData && adminEmail && adminPassword) {
    p.log.warn(
      'Sample data skipped: the store defaults are missing. Run `spree config provision`, then `spree sample-data`.',
    )
  } else if (sampleData) {
    p.log.info(
      'Sample data: tick "Load sample data" on the setup screen, or run `spree sample-data` any time later.',
    )
  }

  s.start('Indexing products for search...')
  await captureTask(spreeTask('search:reindex'), ctx.projectDir)
  s.stop('Search index ready.')

  writeProjectSetupMarker(ctx.projectDir)

  // With apps/dashboard present, its dev server IS the admin — started
  // below alongside the stack, so what the user customizes is what they use.
  // One admin block: the dev server is the only admin URL worth naming. (The
  // production image serves a built dashboard at /dashboard — a deployment
  // detail, not a dev-flow concept.) The summary, --open, and the spawn all
  // key off the same runnable check so they can't disagree — if the dev
  // server can't start (deps install failed above), the card says how to
  // install it instead of advertising a dead URL.
  const devDashboardInstalled = dashboardDevRunnable(ctx.projectDir)
  if (hasDashboardApp(ctx.projectDir) && !devDashboardInstalled) {
    warnDashboardNotRunnable(ctx.projectDir)
  }
  // --detach returns before the dev server starts, so the card names the
  // dashboard the API serves instead of a dev server that never comes up.
  const dashboardRunnable = devDashboardInstalled && !flags.detach
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
              : 'run `spree task setup:token` for the setup link',
          )}`,
        ]

  const adminBlock = dashboardRunnable
    ? [
        pc.bold('Admin Dashboard'),
        `  ${pc.cyan(`http://localhost:${DASHBOARD_PORT}`)}`,
        ...credentialLines,
        `  ${pc.dim('Live-reloading from apps/dashboard/')}`,
      ]
    : [
        pc.bold('Admin Dashboard'),
        `  ${pc.cyan(`http://localhost:${ctx.port}/dashboard`)}`,
        ...credentialLines,
        `  ${pc.dim(
          hasDashboardApp(ctx.projectDir)
            ? 'Built-in dashboard — apps/dashboard/ runs once its dependencies are installed'
            : `Built-in dashboard — run ${pc.bold('spree add dashboard')} to customize it`,
        )}`,
      ]

  // The wholesale demo needs both the storefront env opt-in and the seeded
  // group/prices (sampleData) to be walkable end to end. The portal runs on
  // the default publishable key — the channel header selects the channel.
  const wholesaleBlock =
    sampleDataLoaded && storefrontWholesaleChannel(ctx.projectDir)
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

  // A scripted install (CI, a benchmark, a provisioning script) needs init to
  // return; the stack keeps running in Docker either way.
  if (flags.detach) return

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
      // one, open the built-in dashboard the summary names.
      const dashboardUrl = dashboard
        ? ((await dashboard.url) ?? `http://localhost:${DASHBOARD_PORT}`)
        : setupBase
      // No admin was seeded, so the dashboard would only show a login form
      // nobody can pass — open first-run setup instead and land the operator
      // on the account form directly.
      const target = setupToken
        ? `${dashboardUrl.replace(/\/$/, '')}/setup?token=${setupToken}`
        : dashboardUrl
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
async function installAppDeps(projectDir: string, app: string): Promise<void> {
  const appDir = path.join(projectDir, 'apps', app)
  if (!fs.existsSync(path.join(appDir, 'package.json'))) return
  if (fs.existsSync(path.join(appDir, 'node_modules'))) return

  const pm = detectPackageManager(projectDir, appDir)
  const s = p.spinner()
  s.start(`Installing apps/${app}/ dependencies with ${pm}...`)
  try {
    await execa(pm, ['install'], { cwd: appDir })
    s.stop(`apps/${app}/ dependencies installed.`)
  } catch (err) {
    s.stop(pc.yellow(`${pm} install failed — run it manually in apps/${app}/.`))
    p.log.warn(err instanceof Error ? err.message : String(err))
  }
}

export async function waitForHealthy(port: number, signal?: AbortSignal): Promise<void> {
  const url = `http://localhost:${port}/up`
  const start = Date.now()

  while (Date.now() - start < HEALTH_CHECK_TIMEOUT_MS) {
    signal?.throwIfAborted()
    try {
      const res = await fetch(url, { signal })
      if (res.ok) return
    } catch {
      // not ready yet
    }
    await sleep(HEALTH_CHECK_INTERVAL_MS, undefined, { signal })
  }

  throw new Error(`Spree did not become healthy within ${HEALTH_CHECK_TIMEOUT_MS / 1000}s`)
}

async function fetchApiKey(projectDir: string): Promise<string> {
  const stdout = await captureTask(spreeTask('cli:ensure_api_key'), projectDir)

  const match = stdout.match(/pk_[A-Za-z0-9_-]+/)
  if (!match) {
    throw new Error(`Could not extract API key from the backend output: ${stdout}`)
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
 * On a scripted install, which has no setup screen, deploys the store
 * defaults and then the project's `spree.store.yml` — the store's declared
 * shape, committed with the project — against the freshly seeded server. The
 * project's own key is read-only by design, so a write key is minted for
 * this run and revoked as soon as the deploy is over. Answers whether the
 * store defaults were all written, which sample data needs.
 */
const DEPLOY_KEY = 'spree init (config deploy)'
const SAMPLE_DATA_KEY = 'spree init (sample data)'

function warnKeyNotRevoked(name: string): void {
  p.log.warn(
    `Could not revoke the key minted for this run; revoke "${name}" with \`spree api-key revoke\`.`,
  )
}

/**
 * Loads the demo store through the Admin API with a key minted for the run.
 * A failure leaves setup standing: the recipe is safe to run again.
 */
async function loadSampleDataInto(projectDir: string, port: number): Promise<void> {
  const s = p.spinner()
  s.start('Loading sample data...')
  try {
    const { revoked } = await withTemporaryKey(projectDir, port, SAMPLE_DATA_KEY, (client) =>
      loadSampleData(client, sampleData(), (message) => s.message(message)),
    )
    s.stop('Sample data loaded.')
    if (!revoked) warnKeyNotRevoked(SAMPLE_DATA_KEY)
  } catch (error) {
    s.stop(pc.yellow('Could not load sample data.'))
    p.log.warn(
      `${error instanceof Error ? error.message : String(error)}\nRun \`spree sample-data\` once the app is up.`,
    )
  }
}

async function deployStoreConfiguration(
  projectDir: string,
  port: number,
  { provision }: { provision: boolean },
): Promise<boolean> {
  const file = path.join(projectDir, DEFAULT_CONFIG_FILE)
  // Without a scripted admin the store is claimed on the setup screen, which
  // deploys the defaults the project file may refer to; deploying it before
  // that would fail on every such reference.
  if (!provision) {
    if (fs.existsSync(file)) {
      p.log.info(
        `${DEFAULT_CONFIG_FILE} is deployed after first-run setup: run \`spree config deploy\` once the store is set up.`,
      )
    }
    return false
  }
  let config: ReturnType<typeof loadConfig>['config'] | null = null
  if (fs.existsSync(file)) {
    try {
      ;({ config } = loadConfig(file))
    } catch (error) {
      if (!(error instanceof ConfigValidationError)) throw error
      p.log.warn(`Skipping ${DEFAULT_CONFIG_FILE}: ${error.message}`)
    }
  }

  const s = p.spinner()
  // Setup still stands without the deploy; it can be run by hand.
  const skipDeploy = (error: unknown) => {
    s.stop(pc.yellow('Could not configure the store.'))
    p.log.warn(
      `${error instanceof Error ? error.message : String(error)}\nRun \`spree config provision\` and \`spree config deploy\` once the app is up.`,
    )
  }
  s.start('Setting up store defaults...')
  let provisioned = false
  try {
    const { revoked } = await withTemporaryKey(projectDir, port, DEPLOY_KEY, async (client) => {
      const defaults = await provisionStore(client)
      provisioned = !reportHasFailures(defaults)
      const results = [
        ...defaults.results,
        ...(config ? (await deployConfig(config, client)).results : []),
      ]
      const report = { results }
      if (reportHasFailures(report)) {
        s.stop(pc.yellow('Store configured with failures.'))
        p.log.warn(renderReport(report))
      } else {
        s.stop(
          results.length
            ? `Store configured (${results.length} record${results.length === 1 ? '' : 's'} written).`
            : 'Store configured (nothing to change).',
        )
      }
    })
    if (!revoked) warnKeyNotRevoked(DEPLOY_KEY)
  } catch (error) {
    skipDeploy(error)
  }
  return provisioned
}

/**
 * Admin credentials come from flags only, for scripted installs that want a
 * known account. Without them no admin is seeded and the first one is created
 * in the dashboard's own setup screen, which the seed's one-time link opens —
 * so no install, automated or not, mints a well-known password.
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

export async function openBrowser(url: string): Promise<void> {
  const os = platform()
  // `start` is built into cmd.exe rather than a program of its own; its first
  // quoted argument is a window title. An empty argument reaches cmd.exe as
  // `""`, which is that empty title.
  const [cmd, args] =
    os === 'darwin'
      ? ['open', [url]]
      : os === 'win32'
        ? ['cmd', ['/c', 'start', '', url]]
        : ['xdg-open', [url]]

  try {
    await execa(cmd, args, { stdio: 'ignore' })
  } catch {
    // best-effort
  }
}
