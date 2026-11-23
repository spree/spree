// Prepares the spree-starter pull request for a Spree release: a fresh clone
// in tmp/spree-starter, the released gems in its lockfile, the gem migrations
// it lacks and a regenerated db/schema.rb, then a commit. The caller pushes it
// and opens the pull request. Run from a worktree, whose Postgres the scratch
// databases use:
//
//   node scripts/release/bump-starter.mjs [<version>]   defaults to Spree::VERSION
import fs from 'node:fs'
import path from 'node:path'
import { gemVersion } from '../version-packages.mjs'
import { assertChangedOnly, dashed, freshClone, read, repoRoot, retry, run } from './lib.mjs'

const version = process.argv[2] ?? gemVersion()
const dir = freshClone('spree/spree-starter', `chore/spree-${dashed(version)}`)
const lockfile = () => fs.readFileSync(path.join(dir, 'Gemfile.lock'), 'utf8')
const locked = (gem) => lockfile().match(new RegExp(`^ {4}${gem} \\(([^)]+)\\)`, 'm'))?.[1]

// The gems this repository releases that the starter installs. `spree_dev_tools`
// has its own version, and a provider gem the starter does not install is left
// out rather than added.
const subdirectories = (dir) =>
  fs
    .readdirSync(path.join(repoRoot, dir), { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => `${dir}/${entry.name}`)
const gems = ['spree', ...subdirectories('spree'), ...subdirectories('spree/providers')]
  .flatMap((dir) =>
    fs.readdirSync(path.join(repoRoot, dir)).filter((file) => file.endsWith('.gemspec')),
  )
  .map((file) => file.replace(/\.gemspec$/, ''))
  .filter((gem) => locked(gem))

// Each gem's versions in the lockfile, without the platform suffix a native
// gem repeats once per platform (`ffi (1.17.4-arm64-darwin)`).
const lockedVersions = () => {
  const versions = new Map()
  for (const [, gem, spec] of lockfile().matchAll(/^ {4}([a-z0-9_-]+) \(([^)]+)\)/gm)) {
    versions.set(gem, (versions.get(gem) ?? new Set()).add(spec.split('-')[0]))
  }
  return new Map([...versions].map(([gem, specs]) => [gem, [...specs].join(', ')]))
}
const before = lockedVersions()

// Bundler's compact index can trail the RubyGems API by several minutes.
retry(`Spree ${version} on Bundler's index`, () => {
  run('bundle', ['update', ...gems], { cwd: dir })
  return gems.every((gem) => locked(gem) === version)
})

// The starter's CI fails on any advisory, including one for a gem this release
// did not move, so clear them here with the smallest update that fixes each.
const audit = () => {
  try {
    read('bundle', ['exec', 'bundle-audit', 'check', '--update'], { cwd: dir })
    return []
  } catch (error) {
    const names = [...String(error.stdout).matchAll(/^Name: (\S+)/gm)].map((m) => m[1])
    // A failure that names no gem (bundle-audit missing, no advisory database)
    // is not a clean audit.
    if (names.length === 0) throw error
    return [...new Set(names)]
  }
}
const vulnerable = audit()
if (vulnerable.length > 0) {
  run('bundle', ['update', '--conservative', ...vulnerable], { cwd: dir })
  const remaining = audit()
  if (remaining.length > 0) throw new Error(`bundle audit still fails for ${remaining.join(', ')}`)
}

// Both names are set, and unique to this run, so neither the development nor
// the test database is one that other worktrees, sessions or releases on this
// machine may be using. An inherited DATABASE_URL would win over both names.
const databases = {
  DATABASE_URL: undefined,
  DATABASE_NAME: `spree_starter_release_${process.pid}`,
  DATABASE_NAME_TEST: `spree_starter_release_${process.pid}_test`,
}
const migrationsBefore = new Set(fs.readdirSync(path.join(dir, 'db/migrate')))
try {
  run('bin/rails', ['db:create', 'spree:install:migrations', 'db:migrate'], {
    cwd: dir,
    env: databases,
  })
} catch (error) {
  // Keep the migrate error: a failing drop here would hide it.
  try {
    run('bin/rails', ['db:drop'], { cwd: dir, env: databases })
  } catch {}
  throw error
}
run('bin/rails', ['db:drop'], { cwd: dir, env: databases })
const migrations = fs
  .readdirSync(path.join(dir, 'db/migrate'))
  .filter((file) => !migrationsBefore.has(file))

assertChangedOnly(dir, ['Gemfile.lock', 'db/migrate/', 'db/schema.rb'])

const moved = [...lockedVersions()]
  .filter(([gem, now]) => !gems.includes(gem) && before.get(gem) !== now)
  .map(([gem, now]) => `${gem} ${before.get(gem) ?? '(new)'} → ${now}`)

if (read('git', ['status', '--porcelain'], { cwd: dir }).trim() === '') {
  console.log(`\nspree-starter is already on Spree ${version}; nothing to commit.`)
  process.exit(0)
}

const body = [
  `Moves the Spree gems to ${version}.`,
  moved.length > 0 ? `Other gems: ${moved.join(', ')}.` : 'No other gems moved.',
  vulnerable.length > 0 ? `Updated for bundle audit advisories: ${vulnerable.join(', ')}.` : '',
  migrations.length > 0
    ? `Copied migrations: ${migrations.join(', ')}.`
    : `Spree ${version} adds no migrations, so db/migrate and db/schema.rb are unchanged.`,
]
  .filter(Boolean)
  .join(' ')
run('git', ['add', '-A'], { cwd: dir })
run('git', ['commit', '--quiet', '-m', `Bump Spree to ${version}`, '-m', body], { cwd: dir })

console.log(`\nCommitted in ${path.relative(repoRoot, dir)}:\n${body}`)
console.log('\nNew migrations (describe each in the pull request):')
for (const migration of migrations) console.log(`  ${migration}`)
if (migrations.length === 0) console.log('  none')
