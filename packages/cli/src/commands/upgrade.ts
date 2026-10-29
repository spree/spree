import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execa } from 'execa'
import pc from 'picocolors'
import semver from 'semver'
import {
  INSTALL_PACKAGES,
  LIST_PACKAGES,
  MIGRATE,
  UPGRADE,
  updatePackagesCommand,
} from '../backend.js'
import { detectProject, hasMonorepoSpreePath, isEjectedProject } from '../context.js'
import {
  dockerCompose,
  dockerComposeCapture,
  dockerComposeExecOrRun,
  dockerStackProblem,
  isServiceRunning,
  primeBundleVolume,
  restartAppServices,
} from '../docker.js'
import { RELEASE_LINE, type ReleaseLine, releaseLineFor } from '../lib/release-line.js'
import { APP_DIRS, detectPackageManager, generateRouteTree } from './add.js'

interface UpgradeFlags {
  plan?: boolean
  step?: string
  to?: string
  yes?: boolean
}

// One command for both project shapes. The server half depends on where the
// Rails app comes from: a prebuilt-image project pulls the new image (its
// entrypoint migrates when the containers are recreated), an ejected project
// bumps the Spree gems and migrates itself. The @spree/* packages of the root
// and the admin apps are bumped right after the server, before migrations and
// the spree:upgrade rake backfills, so a failing backfill can't leave the
// dashboards on the old release. Flags map to env vars on the rake task:
// --plan → DRY_RUN, --step → STEP, --to → TO. --plan and --step run the rake
// task alone.
export function registerUpgradeCommand(program: Command): void {
  withUpgradeOptions(
    program
      .command('upgrade')
      .description('Upgrade Spree: the server, @spree/* packages, migrations and data backfills'),
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
      'list the data backfills a run would execute — for the installed Spree version, or the --to version; runs nothing else',
    )
    .option('--step <id>', 'run a single upgrade step by id (runs nothing else)')
    .option(
      '--to <version>',
      'explicit target version (auto-detected from the installed Spree otherwise)',
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

  let line: ReleaseLine
  if (isEjectedProject(ctx.projectDir)) {
    const gemsUpdated = await runBundleUpdate(ctx.projectDir, flags)
    line = await serverReleaseLine(ctx.projectDir, { fromNewImage: false })
    await updateSpreePackages(ctx.projectDir, flags, line)
    await runMigrate(ctx.projectDir, flags)
    await runRakeUpgrade(ctx.projectDir, flags)
    // Puma loaded the old gems at boot; the rake steps ran in fresh processes.
    if (gemsUpdated)
      await restartAppServices(
        ctx.projectDir,
        'Restarting the app to load the updated Spree packages',
      )
  } else {
    const imagePulled = await pullImage(ctx.projectDir, flags)
    line = await serverReleaseLine(ctx.projectDir, { fromNewImage: imagePulled })
    await updateSpreePackages(ctx.projectDir, flags, line)
    if (imagePulled) await recreateContainers(ctx.projectDir)
    await runRakeUpgrade(ctx.projectDir, flags)
  }

  printPostUpgradeReminder(ctx.projectDir, line)
}

/**
 * The Spree version the server runs after its update, as the release line the
 * packages move to. The CLI that runs an upgrade was installed before it, so
 * the version built into it can be a release behind the server. A freshly
 * pulled image is read from a one-off container, since the running one still
 * has the old image until it is recreated.
 */
async function serverReleaseLine(
  projectDir: string,
  { fromNewImage }: { fromNewImage: boolean },
): Promise<ReleaseLine> {
  try {
    const stdout = fromNewImage
      ? (
          await execa(
            'docker',
            ['compose', 'run', '--rm', '--no-deps', '-T', 'web', 'bundle', 'list'],
            { cwd: projectDir },
          )
        ).stdout
      : await dockerComposeCapture(['bundle', 'list'], projectDir)
    const installed = stdout.match(/\bspree_core \(([^)\s]+)/)?.[1]
    if (installed) return releaseLineFor(installed, RELEASE_LINE)
  } catch {
    // Fall through to the version this CLI was built with.
  }
  p.log.warn(
    `Could not read the server's Spree version; moving the @spree/* packages to ${RELEASE_LINE.version}.`,
  )
  return RELEASE_LINE
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

async function pullImage(projectDir: string, flags: UpgradeFlags): Promise<boolean> {
  if (!(await confirmStep('Pull the latest Spree image and recreate the containers?', flags))) {
    p.log.info('Skipping the image pull.')
    return false
  }

  p.log.step(pc.bold('docker compose pull'))
  await dockerCompose(['pull'], projectDir, { stdio: 'inherit' })
  return true
}

// The image's entrypoint runs db:prepare before Puma starts, and web's
// healthcheck only passes once Puma answers — so `--wait` returns with the
// migrations applied and the container ready for the rake step.
async function recreateContainers(projectDir: string): Promise<void> {
  p.log.step(pc.bold('Recreating containers and running migrations'))
  // Prime the shared bundle_cache volume with web alone first so the up
  // below doesn't race the copy-up if this follows a `down -v` (cold volume).
  await primeBundleVolume(projectDir)
  await dockerCompose(['up', '-d', '--wait'], projectDir, { stdio: 'inherit' })
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
    // `compose ps` itself failed: daemon down, broken/stale compose, unknown
    // service. (Backstop for a stale API directory that slipped past
    // detectProject re-rooting.)
    refuse(dockerStackProblem(err, 'spree upgrade'))
  }
}

async function runBundleUpdate(projectDir: string, flags: UpgradeFlags): Promise<boolean> {
  if (!(await confirmStep('Update the Spree packages?', flags))) {
    p.log.info('Skipping the Spree package update.')
    return false
  }

  // Scope to spree* gems to avoid surprise major bumps on unrelated deps.
  const spreeGems = await detectSpreeGems(projectDir)
  if (spreeGems.length === 0) {
    throw new Error(
      'No Spree packages detected in the backend dependencies. ' +
        'Confirm the project has `gem "spree"` (or `spree_core`) in its Gemfile.',
    )
  }

  p.log.step(pc.bold(`Updating ${spreeGems.join(' ')}`))
  await dockerComposeExecOrRun(updatePackagesCommand(spreeGems), projectDir)
  return true
}

// A bundle out of sync with Gemfile.lock (a pulled lockfile change, a cold
// bundle_cache volume, an un-checked-out git source) makes `bundle list` fail.
// `bundle install` is the fix every time, so run it and list again rather than
// sending the operator off to run it by hand.
export async function detectSpreeGems(projectDir: string): Promise<string[]> {
  try {
    return await listSpreeGems(projectDir)
  } catch {
    p.log.step(
      pc.bold('Installing backend dependencies') +
        pc.dim(' — they are out of sync with the lockfile'),
    )
    await dockerComposeExecOrRun(INSTALL_PACKAGES, projectDir)
  }

  try {
    return await listSpreeGems(projectDir)
  } catch (err) {
    const e = err as { stderr?: string }
    throw new Error(
      'Could not list the Spree packages in the web container, even after reinstalling the backend dependencies.' +
        (e.stderr?.trim() ? `\n\n${e.stderr.trim()}` : ''),
    )
  }
}

// Filter in JS rather than piping through grep: `bundle list` exits 0 even
// with zero spree gems, so a nonzero exit unambiguously means bundler itself
// errored.
async function listSpreeGems(projectDir: string): Promise<string[]> {
  const stdout = await dockerComposeCapture(LIST_PACKAGES, projectDir)
  return stdout
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.startsWith('spree'))
}

async function runMigrate(projectDir: string, flags: UpgradeFlags): Promise<void> {
  if (!(await confirmStep('Install + run pending migrations?', flags))) {
    p.log.info('Skipping migrations.')
    return
  }
  p.log.step(pc.bold('Installing + running pending migrations'))
  await dockerComposeExecOrRun(MIGRATE, projectDir)
}

async function runRakeUpgrade(projectDir: string, flags: UpgradeFlags): Promise<void> {
  // --plan and --step already name the rake run the operator asked for.
  const explicit = flags.plan || flags.step
  if (!explicit && !(await confirmStep('Run the Spree upgrade tasks (data backfills)?', flags))) {
    p.log.info('Skipping the upgrade tasks.')
    return
  }

  // Flags map to env vars so production and dev runs share the same path.
  const env: Record<string, string> = {}
  if (flags.plan) env.DRY_RUN = '1'
  if (flags.step) env.STEP = flags.step
  if (flags.to) env.TO = flags.to

  p.log.step(pc.bold('Running upgrade steps'))
  await dockerComposeExecOrRun(UPGRADE, projectDir, { env })
}

// A Spree package the project resolves from the registry. Local specs
// (workspace:, file:, link:, git URLs) point at code the operator manages.
const REGISTRY_SPEC = /^[\^~<>=\d*]|^latest$|^next$/

// A single version (`6.0.0-rc.7`) rather than a range. `update` keeps a
// declared range, and a single version is a range nothing else satisfies.
const EXACT_VERSION = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/

// A peer range read from the registry is written into the app's package.json,
// so only a valid semver range is taken (no aliases, URLs or paths), and never
// one with a control character, which semver trims but JSON can't hold raw.
function isPlainRange(range: unknown): range is string {
  return (
    typeof range === 'string' &&
    [...range].every((character) => character.charCodeAt(0) >= 0x20) &&
    semver.validRange(range) !== null
  )
}

export interface SpreePackage {
  name: string
  spec: string
  dev: boolean
}

interface PackageJson {
  dependencies?: Record<string, string>
  devDependencies?: Record<string, string>
  packageManager?: string
}

/**
 * The @spree/* packages a package.json depends on through the registry —
 * what `spree upgrade` bumps there. Returns [] for a missing or unreadable file.
 */
export function detectSpreePackages(dir: string): SpreePackage[] {
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(dir, 'package.json'), 'utf-8')) as PackageJson
    return [
      ...Object.entries(pkg.dependencies ?? {}).map(([name, spec]) => ({ name, spec, dev: false })),
      ...Object.entries(pkg.devDependencies ?? {}).map(([name, spec]) => ({
        name,
        spec,
        dev: true,
      })),
    ].filter(({ name, spec }) => name.startsWith('@spree/') && REGISTRY_SPEC.test(spec))
  } catch {
    return []
  }
}

export function isExactVersion(spec: string): boolean {
  return EXACT_VERSION.test(spec)
}

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function isReleasedPin(spec: string, line: ReleaseLine): boolean {
  return spec.includes('-') && !line.version.includes('-') && isOlderVersion(spec, line.version)
}

function isOlderLine(spec: string, line: ReleaseLine): boolean {
  const declared = spec.match(/(\d+)\./)
  return declared !== null && Number(declared[1]) < Number(line.version.split('.')[0])
}

/**
 * Rewrites the specs in a package.json that the update that follows could not
 * move to the Spree version the server runs, for packages released with Spree:
 *
 * - a range on an older version line: from 6.0 these packages share the Spree
 *   version, and `^1.0.0-rc.7` never resolves to 6.x on its own
 * - a release candidate pin, once the server is on a final version: pnpm 11's
 *   `update` writes a prerelease back as an exact version, so the pin is
 *   pnpm's rather than the operator's, and `6.0.0-rc.7` becomes `^6.0.0`
 *
 * Both become a `^` range on the server's version, which a locked prerelease
 * never satisfies, so the update installs it. Other exact versions are left
 * for the upgrade to install by name, so they stay exact. The file is edited
 * as text so its formatting is kept.
 *
 * @param dir directory holding the package.json
 * @param line the packages released with Spree and the version to move to
 * @returns the rewritten packages with their old and new ranges, [] when none
 */
export function moveToReleaseLine(
  dir: string,
  line: ReleaseLine = RELEASE_LINE,
): Array<{ name: string; from: string; to: string }> {
  const manifestPath = path.join(dir, 'package.json')
  let source: string
  let pkg: PackageJson
  try {
    source = fs.readFileSync(manifestPath, 'utf-8')
    pkg = JSON.parse(source)
  } catch {
    return []
  }

  const to = `^${line.version}`
  const moved = Object.entries({ ...pkg.dependencies, ...pkg.devDependencies })
    .filter(([name, spec]) => line.packages.includes(name) && REGISTRY_SPEC.test(spec))
    .filter(([, spec]) =>
      isExactVersion(spec) ? isReleasedPin(spec, line) : isOlderLine(spec, line),
    )
    .map(([name, from]) => ({ name, from, to }))

  for (const { name, from } of moved) {
    const declaration = new RegExp(`("${escapeRegExp(name)}"\\s*:\\s*)"${escapeRegExp(from)}"`, 'g')
    source = source.replace(declaration, `$1"${to}"`)
  }
  if (moved.length > 0) fs.writeFileSync(manifestPath, source)
  return moved
}

/**
 * The third-party peer ranges the given @spree/* packages declare at the
 * versions about to be installed, read from the registry before installing:
 * npm refuses an install whose peers don't match, so the app's own ranges have
 * to move first. Where two packages name the same peer, the higher floor wins.
 * A package the registry can't answer for is skipped, leaving its peers to
 * the package manager's own warnings.
 *
 * @param dir directory the registry is queried from, for its .npmrc
 * @param packages the @spree/* packages and the specs they will be installed at
 * @returns peer name → range, {} when nothing could be read
 */
export async function spreePeerRanges(
  dir: string,
  packages: Array<{ name: string; spec: string }>,
): Promise<Record<string, string>> {
  const ranges: Record<string, string> = {}
  for (const { name, spec } of packages) {
    let peers: Record<string, string>
    try {
      const { stdout } = await execa(
        'npm',
        ['view', `${name}@${spec}`, 'peerDependencies', '--json'],
        {
          cwd: dir,
        },
      )
      // A range several versions match answers with one entry per version, oldest first.
      const parsed = stdout.trim() ? JSON.parse(stdout) : {}
      peers = (Array.isArray(parsed) ? parsed.at(-1) : parsed) ?? {}
    } catch {
      p.log.warn(
        `Could not read the peer dependencies of ${name}@${spec}; leaving them as they are.`,
      )
      continue
    }
    for (const [peer, range] of Object.entries(peers)) {
      if (peer.startsWith('@spree/') || !isPlainRange(range)) continue
      const current = Object.hasOwn(ranges, peer) ? ranges[peer] : null
      if (!current || semver.gt(minVersionOf(range), minVersionOf(current))) ranges[peer] = range
    }
  }
  return ranges
}

/**
 * Rewrites the app's own ranges for Spree's peer dependencies (React Hook
 * Form, i18next, the TanStack libraries, …) that admit a version Spree's range
 * doesn't (`^7.75.0` against `^7.90.0`). A range already inside Spree's, for
 * any of its alternatives, stays as it is. Left alone, the app keeps its older copy: npm refuses the install,
 * and pnpm installs it with a warning, leaving Spree's components typed and
 * tested against a version the app doesn't run. Each becomes Spree's range,
 * so the update that follows checks against it. An exact version is marked
 * `exact` for the caller to pin again at the newest release the range allows:
 * the range's floor need not be a published version. The file is edited as
 * text so its formatting is kept.
 *
 * @param dir directory holding the package.json
 * @param peers peer name → the range Spree requires (see spreePeerRanges)
 * @returns the rewritten dependencies, [] when none
 */
export function alignPeerRanges(
  dir: string,
  peers: Record<string, string>,
): Array<{ name: string; from: string; to: string; dev: boolean; exact: boolean }> {
  const manifestPath = path.join(dir, 'package.json')
  let source: string
  let pkg: PackageJson
  try {
    source = fs.readFileSync(manifestPath, 'utf-8')
    pkg = JSON.parse(source)
  } catch {
    return []
  }

  const moved = [
    ...Object.entries(pkg.dependencies ?? {}).map(([name, from]) => ({ name, from, dev: false })),
    ...Object.entries(pkg.devDependencies ?? {}).map(([name, from]) => ({ name, from, dev: true })),
  ]
    .filter(({ name, from }) => Object.hasOwn(peers, name) && REGISTRY_SPEC.test(from))
    .filter(
      ({ name, from }) => semver.validRange(from) !== null && !semver.subset(from, peers[name]),
    )
    .map((dependency) => ({
      ...dependency,
      to: peers[dependency.name],
      exact: isExactVersion(dependency.from),
    }))

  for (const { name, from, to } of moved) {
    const declaration = new RegExp(`("${escapeRegExp(name)}"\\s*:\\s*)"${escapeRegExp(from)}"`, 'g')
    source = source.replace(declaration, `$1"${to}"`)
  }
  if (moved.length > 0) fs.writeFileSync(manifestPath, source)
  // Listed in both groups, each declaration moves, but it is installed once,
  // from `dependencies`.
  return moved.filter(({ name, dev }) => !(dev && pkg.dependencies?.[name]))
}

function minVersionOf(range: string): string {
  return semver.minVersion(range)?.version ?? '0.0.0'
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
  return isYarnBerry(projectDir, dir) ? ['up', '-R', ...packages] : ['upgrade', ...packages]
}

/**
 * The package-manager arguments that install the given `name@version` specs
 * and record them as exact versions again, in the group they are declared in.
 */
export function packageAddArgs(pm: string, specs: string[], dev: boolean): string[] {
  if (pm === 'yarn') return ['add', '--exact', ...(dev ? ['--dev'] : []), ...specs]
  const command = pm === 'npm' ? 'install' : 'add'
  return [command, '--save-exact', ...(dev ? ['--save-dev'] : []), ...specs]
}

/**
 * The package-manager arguments that fold duplicate copies of a package into
 * one, or null where the package manager has no such command (Yarn Classic).
 * An updated package can pin a dependency, such as `@codemirror/view`, newer
 * than the copy the lockfile already holds for packages that take it by range;
 * the two copies then clash in type checks until they are folded together.
 */
export function packageDedupeArgs(pm: string, projectDir: string, dir: string): string[] | null {
  if (pm === 'yarn' && !isYarnBerry(projectDir, dir)) return null
  return ['dedupe']
}

function isYarnBerry(projectDir: string, dir: string): boolean {
  return [dir, projectDir].some((candidate) => {
    if (fs.existsSync(path.join(candidate, '.yarnrc.yml'))) return true
    try {
      const pkg = JSON.parse(
        fs.readFileSync(path.join(candidate, 'package.json'), 'utf-8'),
      ) as PackageJson
      const major = pkg.packageManager?.match(/^yarn@(\d+)\./)?.[1]
      return major !== undefined && Number(major) >= 2
    } catch {
      return false
    }
  })
}

function compareIdentifiers(left: string, right: string): number {
  const leftNumeric = /^\d+$/.test(left)
  const rightNumeric = /^\d+$/.test(right)
  if (leftNumeric && rightNumeric) return Number(left) - Number(right)
  if (leftNumeric !== rightNumeric) return leftNumeric ? -1 : 1
  return left < right ? -1 : left > right ? 1 : 0
}

/**
 * Whether one exact version sorts before another under semver precedence: the
 * release numbers first, then a prerelease (`6.0.0-rc.7`) before its release,
 * then prerelease identifiers one by one.
 */
export function isOlderVersion(version: string, than: string): boolean {
  const [leftRelease, leftPrerelease] = splitVersion(version)
  const [rightRelease, rightPrerelease] = splitVersion(than)
  for (let index = 0; index < 3; index++) {
    const difference = leftRelease[index] - rightRelease[index]
    if (difference !== 0) return difference < 0
  }
  if (leftPrerelease.length === 0 || rightPrerelease.length === 0) {
    return leftPrerelease.length > rightPrerelease.length
  }
  for (let index = 0; index < Math.min(leftPrerelease.length, rightPrerelease.length); index++) {
    const difference = compareIdentifiers(leftPrerelease[index], rightPrerelease[index])
    if (difference !== 0) return difference < 0
  }
  return leftPrerelease.length < rightPrerelease.length
}

function splitVersion(version: string): [number[], string[]] {
  const [release, ...prerelease] = version.split('-')
  const identifiers = prerelease.join('-')
  return [release.split('.').map(Number), identifiers ? identifiers.split('.') : []]
}

// `update` leaves an exact version where it is, so a pinned app would stay on
// the old release while the server moves on. A pin on a package released with
// Spree that is older than the server's Spree version moves to it. A newer pin
// stays, since the server may not have moved (a skipped pull); any other pin is
// the operator's to move. A release candidate pin reaching a final version
// was already turned into a range (see moveToReleaseLine).
function pinnedOffRelease(packages: SpreePackage[], dev: boolean, line: ReleaseLine): string[] {
  return packages
    .filter((pkg) => pkg.dev === dev && isExactVersion(pkg.spec))
    .filter((pkg) => line.packages.includes(pkg.name))
    .filter((pkg) => isOlderVersion(pkg.spec, line.version))
    .map((pkg) => `${pkg.name}@${line.version}`)
}

// The spec a Spree package is about to be installed at: the Spree version for
// a pin the upgrade moves (see pinnedOffRelease), its declared spec otherwise.
function installedSpec(line: ReleaseLine): (pkg: SpreePackage) => { name: string; spec: string } {
  return (pkg) => ({
    name: pkg.name,
    spec: pinnedOffRelease([pkg], pkg.dev, line).length > 0 ? line.version : pkg.spec,
  })
}

// The project root carries @spree/cli; each admin app carries the dashboard
// packages and the Admin SDK. The storefront is the merchant's own fork, so
// its SDK bump stays theirs (see sdkAdvisory).
async function updateSpreePackages(
  projectDir: string,
  flags: UpgradeFlags,
  line: ReleaseLine,
): Promise<void> {
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
    for (const { name, from, to } of moveToReleaseLine(target.dir, line)) {
      p.log.info(`${name}: ${from} → ${to} ${pc.dim(`in ${target.relative}`)}`)
    }
    const pm = detectPackageManager(projectDir, target.dir)
    // Read again, since the rewrite above can turn a pin into a range.
    const packages = detectSpreePackages(target.dir)

    const peers = alignPeerRanges(
      target.dir,
      await spreePeerRanges(target.dir, packages.map(installedSpec(line))),
    )
    for (const { name, from, to } of peers) {
      p.log.info(`${name}: ${from} → ${to} ${pc.dim(`in ${target.relative}, required by Spree`)}`)
    }

    // Spree packages and the peers they require go in one command, so npm
    // checks the new peers against the new ranges.
    const ranged = [
      ...packages.filter((pkg) => !isExactVersion(pkg.spec)).map((pkg) => pkg.name),
      ...peers.filter((peer) => !peer.exact).map((peer) => peer.name),
    ]
    if (ranged.length > 0) {
      await runPackageManager(pm, packageUpdateArgs(pm, ranged, projectDir, target.dir), target)
    }
    for (const dev of [false, true]) {
      const pinned = [
        ...pinnedOffRelease(packages, dev, line),
        ...peers
          .filter((peer) => peer.dev === dev && peer.exact)
          .map((peer) => `${peer.name}@${peer.to}`),
      ]
      if (pinned.length > 0) await runPackageManager(pm, packageAddArgs(pm, pinned, dev), target)
    }
    const dedupeArgs = packageDedupeArgs(pm, projectDir, target.dir)
    if (dedupeArgs) await runPackageManager(pm, dedupeArgs, target)

    // An updated dashboard can ship new routes; regenerate now so the next
    // dev start doesn't rewrite the file and reload the open page.
    if (target.relative !== '.') await generateRouteTree(target.dir)
  }
}

async function runPackageManager(
  pm: string,
  args: string[],
  target: { relative: string; dir: string },
): Promise<void> {
  p.log.step(`${pc.bold(`${pm} ${args.join(' ')}`)} ${pc.dim(`in ${target.relative}`)}`)
  await execa(pm, args, { cwd: target.dir, stdio: 'inherit' })
}

// We can detect the conventional create-spree-app storefront and tell the
// operator exactly what to bump.
export function sdkAdvisory(projectDir: string, line: ReleaseLine = RELEASE_LINE): string {
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
    if (line.packages.includes('@spree/sdk') && isOlderLine(declared, line)) {
      return `Update @spree/sdk in apps/storefront from ${declared} to ^${line.version}: from Spree 6.0 the SDK shares the Spree version`
    }
    return `Update @spree/sdk in apps/storefront (currently ${declared}) to the release matching the new Spree version`
  } catch {
    return generic
  }
}

function printPostUpgradeReminder(projectDir: string, line: ReleaseLine = RELEASE_LINE): void {
  p.note(
    [
      `The manifest only ran the ${pc.bold('automatable')} steps.`,
      '',
      "Don't forget the manual parts from the upgrade doc:",
      `  ${pc.dim('- Compare your scheduled jobs (config/recurring.yml) with the upgrade guide')}`,
      `  ${pc.dim(`- ${sdkAdvisory(projectDir, line)}`)}`,
      `  ${pc.dim('- Review the behavior changes listed in the upgrade guide')}`,
      `  ${pc.dim('- Audit custom decorators against renamed APIs')}`,
      '',
      `Full checklist: ${pc.cyan('https://spreecommerce.org/docs/developer/upgrades/quickstart')}`,
    ].join('\n'),
    'Next steps',
  )
}
