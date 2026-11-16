// Prepares the storefront pull request for a Spree release: a fresh clone in
// tmp/storefront, `@spree/sdk` moved to the release, the storefront's type
// check, lint and unit tests, then a commit. The caller pushes it and opens the
// pull request.
//
//   node scripts/release/bump-storefront.mjs [<npm version>]   defaults to Spree::VERSION
//   node scripts/release/bump-storefront.mjs --local
//
// `--local` is the release audit's check: it builds the SDK in this worktree
// and type-checks the storefront against it, committing nothing. A Store API
// change that breaks the storefront's types then shows up before anything is
// published.
import fs from 'node:fs'
import path from 'node:path'
import { gemVersion, npmVersion } from '../version-packages.mjs'
import { assertChangedOnly, dashed, freshClone, read, repoRoot, retry, run } from './lib.mjs'

const local = process.argv.includes('--local')
const version = local ? 'local' : (process.argv[2] ?? npmVersion(gemVersion()))
const dir = freshClone('spree/storefront', `chore/sdk-${dashed(version)}`)
const lockfile = () => fs.readFileSync(path.join(dir, 'pnpm-lock.yaml'), 'utf8')

if (local) {
  run('pnpm', ['turbo', 'build', '--filter', '@spree/sdk'])
  const packDir = path.join(repoRoot, 'tmp')
  const tarball = read('pnpm', ['pack', '--pack-destination', packDir], {
    cwd: path.join(repoRoot, 'packages/sdk'),
  })
    .trim()
    .split('\n')
    .pop()
  const tarballPath = path.resolve(packDir, tarball)
  let typeChecks = true
  try {
    run('pnpm', ['add', `@spree/sdk@file:${tarballPath}`], { cwd: dir })
    run('pnpm', ['exec', 'tsc', '--noEmit'], { cwd: dir })
  } catch {
    typeChecks = false
  } finally {
    fs.rmSync(tarballPath, { force: true })
  }
  if (!typeChecks) {
    console.error(
      '\nThe storefront does not type-check against this worktree’s @spree/sdk. ' +
        'Fix the storefront in a pull request before the release, so its SDK bump needs no changes.',
    )
    process.exit(1)
  }
  console.log('\nThe storefront type-checks against this worktree’s @spree/sdk.')
  process.exit(0)
}

// npm's metadata replicates to mirrors over several minutes. The exact version
// is installed, so neither a stale mirror nor a newer minor release can satisfy
// it; the caret range then goes in package.json and keeps that resolution.
retry(`@spree/sdk@${version} on npm`, () => {
  run('pnpm', ['add', `@spree/sdk@${version}`], { cwd: dir })
  return lockfile().includes(`'@spree/sdk@${version}'`)
})
const manifestPath = path.join(dir, 'package.json')
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'))
manifest.dependencies['@spree/sdk'] = `^${version}`
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`)
run('pnpm', ['install'], { cwd: dir })
assertChangedOnly(dir, ['package.json', 'pnpm-lock.yaml'])

// A type error means the Store API changed shape in this release: the caller
// fixes the storefront in this same pull request, never the release.
run('pnpm', ['exec', 'tsc', '--noEmit'], { cwd: dir })
run('pnpm', ['run', 'check'], { cwd: dir })
run('pnpm', ['run', 'test'], { cwd: dir })

run('git', ['add', '-A'], { cwd: dir })
run(
  'git',
  [
    'commit',
    '--quiet',
    '-m',
    `Updated @spree/sdk to ^${version}`,
    '-m',
    `Moves the storefront to @spree/sdk ${version} so it builds against this release's Store API.`,
  ],
  { cwd: dir },
)
console.log(`\nCommitted in ${path.relative(repoRoot, dir)}.`)
