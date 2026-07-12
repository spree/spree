#!/usr/bin/env node
// Sync packages/dashboard-starter (the monorepo-canonical source) into a
// working clone of the spree/dashboard-starter template repo, rewriting the
// bits that only make sense inside the monorepo:
//
//   - `workspace:^` dependency ranges → `^<version>` of the published packages
//   - monorepo-only devDependencies dropped (the example plugin isn't on npm)
//   - biome.json extends the workspace root config → replaced with a
//     self-contained equivalent
//
// Everything else copies verbatim, including src/routeTree.gen.ts (committed
// by design — its diff on upgrade shows which admin pages changed).
//
// Usage: node scripts/sync-dashboard-starter.mjs <target-dir>
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const starterDir = path.join(repoRoot, 'packages', 'dashboard-starter')

const target = process.argv[2]
if (!target) {
  console.error('Usage: node scripts/sync-dashboard-starter.mjs <target-dir>')
  process.exit(2)
}
const targetDir = path.resolve(target)
if (!fs.existsSync(targetDir)) {
  console.error(`Target directory does not exist: ${targetDir}`)
  process.exit(2)
}

const EXCLUDE = new Set(['node_modules', 'dist', '.turbo', '.tanstack'])
const MONOREPO_ONLY_DEV_DEPS = new Set(['@spree/dashboard-plugin-example'])

// Clear the target working tree (keep .git) so deletions in the monorepo
// propagate instead of accumulating stale files.
for (const entry of fs.readdirSync(targetDir)) {
  if (entry === '.git') continue
  fs.rmSync(path.join(targetDir, entry), { recursive: true, force: true })
}

fs.cpSync(starterDir, targetDir, {
  recursive: true,
  filter: (src) => !EXCLUDE.has(path.basename(src)),
})

// --- package.json: pin published versions -----------------------------------

function publishedRange(name) {
  const dir = name.replace('@spree/', '')
  const manifestPath = path.join(repoRoot, 'packages', dir, 'package.json')
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'))
  if (manifest.private) {
    throw new Error(`${name} is private — it can't be a dependency of the synced template`)
  }
  return `^${manifest.version}`
}

const pkgPath = path.join(targetDir, 'package.json')
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'))
for (const section of ['dependencies', 'devDependencies']) {
  const deps = pkg[section]
  if (!deps) continue
  for (const [name, range] of Object.entries(deps)) {
    if (MONOREPO_ONLY_DEV_DEPS.has(name)) {
      delete deps[name]
    } else if (typeof range === 'string' && range.startsWith('workspace:')) {
      deps[name] = publishedRange(name)
    }
  }
}
fs.writeFileSync(pkgPath, `${JSON.stringify(pkg, null, 2)}\n`)

// --- biome.json: inline the workspace root config ----------------------------

const rootBiome = JSON.parse(fs.readFileSync(path.join(repoRoot, 'biome.json'), 'utf8'))
const starterBiome = JSON.parse(fs.readFileSync(path.join(starterDir, 'biome.json'), 'utf8'))
const standaloneBiome = {
  $schema: rootBiome.$schema,
  vcs: rootBiome.vcs,
  linter: rootBiome.linter,
  formatter: rootBiome.formatter,
  javascript: rootBiome.javascript,
  css: rootBiome.css,
  assist: rootBiome.assist,
  // The starter's own file list (routeTree.gen.ts stays excluded); the
  // monorepo root's list is irrelevant outside the workspace.
  files: starterBiome.files,
}
fs.writeFileSync(
  path.join(targetDir, 'biome.json'),
  `${JSON.stringify(standaloneBiome, null, 2)}\n`,
)

console.log(`Synced ${starterDir} → ${targetDir}`)
