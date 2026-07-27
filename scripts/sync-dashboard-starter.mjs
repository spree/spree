#!/usr/bin/env node
// Render packages/dashboard-starter (the monorepo-canonical source, which
// doubles as the plugin pipeline's CI consumer test) into a standalone
// template, rewriting the bits that only make sense inside the monorepo:
//
//   - `workspace:^` dependency ranges → floating ranges on the published
//     packages (newest release through 1.x, floored at the version being
//     released)
//   - monorepo-only devDependencies dropped (the example plugin isn't on npm)
//   - biome.json extends the workspace root config → replaced with a
//     self-contained equivalent
//
// Everything else copies verbatim, including src/routeTree.gen.ts (committed
// by design — its diff on upgrade shows which admin pages changed).
//
// Runs at build time in @spree/cli and create-spree-app, targeting their
// `templates/dashboard-starter/` (gitignored; shipped inside the tarball via
// the dist copy). `prepublishOnly` rebuilds on publish, so the floor is
// always stamped from the versions being released — no template repo to keep
// in sync. (A public template repo can reuse this script as a second target
// later.)
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
fs.mkdirSync(targetDir, { recursive: true })

const EXCLUDE = new Set(['node_modules', 'dist', '.turbo', '.tanstack'])
const MONOREPO_ONLY_DEV_DEPS = new Set(['@spree/dashboard-plugin-example'])

// Bump deliberately (with an image-build test) — pnpm majors have changed
// install-policy behavior under existing lockfiles.
const TEMPLATE_PNPM_VERSION = '11.13.1'

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

// npm never packs `.gitignore` files (at any depth), so an embedded template
// would silently lose it and scaffolded apps would commit node_modules. Ship
// it as `gitignore.template`; the scaffolders rename it back after copying.
if (fs.existsSync(path.join(targetDir, '.gitignore'))) {
  fs.renameSync(path.join(targetDir, '.gitignore'), path.join(targetDir, 'gitignore.template'))
}

// --- package.json: pin published versions -----------------------------------

function publishedRange(name) {
  const dir = name.replace('@spree/', '')
  const manifestPath = path.join(repoRoot, 'packages', dir, 'package.json')
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'))
  if (manifest.private) {
    throw new Error(`${name} is private — it can't be a dependency of the synced template`)
  }
  // On 0.x, `^` never crosses a minor, so scaffolds stay frozen on whatever
  // minor the CLI happened to be published against — a dashboard release
  // without a CLI release in the same train would never reach users. Float
  // instead, floored at the version this template was built against, through
  // all of 0.x AND into 1.x so preview-era apps migrate to stable on their
  // own. After 1.0, `^` floats within the major on its own.
  const { version } = manifest
  return version.startsWith('0.') ? `>=${version} <2.0.0` : `^${version}`
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
// Pin the package manager so scaffolded apps (and the Docker image builds
// that run `corepack enable pnpm` against them) use a known pnpm instead of
// whatever is latest — pnpm 11 changed install-policy defaults under
// existing lockfiles, which broke image rebuilds. Injected here rather than
// in the monorepo source, where the workspace root's pin governs.
pkg.packageManager = `pnpm@${TEMPLATE_PNPM_VERSION}`
fs.writeFileSync(pkgPath, `${JSON.stringify(pkg, null, 2)}\n`)

// --- pnpm-workspace.yaml: install policy for scaffolded apps -----------------
// Standalone-only (the monorepo workspace root governs inside the repo).
// trustLockfile: pnpm 11 re-applies minimumReleaseAge (default 24h) to every
// lockfile entry, so an image rebuild whose committed lockfile references
// day-old packages fails; the committed lockfile is the trust anchor.
// The @spree/* exemption keeps Spree's own releases installable on day one.
fs.writeFileSync(
  path.join(targetDir, 'pnpm-workspace.yaml'),
  [
    'packages:',
    "  - '.'",
    '# Image rebuilds re-install the committed lockfile verbatim — without this,',
    "# pnpm 11's supply-chain re-validation (minimumReleaseAge) fails any build",
    '# whose lockfile references <24h-old packages you intentionally installed.',
    '# Fresh resolution on your machine still honors the age gate.',
    'trustLockfile: true',
    "# Spree's own releases shouldn't wait out the age gate — an upgrade right",
    '# after a Spree release would otherwise fail for a day.',
    'minimumReleaseAgeExclude:',
    "  - '@spree/*'",
    '',
  ].join('\n'),
)

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
