import fs from 'node:fs'
import { platform } from 'node:os'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execaCommand } from 'execa'
import pc from 'picocolors'
import { mintProjectCredentials } from '../config.js'
import { DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from '../constants.js'
import { detectProject } from '../context.js'
import { dockerCompose, primeBundleVolume, rakeTask, streamLogs } from '../docker.js'

const HEALTH_CHECK_INTERVAL_MS = 3000
const HEALTH_CHECK_TIMEOUT_MS = 120_000

export function registerInitCommand(program: Command): void {
  program
    .command('init')
    .description('First-run setup: start services, configure API key, load sample data')
    .option('--no-sample-data', 'skip loading sample data')
    .option('--no-open', 'skip opening browser')
    .action(async (flags: { sampleData: boolean; open: boolean }) => {
      await runFirstRunSetup(flags)
    })
}

// The whole first-run flow, callable outside the `init` command: `spree dev`
// delegates here when it detects a project that has never been set up, so
// create-spree-app's contract — the app just works — holds on every path
// (--no-start, an interrupted scaffold, a fresh clone) without anyone having
// to know `spree init` exists.
export async function runFirstRunSetup(flags: {
  sampleData: boolean
  open: boolean
}): Promise<void> {
  const ctx = detectProject()

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
  await rakeTask('db:seed', ctx.projectDir)
  s.stop('Database seeded.')

  s.start('Configuring API keys...')
  // Sequential, not Promise.all: finish the publishable key (and its
  // storefront env write) before minting the secret, so a failure on the
  // first step never leaves a freshly minted secret stranded on disk while
  // init aborts.
  const publishableKey = await fetchApiKey(ctx.projectDir)
  updateStorefrontEnv(ctx.projectDir, publishableKey)
  const secretKey = await mintCliCredentials(ctx.projectDir, ctx.port)
  s.stop('API keys configured.')

  if (flags.sampleData) {
    s.start('Loading sample data...')
    await rakeTask('spree:load_sample_data', ctx.projectDir)
    s.stop('Sample data loaded.')
  }

  s.start('Indexing products for search...')
  await rakeTask('spree:search:reindex', ctx.projectDir)
  s.stop('Search index ready.')

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
      `  Publishable key: ${pc.cyan(publishableKey)}`,
      '',
      pc.bold('Admin API'),
      `  ${pc.cyan(`http://localhost:${ctx.port}/api/v3/admin`)}`,
      `  Secret key:      ${pc.cyan(secretKey)}`,
      `  ${pc.dim('Saved to .spree/credentials.json')}`,
      '',
    ].join('\n'),
    'Your Spree store is ready!',
  )

  if (flags.open) {
    await openBrowser(`http://localhost:${ctx.port}/admin`)
  }

  p.log.info('Streaming logs (Ctrl+C to stop)...\n')
  await streamLogs('web', ctx.projectDir)
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
    content.replace(/SPREE_PUBLISHABLE_KEY=.*/, `SPREE_PUBLISHABLE_KEY=${apiKey}`),
  )
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
