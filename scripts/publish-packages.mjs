// Publishes the npm packages a release tag names, skipping any version already
// on npm, so a release that failed part-way can simply run again. The npm
// dist-tag follows the version: `0.x` → `next`, a prerelease → `beta`, else
// `latest`. Run by release.yml:
//
//   v6.0.0.rc7               the packages that share the Spree version
//   @spree/cli@3.5.0         @spree/cli
//   create-spree-app@2.4.1   create-spree-app
//
//   node scripts/publish-packages.mjs verify <tag>    the tag matches the versions
//                                                     in the repository
//   node scripts/publish-packages.mjs publish <tag>   build and publish what it names
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

function manifest(dir) {
  return JSON.parse(fs.readFileSync(path.join(dir, 'package.json'), 'utf8'))
}

function workspacePackages() {
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
    packages.map(({ name, dir }) => {
      const { dependencies = {}, peerDependencies = {} } = manifest(dir)
      return [
        name,
        Object.keys({ ...dependencies, ...peerDependencies }).filter((dep) => names.has(dep)),
      ]
    }),
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

function isPublished(name, version) {
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
  const filters = packages.flatMap(({ name }) => ['--filter', name])
  execFileSync('pnpm', ['turbo', 'build', ...filters], { cwd: repoRoot, stdio: 'inherit' })

  for (const { name, dir } of dependencyOrder(packages)) {
    const { version } = manifest(dir)
    if (isPublished(name, version)) {
      console.log(`${name}@${version} is already on npm, skipping.`)
      continue
    }
    const tag = distTag(version)
    console.log(`Publishing ${name}@${version} under ${tag}.`)
    // `pnpm publish`, not `npm publish`: it rewrites `workspace:` ranges, which
    // npm would ship verbatim, and runs each package's prepublishOnly build.
    execFileSync(
      'pnpm',
      ['publish', '--provenance', '--access', 'public', '--tag', tag, '--no-git-checks'],
      { cwd: dir, stdio: 'inherit' },
    )
  }
}

// Released on their own tags, independently of Spree.
const TOOLS = ['@spree/cli', 'create-spree-app']

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
    const packages = alignedPackages()
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
  if (command === 'publish') return publish(packagesForTag(gitTag))
  throw new Error('Usage: publish-packages.mjs verify|publish <tag>')
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main(process.argv.slice(2))
