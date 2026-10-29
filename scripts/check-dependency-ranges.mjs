#!/usr/bin/env node
// Keeps every workspace package on one version of each third-party dependency
// (see `catalog:` in pnpm-workspace.yaml). Fails when:
//
//   - a dependency two or more packages use is declared without `catalog:`
//     in dependencies or devDependencies, so a bump would move one copy only
//   - a peer dependency has no matching dependency or devDependency, so the
//     workspace installs it from the peer range instead of the catalog
//
// Peer ranges themselves may stay wide (the SDKs accept `typescript >=4.7.0`).
//
// Usage: node scripts/check-dependency-ranges.mjs
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
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
const users = new Map()
for (const manifest of manifests) {
  for (const section of ['dependencies', 'devDependencies', 'peerDependencies']) {
    for (const [name, spec] of Object.entries(manifest[section] ?? {})) {
      if (isWorkspace(spec)) continue
      users.set(name, (users.get(name) ?? new Set()).add(manifest.file))
    }
  }
}

const problems = []
for (const manifest of manifests) {
  for (const section of ['dependencies', 'devDependencies']) {
    for (const [name, spec] of Object.entries(manifest[section] ?? {})) {
      if (isWorkspace(spec) || spec === 'catalog:' || users.get(name).size < 2) continue
      problems.push(`${manifest.file}: ${section}.${name} is "${spec}" — use "catalog:"`)
    }
  }
  for (const name of Object.keys(manifest.peerDependencies ?? {})) {
    if (manifest.dependencies?.[name] || manifest.devDependencies?.[name]) continue
    problems.push(
      `${manifest.file}: peer ${name} needs a matching devDependency ("catalog:" or "workspace:")`,
    )
  }
}

if (problems.length > 0) {
  console.error(
    `Dependency ranges drift from the catalog in pnpm-workspace.yaml:\n\n  ${problems.join('\n  ')}\n`,
  )
  process.exit(1)
}
console.log(`Dependency ranges: ${manifests.length} manifests share one catalog.`)
