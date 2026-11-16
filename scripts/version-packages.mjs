// Versions the npm packages from the pending changesets, then moves every
// package in the Changesets `fixed` group onto the version of the Spree gems
// (`spree/core/lib/spree/core/version.rb`, in npm's spelling). Changesets still
// writes the changelogs, but the bump type a changeset names no longer decides
// the version of those packages: `@spree/sdk@6.0.2` is the SDK for Spree 6.0.2.
// Packages outside the group (`@spree/cli`, `create-spree-app`) keep the
// version Changesets gives them. `@spree/docs` also takes the Spree version, so
// a project's local docs match its server; release.yml publishes it with the
// rest of the release on the `v<version>` tag.
//
// Bump `Spree::VERSION` first, then run `pnpm version:packages`.
//
// `pnpm version:tools` (`--tools`) versions only the packages outside the
// group, for a CLI or create-spree-app release between Spree releases; the
// group's pending changesets wait for the next Spree release.
//
// `pnpm changeset:check` (`--check`) fails on a changeset that names more than
// one package; CI runs it, and both versioning commands run it first.
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import YAML from 'yaml'

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

/**
 * The npm spelling of a RubyGems version: `6.0.0.rc7` → `6.0.0-rc.7`. npm needs
 * the hyphen, and the dot keeps `rc.10` sorting above `rc.9`.
 *
 * @param {string} gemVersion
 * @returns {string}
 */
export function npmVersion(gemVersion) {
  const match = gemVersion.match(/^(\d+\.\d+\.\d+)(?:\.([a-z]+)(\d*))?$/)
  if (!match) throw new Error(`Cannot convert Spree version ${gemVersion} to an npm version`)
  const [, release, label, number] = match
  if (!label) return release
  return number ? `${release}-${label}.${number}` : `${release}-${label}`
}

/**
 * The range a package in the group accepts for another one it names with a
 * literal range: this release and anything after it in the same major. The
 * floor is the full version because semver only lets a prerelease such as
 * `6.0.1-rc.1` satisfy a range with a comparator on that same `6.0.1`.
 *
 * @param {string} version
 * @returns {string}
 */
export function peerRange(version) {
  const major = Number(version.split('.')[0])
  return `>=${version} <${major + 1}.0.0-0`
}

/**
 * A range over a package's whole major, release candidates included:
 * `^6.0.0-0` accepts `6.0.0-rc.7`, `6.0.0` and every later 6.x, and installs
 * the newest. Used where a range must never point at a version that may not be
 * on npm yet.
 *
 * @param {string} version
 * @returns {string}
 */
export function majorFloorRange(version) {
  return `^${version.split('.')[0]}.0.0-0`
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'))
}

export function gemVersion() {
  const source = fs.readFileSync(
    path.join(repoRoot, 'spree/core/lib/spree/core/version.rb'),
    'utf8',
  )
  const match = source.match(/VERSION = '([^']+)'/)
  if (!match) throw new Error('Spree::VERSION not found in spree/core/lib/spree/core/version.rb')
  return match[1]
}

function hasPendingChangesets() {
  return fs
    .readdirSync(path.join(repoRoot, '.changeset'))
    .some((file) => file.endsWith('.md') && file !== 'README.md')
}

export function alignedPackages() {
  const { fixed } = readJson(path.join(repoRoot, '.changeset/config.json'))
  const group = fixed.find((names) => names.includes('@spree/sdk'))
  if (!group) throw new Error('No Changesets fixed group contains @spree/sdk')

  const packagesDir = path.join(repoRoot, 'packages')
  const byName = new Map(
    fs
      .readdirSync(packagesDir)
      .map((dir) => path.join(packagesDir, dir))
      .filter((dir) => fs.existsSync(path.join(dir, 'package.json')))
      .map((dir) => [readJson(path.join(dir, 'package.json')).name, dir]),
  )
  return group.map((name) => {
    const dir = byName.get(name)
    if (!dir) throw new Error(`${name} is in the fixed group but not in packages/`)
    return { name, dir }
  })
}

// Edits the text rather than re-serializing, so the file keeps its formatting.
function setVersion(manifestPath, from, to) {
  const source = fs.readFileSync(manifestPath, 'utf8')
  fs.writeFileSync(manifestPath, source.replace(`"version": "${from}"`, `"version": "${to}"`))
}

function setPeerRanges(manifestPath, names, range) {
  const manifest = readJson(manifestPath)
  let source = fs.readFileSync(manifestPath, 'utf8')
  for (const group of ['dependencies', 'peerDependencies']) {
    for (const [name, spec] of Object.entries(manifest[group] ?? {})) {
      if (!names.includes(name) || spec.startsWith('workspace:') || spec === range) continue
      source = source.replace(`"${name}": "${spec}"`, `"${name}": "${range}"`)
    }
  }
  fs.writeFileSync(manifestPath, source)
}

function updateChangelog(changelogPath, { computed, target, changed, spreeVersion, groupNames }) {
  if (!fs.existsSync(changelogPath)) return
  const source = fs.readFileSync(changelogPath, 'utf8')
  const updated = changed
    ? source.replace(`## ${computed}\n`, `## ${target}\n`)
    : source.replace(/^(# .+\n)/, `$1\n## ${target}\n\n${noOwnChanges(spreeVersion)}\n`)
  fs.writeFileSync(changelogPath, ownChangesOnly(updated, target, spreeVersion, groupNames))
}

const noOwnChanges = (spreeVersion) =>
  `Released with Spree ${spreeVersion}, with no changes of its own.`

/**
 * The changelog with `target`'s section reduced to the package's own changes.
 * The group always releases together, so Changesets' "Updated dependencies"
 * entries for other group packages say nothing, and a package left with no
 * entries gets the "Released with Spree" line instead.
 *
 * @param {string} source
 * @param {string} target
 * @param {string} spreeVersion
 * @param {string[]} groupNames
 * @returns {string}
 */
export function ownChangesOnly(source, target, spreeVersion, groupNames) {
  const start = source.indexOf(`## ${target}\n`)
  if (start === -1) return source
  const bodyStart = start + `## ${target}\n`.length
  const next = source.indexOf('\n## ', bodyStart)
  const end = next === -1 ? source.length : next + 1
  let body = source
    .slice(bodyStart, end)
    .replace(/^- Updated dependencies.*\n((?: {2}- .*\n)+)/gm, (entry, deps) =>
      deps
        .trim()
        .split('\n')
        .every((line) => groupNames.some((name) => line.includes(`- ${name}@`)))
        ? ''
        : entry,
    )
    .replace(/^### .+\n\n(?=### |$)/gm, '')
    .replace(/\n{3,}/g, '\n\n')
  if (!/^- /m.test(body)) body = `\n${noOwnChanges(spreeVersion)}\n\n`
  return source.slice(0, bodyStart) + body + source.slice(end)
}

/**
 * The pending changesets that name more than one package. Changesets copies a
 * changeset's text word for word into every package it names, so a change to
 * several packages takes one changeset per package, each describing that
 * package's part of it.
 *
 * @returns {string[]}
 */
export function sharedChangesets() {
  const dir = path.join(repoRoot, '.changeset')
  return fs
    .readdirSync(dir)
    .filter((file) => file.endsWith('.md') && file !== 'README.md')
    .flatMap((file) => {
      const frontMatter = fs
        .readFileSync(path.join(dir, file), 'utf8')
        .match(/^---\r?\n([\s\S]*?)\r?\n?---/)
      const names = Object.keys(YAML.parse(frontMatter?.[1] ?? '') ?? {})
      return names.length > 1 ? [`.changeset/${file} names ${names.join(', ')}`] : []
    })
}

function checkChangesets() {
  const shared = sharedChangesets()
  if (shared.length === 0) return
  throw new Error(
    `Each changeset must name one package, so its text describes that package:\n- ${shared.join('\n- ')}\n` +
      'Split each into one changeset per package, saying what changed in that package.',
  )
}

function versionTools() {
  const ignores = alignedPackages().flatMap(({ name }) => ['--ignore', name])
  execFileSync('pnpm', ['exec', 'changeset', 'version', ...ignores], {
    cwd: repoRoot,
    stdio: 'inherit',
  })
}

function main() {
  if (process.argv.includes('--check')) return checkChangesets()
  checkChangesets()
  if (process.argv.includes('--tools')) return versionTools()

  const spreeVersion = gemVersion()
  const target = npmVersion(spreeVersion)
  const packages = alignedPackages()
  const names = packages.map(({ name }) => name)
  const before = new Map(
    packages.map(({ name, dir }) => [name, readJson(path.join(dir, 'package.json')).version]),
  )

  // `changeset version` fails when nothing is pending, but a Spree release
  // without TypeScript changes still moves the group to the new version.
  if (hasPendingChangesets()) {
    execFileSync('pnpm', ['exec', 'changeset', 'version'], { cwd: repoRoot, stdio: 'inherit' })
  }

  const plans = packages.map(({ name, dir }) => {
    const manifestPath = path.join(dir, 'package.json')
    const computed = readJson(manifestPath).version
    return { name, dir, manifestPath, computed, changed: computed !== before.get(name) }
  })
  const stale = plans.filter(({ name, changed }) => changed && before.get(name) === target)
  if (stale.length > 0) {
    throw new Error(
      `${stale.map(({ name }) => name).join(', ')} already at ${target} but with pending changes. ` +
        'Bump Spree::VERSION, then discard the changes `changeset version` made and run this again.',
    )
  }

  for (const { name, dir, manifestPath, computed, changed } of plans) {
    if (before.get(name) !== target) {
      updateChangelog(path.join(dir, 'CHANGELOG.md'), {
        computed,
        target,
        changed,
        spreeVersion,
        groupNames: names,
      })
      setVersion(manifestPath, computed, target)
      console.log(`${name}: ${before.get(name)} → ${target}`)
    }
    setPeerRanges(manifestPath, names, peerRange(target))
  }

  const docsManifest = path.join(repoRoot, 'packages/docs/package.json')
  const docsVersion = readJson(docsManifest).version
  if (docsVersion !== target) {
    setVersion(docsManifest, docsVersion, target)
    console.log(`@spree/docs: ${docsVersion} → ${target}`)
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main()
