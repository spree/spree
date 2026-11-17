// Publishes the npm packages a release tag names, skipping any version already
// on npm, so a release that failed part-way can simply run again. The npm
// dist-tag follows the version: `0.x` → `next`, a prerelease → `beta`, else
// `latest`. Run by release.yml:
//
//   v6.0.0.rc7               the packages that share the Spree version, and
//                            @spree/docs, the docs for that version
//   @spree/cli@3.5.0         @spree/cli
//   create-spree-app@2.4.1   create-spree-app
//
//   node scripts/publish-packages.mjs verify <tag>     the tag matches the versions
//                                                      in the repository
//   node scripts/publish-packages.mjs preflight <tag>  npm accepts this workflow for
//                                                      every package it will publish
//   node scripts/publish-packages.mjs publish <tag>    build and publish what it names
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { alignedPackages, gemVersion, npmVersion } from './version-packages.mjs'

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

/**
 * @param {string} version
 * @returns {string}
 */
export function distTag(version) {
  if (version.startsWith('0.')) return 'next'
  return version.includes('-') ? 'beta' : 'latest'
}

export function manifest(dir) {
  return JSON.parse(fs.readFileSync(path.join(dir, 'package.json'), 'utf8'))
}

function runtimeDependencies(dir) {
  const { dependencies = {}, peerDependencies = {} } = manifest(dir)
  return Object.keys({ ...dependencies, ...peerDependencies })
}

export function workspacePackages() {
  const packagesDir = path.join(repoRoot, 'packages')
  return new Map(
    fs
      .readdirSync(packagesDir)
      .map((dir) => path.join(packagesDir, dir))
      .filter((dir) => fs.existsSync(path.join(dir, 'package.json')))
      .map((dir) => [manifest(dir).name, dir]),
  )
}

/**
 * Orders packages so each publishes after the ones it depends on: `pnpm
 * publish` rewrites `workspace:` ranges to the versions being released, and an
 * install of a package whose dependency is not on npm yet fails.
 *
 * @param {Array<{ name: string, dir: string }>} packages
 */
export function dependencyOrder(packages) {
  const names = new Set(packages.map(({ name }) => name))
  const dependsOn = new Map(
    packages.map(({ name, dir }) => [
      name,
      runtimeDependencies(dir).filter((dep) => names.has(dep)),
    ]),
  )
  const ordered = []
  const visit = (name, trail = []) => {
    if (ordered.some((pkg) => pkg.name === name)) return
    if (trail.includes(name)) throw new Error(`Dependency cycle: ${[...trail, name].join(' → ')}`)
    for (const dep of dependsOn.get(name)) visit(dep, [...trail, name])
    ordered.push(packages.find((pkg) => pkg.name === name))
  }
  for (const { name } of packages) visit(name)
  return ordered
}

export function isPublished(name, version) {
  try {
    return (
      execFileSync('npm', ['view', `${name}@${version}`, 'version'], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      }).trim() !== ''
    )
  } catch {
    return false
  }
}

function publish(packages) {
  // One failure (say, a package whose build broke or whose npm Trusted
  // Publishing lapsed) must not hold back the unrelated packages after it. Its
  // dependents are still held back: they would point at a version npm does not
  // have. Each package builds on its own so a broken build fails only itself.
  const failed = []
  for (const { name, dir } of dependencyOrder(packages)) {
    const { version } = manifest(dir)
    if (isPublished(name, version)) {
      console.log(`${name}@${version} is already on npm, skipping.`)
      continue
    }
    const failedDependency = runtimeDependencies(dir).find((dep) => failed.includes(dep))
    if (failedDependency) {
      console.error(`Not publishing ${name}@${version}: ${failedDependency} failed to publish.`)
      failed.push(name)
      continue
    }
    const tag = distTag(version)
    console.log(`Publishing ${name}@${version} under ${tag}.`)
    try {
      execFileSync('pnpm', ['turbo', 'build', '--filter', name], {
        cwd: repoRoot,
        stdio: 'inherit',
      })
      // `pnpm publish`, not `npm publish`: it rewrites `workspace:` ranges, which
      // npm would ship verbatim, and runs each package's prepublishOnly build.
      execFileSync(
        'pnpm',
        ['publish', '--provenance', '--access', 'public', '--tag', tag, '--no-git-checks'],
        { cwd: dir, stdio: 'inherit' },
      )
    } catch {
      console.error(`Failed to build or publish ${name}@${version}.`)
      failed.push(name)
    }
  }
  if (failed.length > 0) {
    throw new Error(`Not published: ${failed.join(', ')}. Fix the cause and re-run the failed job.`)
  }
}

/**
 * Checks that npm Trusted Publishing accepts this workflow run for every
 * package the tag would publish, before anything is published. It makes the
 * same OIDC token exchange `npm publish` makes and throws the short-lived token
 * away; the exchange alone publishes nothing. A package whose trusted publisher
 * lapsed then stops the release before the gems or any other package ship.
 *
 * @param {Array<{ name: string, dir: string }>} packages
 */
async function preflight(packages) {
  const pending = packages.filter(({ name, dir }) => !isPublished(name, manifest(dir).version))
  if (pending.length === 0) return console.log('Every package is already on npm.')

  const { ACTIONS_ID_TOKEN_REQUEST_URL: requestUrl, ACTIONS_ID_TOKEN_REQUEST_TOKEN: requestToken } =
    process.env
  if (!requestUrl || !requestToken) {
    throw new Error('No GitHub OIDC token available: the job needs `id-token: write`.')
  }

  const rejected = []
  for (const { name } of pending) {
    // A fresh ID token per package, as `npm publish` fetches one per package.
    const url = new URL(requestUrl)
    url.searchParams.append('audience', 'npm:registry.npmjs.org')
    const idToken = await fetch(url, { headers: { Authorization: `Bearer ${requestToken}` } })
    if (!idToken.ok) throw new Error(`GitHub refused an OIDC token: HTTP ${idToken.status}`)
    const { value } = await idToken.json()

    const exchange = await fetch(
      `https://registry.npmjs.org/-/npm/v1/oidc/token/exchange/package/${name.replaceAll('/', '%2f')}`,
      { method: 'POST', headers: { Authorization: `Bearer ${value}` } },
    )
    if (exchange.ok) {
      console.log(`npm accepts this workflow for ${name}.`)
    } else {
      // npm sets up Trusted Publishing only for a package that exists, so a new
      // package's first version is published by hand.
      const { message } = await exchange.json().catch(() => ({}))
      console.error(
        `npm rejects this workflow for ${name}: HTTP ${exchange.status} ${message ?? ''}`,
      )
      rejected.push(name)
    }
  }
  if (rejected.length > 0) {
    throw new Error(
      `npm Trusted Publishing rejects ${rejected.join(', ')}. Check each package's trusted publisher ` +
        '(organization spree, repository spree, workflow release.yml, environment release) on npmjs.com, ' +
        'then re-run the failed jobs.',
    )
  }
}

// Carries the Spree version outside the Changesets group (it has no
// changelog), so a project's local docs match its server. Released with Spree.
const DOCS = '@spree/docs'

// Released on their own tags, independently of Spree.
export const TOOLS = ['@spree/cli', 'create-spree-app']

/**
 * The packages a release tag names, after checking that the versions in the
 * repository are the ones the tag announces. Throws when they are not.
 *
 * @param {string} gitTag
 * @returns {Array<{ name: string, dir: string }>}
 */
export function packagesForTag(gitTag) {
  if (gitTag?.startsWith('v')) {
    const spreeVersion = gemVersion()
    const expected = npmVersion(spreeVersion)
    const problems = []
    if (gitTag !== `v${spreeVersion}`) {
      problems.push(
        `the tag does not match Spree::VERSION ${spreeVersion} (expected v${spreeVersion})`,
      )
    }
    const packages = [...alignedPackages(), { name: DOCS, dir: workspacePackages().get(DOCS) }]
    for (const { name, dir } of packages) {
      const { version } = manifest(dir)
      if (version !== expected) problems.push(`${name} is at ${version}, expected ${expected}`)
    }
    if (problems.length > 0) {
      throw new Error(
        `Not releasing ${gitTag}:\n- ${problems.join('\n- ')}\nRun \`pnpm version:packages\` after bumping Spree::VERSION.`,
      )
    }
    return packages
  }

  const at = gitTag?.lastIndexOf('@') ?? -1
  const name = at > 0 ? gitTag.slice(0, at) : ''
  if (!TOOLS.includes(name)) {
    throw new Error(
      `Not releasing ${gitTag}: expected v<Spree version> or <package>@<version> for ${TOOLS.join(' or ')}`,
    )
  }
  const dir = workspacePackages().get(name)
  const { version } = manifest(dir)
  if (gitTag.slice(at + 1) !== version) {
    throw new Error(`Not releasing ${gitTag}: ${name} is at ${version} in the repository`)
  }
  return [{ name, dir }]
}

function main([command, gitTag]) {
  if (command === 'verify') {
    const packages = packagesForTag(gitTag)
    return console.log(`${gitTag} releases ${packages.map(({ name }) => name).join(', ')}.`)
  }
  if (command === 'preflight') return preflight(packagesForTag(gitTag))
  if (command === 'publish') return publish(packagesForTag(gitTag))
  throw new Error('Usage: publish-packages.mjs verify|preflight|publish <tag>')
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main(process.argv.slice(2))
