#!/usr/bin/env node
// Keeps every workspace package on one version of each third-party dependency
// (see `catalog:` in pnpm-workspace.yaml). Fails when:
//
//   - a dependency two or more packages install is declared in dependencies
//     or devDependencies as anything but `catalog:` or the catalog's exact
//     version (@spree/dashboard-ui pins its runtime dependencies)
//   - a peer dependency has no matching dependency or devDependency, so the
//     workspace would install it from the peer range instead of the catalog
//   - the version the workspace installs falls outside the package's own peer
//     range, so the published contract no longer covers what this repository
//     tests
//
// Peer ranges themselves are hand-written floors (see pnpm-workspace.yaml).
//
// Usage: node scripts/check-dependency-ranges.mjs
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import semver from 'semver'
import { parse as parseYaml } from 'yaml'

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
// Released with `npm publish`, which ships `catalog:` verbatim.
const NPM_PUBLISHED = new Set(['packages/docs/package.json'])
// Ships source, so it pins runtime dependencies to the catalog's exact version.
const EXACT_PINS = 'packages/dashboard-ui/package.json'

const { catalog = {} } = parseYaml(
  fs.readFileSync(path.join(repoRoot, 'pnpm-workspace.yaml'), 'utf8'),
)
const manifestPaths = [
  'package.json',
  ...fs
    .readdirSync(path.join(repoRoot, 'packages'))
    .map((dir) => path.join('packages', dir, 'package.json'))
    .filter((file) => fs.existsSync(path.join(repoRoot, file))),
]
const manifests = manifestPaths.map((file) => ({
  file,
  ...JSON.parse(fs.readFileSync(path.join(repoRoot, file), 'utf8')),
}))

const isWorkspace = (spec) => spec.startsWith('workspace:')
const installers = new Map()
for (const manifest of manifests) {
  if (NPM_PUBLISHED.has(manifest.file)) continue
  for (const section of ['dependencies', 'devDependencies']) {
    for (const [name, spec] of Object.entries(manifest[section] ?? {})) {
      if (isWorkspace(spec)) continue
      installers.set(name, (installers.get(name) ?? new Set()).add(manifest.file))
    }
  }
}

function pinsCatalogVersion(name, spec) {
  return catalog[name] && semver.valid(spec) && spec === semver.minVersion(catalog[name]).version
}

const problems = []
for (const manifest of manifests) {
  for (const section of ['dependencies', 'devDependencies']) {
    for (const [name, spec] of Object.entries(manifest[section] ?? {})) {
      if (isWorkspace(spec) || spec === 'catalog:' || NPM_PUBLISHED.has(manifest.file)) continue
      if (installers.get(name).size < 2) continue
      if (
        manifest.file === EXACT_PINS &&
        section === 'dependencies' &&
        pinsCatalogVersion(name, spec)
      )
        continue
      problems.push(`${manifest.file}: ${section}.${name} is "${spec}" — use "catalog:"`)
    }
  }
  for (const [name, range] of Object.entries(manifest.peerDependencies ?? {})) {
    const spec = manifest.dependencies?.[name] ?? manifest.devDependencies?.[name]
    if (!spec) {
      problems.push(
        `${manifest.file}: peer ${name} needs a matching devDependency ("catalog:" or "workspace:")`,
      )
      continue
    }
    if (isWorkspace(spec) || isWorkspace(range)) continue
    const installed = semver.minVersion(spec === 'catalog:' ? catalog[name] : spec)
    if (!semver.satisfies(installed, range)) {
      problems.push(
        `${manifest.file}: peer ${name} "${range}" excludes ${installed}, the version this workspace tests`,
      )
    }
  }
}

if (problems.length > 0) {
  console.error(
    `Dependency ranges drift from the catalog in pnpm-workspace.yaml:\n\n  ${problems.join('\n  ')}\n`,
  )
  process.exit(1)
}
console.log(`Dependency ranges: ${manifests.length} manifests share one catalog.`)
