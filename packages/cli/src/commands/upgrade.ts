import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execa } from 'execa'
import pc from 'picocolors'
import { detectProject, hasMonorepoSpreePath, isEjectedProject } from '../context.js'
import {
  appServices,
  dockerCompose,
  dockerComposeCapture,
  dockerComposeExecOrRun,
  isServiceRunning,
  primeBundleVolume,
} from '../docker.js'
import { APP_DIRS, detectPackageManager, generateRouteTree } from './add.js'

interface UpgradeFlags {
  plan?: boolean
  step?: string
  to?: string
  yes?: boolean
}

// One command for both project shapes. The server half depends on where the
// Rails app comes from: a prebuilt-image project pulls the new image (its
// entrypoint migrates on boot), an ejected project bumps the Spree gems and
// migrates itself. Both then run the spree:upgrade rake backfills and bump the
// @spree/* packages of the root and the admin apps. Flags map to env vars on
// the rake task: --plan → DRY_RUN, --step → STEP, --to → TO. --plan and --step
// run the rake task alone.
export function registerUpgradeCommand(program: Command): void {
  withUpgradeOptions(
    program
      .command('upgrade')
      .description(
        'Upgrade Spree: the server (image or gems), migrations, data backfills and @spree/* packages',
      ),
  ).action(upgrade)

  // `update` predates the merge and only pulled the image. Kept one release
  // so existing projects' `update` package scripts keep working.
  withUpgradeOptions(program.command('update', { hidden: true })).action(
    async (flags: UpgradeFlags) => {
      p.log.warn(
        `${pc.bold('spree update')} is deprecated and will be removed in a future release — use ${pc.bold('spree upgrade')}.`,
      )
      await upgrade(flags)
    },
  )
}

function withUpgradeOptions(command: Command): Command {
  return command
    .option(
      '--plan',
      'list the data backfills a run would execute — for the installed Spree version, or the --to version (DRY_RUN=1); runs nothing else',
    )
    .option('--step <id>', 'run a single rake step by id (runs nothing else)')
    .option(
      '--to <version>',
      'explicit target version (auto-detected from installed gem otherwise)',
    )
    .option('--yes', 'skip prompts on automated steps')
}

async function upgrade(flags: UpgradeFlags): Promise<void> {
  const ctx = detectProject()
  await assertUpgradeable(ctx.projectDir)

  if (flags.plan || flags.step) {
    await runRakeUpgrade(ctx.projectDir, flags)
    if (!flags.plan) printPostUpgradeReminder(ctx.projectDir)
    return
  }

  if (isEjectedProject(ctx.projectDir)) {
    const gemsUpdated = await runBundleUpdate(ctx.projectDir, flags)
    await runMigrate(ctx.projectDir, flags)
    await runRakeUpgrade(ctx.projectDir, flags)
    if (gemsUpdated) await restartAppServices(ctx.projectDir)
  } else {
    await pullImage(ctx.projectDir, flags)
    await runRakeUpgrade(ctx.projectDir, flags)
  }

  await updateSpreePackages(ctx.projectDir, flags)

  printPostUpgradeReminder(ctx.projectDir)
}

async function confirmStep(message: string, flags: UpgradeFlags): Promise<boolean> {
  if (flags.yes) return true
  const confirmed = await p.confirm({ message, initialValue: true })
  if (p.isCancel(confirmed)) {
    p.cancel('Upgrade aborted.')
    process.exit(0)
  }
  return confirmed
}

// The image's entrypoint runs db:prepare before Puma starts, and web's
// healthcheck only passes once Puma answers — so `--wait` returns with the
// migrations applied and the container ready for the rake step.
async function pullImage(projectDir: string, flags: UpgradeFlags): Promise<void> {
  if (!(await confirmStep('Pull the latest Spree image and recreate the containers?', flags))) {
    p.log.info('Skipping the image pull.')
    return
  }

  p.log.step(pc.bold('docker compose pull'))
  await dockerCompose(['pull'], projectDir, { stdio: 'inherit' })

  p.log.step(pc.bold('Recreating containers and running migrations'))
  // Prime the shared bundle_cache volume with web alone first so the up
  // below doesn't race the copy-up if this follows a `down -v` (cold volume).
  await primeBundleVolume(projectDir)
  await dockerCompose(['up', '-d', '--wait'], projectDir, { stdio: 'inherit' })
}

// Puma loaded the old gems at boot; the rake steps ran in fresh processes,
// but the server itself only picks up the bumped gems on restart.
async function restartAppServices(projectDir: string): Promise<void> {
  if (!(await isServiceRunning('web', projectDir))) return
  p.log.step(pc.bold('Restarting the app to load the updated gems'))
  await dockerCompose(['restart', ...(await appServices(projectDir))], projectDir, {
    stdio: 'inherit',
  })
}

// Upgrade migrates the DB and runs spree:upgrade rake against the project's
// REAL Postgres + warm bundle_cache. A one-off `compose run` reaches the same
// named volumes (`run`'s depends_on cold-starts postgres, like db:reset), so
// each step falls back to one when web is down. Cheap pre-checks: monorepo-edge
// + the compose stack being inspectable at all.
async function assertUpgradeable(projectDir: string): Promise<void> {
  const refuse = (lines: string[]): never => {
    p.cancel(lines.join('\n'))
    process.exit(1)
  }

  if (hasMonorepoSpreePath(projectDir)) {
    refuse([
      'This is a monorepo edge project (SPREE_PATH set in .env).',
      `Run the upgrade from the monorepo root with ${pc.bold('pnpm server:*')} — the`,
      'project-local docker-compose.yml is not the running config here.',
    ])
  }

  try {
    await isServiceRunning('web', projectDir)
  } catch (err) {
    // `compose ps` itself failed: broken/stale compose, daemon down, unknown
    // service. Point home instead of dumping the raw env-file error. (Backstop
    // for a stale API directory that slipped past detectProject re-rooting.)
    refuse([
      'Could not inspect the Docker stack from this directory.',
      `  ${pc.dim(String((err as Error).message).split('\n')[0])}`,
      '',
      `Run ${pc.bold('spree upgrade')} from your project root (the directory holding the`,
      '.env with SECRET_KEY_BASE), and make sure Docker is running.',
    ])
  }
}

async function runBundleUpdate(projectDir: string, flags: UpgradeFlags): Promise<boolean> {
  if (!(await confirmStep('Run `bundle update` to bump Spree gems?', flags))) {
    p.log.info('Skipping `bundle update`.')
    return false
  }

  // Scope to spree* gems to avoid surprise major bumps on unrelated deps.
  const spreeGems = await detectSpreeGems(projectDir)
  if (spreeGems.length === 0) {
    throw new Error(
      'No Spree gems detected in Gemfile.lock. ' +
        'Confirm the project has `gem "spree"` (or `spree_core`) in its Gemfile.',
    )
  }

  p.log.step(pc.bold(`bundle update ${spreeGems.join(' ')}`))
  await dockerComposeExecOrRun(['bundle', 'update', ...spreeGems], projectDir)
  return true
}

export async function detectSpreeGems(projectDir: string): Promise<string[]> {
  try {
    // Filter in JS rather than piping through grep: `bundle list` exits 0 even
    // with zero spree gems, so a nonzero exit unambiguously means bundler
    // itself errored (out-of-sync lockfile, un-checked-out git source) — no
    // exit-code disambiguation against grep's "no match" needed.
    const stdout = await dockerComposeCapture(['bundle', 'list', '--name-only'], projectDir)
    return stdout
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line.startsWith('spree'))
  } catch (err) {
    const e = err as { stderr?: string }
    // Surface bundler's error + the real next step instead of laundering it
    // into a misleading "No Spree gems detected".
    throw new Error(
      'Could not list gems in the web container — the bundle looks out of sync.\n' +
        'Run `spree bundle install` first, then re-run `spree upgrade`.' +
        (e.stderr?.trim() ? `\n\n${e.stderr.trim()}` : ''),
    )
  }
}

async function runMigrate(projectDir: string, flags: UpgradeFlags): Promise<void> {
  if (!(await confirmStep('Install + run pending migrations?', flags))) {
    p.log.info('Skipping migrations.')
    return
  }
  p.log.step(pc.bold('spree:install:migrations + db:migrate'))
  await dockerComposeExecOrRun(['bin/rails', 'spree:install:migrations', 'db:migrate'], projectDir)
}

async function runRakeUpgrade(projectDir: string, flags: UpgradeFlags): Promise<void> {
  // Flags map to env vars so prod (`STEP=channels rake spree:upgrade`) and dev share the same path.
  const env: Record<string, string> = {}
  if (flags.plan) env.DRY_RUN = '1'
  if (flags.step) env.STEP = flags.step
  if (flags.to) env.TO = flags.to

  p.log.step(pc.bold('spree:upgrade'))
  await dockerComposeExecOrRun(['bin/rake', 'spree:upgrade'], projectDir, { env })
}

// A Spree package the project resolves from the registry. Local specs
// (workspace:, file:, link:, git URLs) point at code the operator manages.
const REGISTRY_SPEC = /^[\^~<>=\d*]|^latest$|^next$/

/**
 * The @spree/* packages a package.json depends on through the registry —
 * what `spree upgrade` bumps there. Returns [] for a missing or unreadable file.
 */
export function detectSpreePackages(dir: string): string[] {
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(dir, 'package.json'), 'utf-8')) as {
      dependencies?: Record<string, string>
      devDependencies?: Record<string, string>
    }
    return Object.entries({ ...pkg.dependencies, ...pkg.devDependencies })
      .filter(([name, spec]) => name.startsWith('@spree/') && REGISTRY_SPEC.test(spec))
      .map(([name]) => name)
  } catch {
    return []
  }
}

/**
 * The package-manager arguments that move the given packages to the newest
 * release their declared range allows, without rewriting that range — the
 * same promise `bundle update` makes against the Gemfile. Yarn Berry's `up`
 * rewrites ranges unless it re-resolves (`-R`); Classic spells it `upgrade`.
 */
export function packageUpdateArgs(
  pm: string,
  packages: string[],
  projectDir: string,
  dir: string,
): string[] {
  if (pm !== 'yarn') return ['update', ...packages]
  const berry = [dir, projectDir].some((candidate) =>
    fs.existsSync(path.join(candidate, '.yarnrc.yml')),
  )
  return berry ? ['up', '-R', ...packages] : ['upgrade', ...packages]
}

// The project root carries @spree/cli; each admin app carries the dashboard
// packages and the Admin SDK. The storefront is the merchant's own fork, so
// its SDK bump stays theirs (see sdkAdvisory).
async function updateSpreePackages(projectDir: string, flags: UpgradeFlags): Promise<void> {
  const targets = ['.', ...APP_DIRS.map((dir) => path.join('apps', dir))]
    .map((relative) => ({ relative, dir: path.join(projectDir, relative) }))
    .map((target) => ({ ...target, packages: detectSpreePackages(target.dir) }))
    .filter((target) => target.packages.length > 0)
  if (targets.length === 0) return

  if (!(await confirmStep('Update the @spree/* packages of the project and admin apps?', flags))) {
    p.log.info('Skipping the @spree/* packages.')
    return
  }

  for (const target of targets) {
    const pm = detectPackageManager(projectDir, target.dir)
    const args = packageUpdateArgs(pm, target.packages, projectDir, target.dir)
    p.log.step(`${pc.bold(`${pm} ${args.join(' ')}`)} ${pc.dim(`in ${target.relative}`)}`)
    await execa(pm, args, { cwd: target.dir, stdio: 'inherit' })
    // An updated dashboard can ship new routes; regenerate now so the next
    // dev start doesn't rewrite the file and reload the open page.
    if (target.relative !== '.') await generateRouteTree(target.dir)
  }
}

// We can detect the conventional create-spree-app storefront and tell the
// operator exactly what to bump.
export function sdkAdvisory(projectDir: string): string {
  const generic = 'Update @spree/sdk in any storefront or integration consuming the API'
  const pkgPath = path.join(projectDir, 'apps', 'storefront', 'package.json')
  if (!fs.existsSync(pkgPath)) return generic
  try {
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8')) as {
      dependencies?: Record<string, string>
      devDependencies?: Record<string, string>
    }
    const declared = pkg.dependencies?.['@spree/sdk'] ?? pkg.devDependencies?.['@spree/sdk']
    if (!declared) return generic
    return `Update @spree/sdk in apps/storefront (currently ${declared}) to the release matching the new Spree version`
  } catch {
    return generic
  }
}

function printPostUpgradeReminder(projectDir: string): void {
  p.note(
    [
      `The manifest only ran ${pc.bold('rake-automatable')} steps.`,
      '',
      "Don't forget the manual parts from the upgrade doc:",
      `  ${pc.dim('- Compare your scheduled jobs (config/recurring.yml) with the upgrade guide')}`,
      `  ${pc.dim(`- ${sdkAdvisory(projectDir)}`)}`,
      `  ${pc.dim('- Review the behavior changes listed in the upgrade guide')}`,
      `  ${pc.dim('- Audit custom decorators against renamed APIs')}`,
      '',
      `Full checklist: ${pc.cyan('https://spreecommerce.org/docs/developer/upgrades/quickstart')}`,
    ].join('\n'),
    'Next steps',
  )
}
