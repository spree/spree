// Shared steps of the scripts that bump spree-starter and the storefront after
// a release. Commands run with argument lists, never through a shell, so a
// list of gem names stays a list whatever shell started the script.
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

export const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')

/**
 * Runs a command, printing its output, and returns nothing. Throws when it fails.
 *
 * @param {string} command
 * @param {string[]} args
 * @param {{ cwd?: string, env?: Record<string, string> }} [options]
 */
export function run(command, args, { cwd = repoRoot, env = {} } = {}) {
  execFileSync(command, args, { cwd, stdio: 'inherit', env: { ...process.env, ...env } })
}

/**
 * Runs a command and returns its standard output.
 *
 * @param {string} command
 * @param {string[]} args
 * @param {{ cwd?: string }} [options]
 * @returns {string}
 */
export function read(command, args, { cwd = repoRoot } = {}) {
  return execFileSync(command, args, {
    cwd,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'inherit'],
  })
}

/**
 * Calls `attempt` until it returns true, waiting a minute between tries. The
 * registries serve a new version to their APIs before their install indexes,
 * so an install right after a release can fail for several minutes.
 *
 * @param {string} what
 * @param {() => boolean} attempt
 * @param {number} [tries]
 */
export function retry(what, attempt, tries = 10) {
  for (let i = 1; i <= tries; i++) {
    try {
      if (attempt()) return
    } catch (error) {
      if (i === tries) throw error
    }
    if (i === tries) break
    console.log(`${what}: not available yet, trying again in a minute (${i}/${tries}).`)
    execFileSync('sleep', ['60'])
  }
  throw new Error(`${what}: still not available after ${tries} tries.`)
}

/**
 * A fresh clone of `repository` in `tmp/<name>`, on a new branch.
 *
 * @param {string} repository `owner/name`
 * @param {string} branch
 * @returns {string} the clone's path
 */
export function freshClone(repository, branch) {
  const dir = path.join(repoRoot, 'tmp', repository.split('/')[1])
  fs.rmSync(dir, { recursive: true, force: true })
  run('git', ['clone', '--quiet', `https://github.com/${repository}.git`, dir])
  run('git', ['switch', '--quiet', '-c', branch], { cwd: dir })
  return dir
}

/**
 * Throws when the clone's changes touch anything outside `allowed` (paths or
 * directory prefixes ending in `/`).
 *
 * @param {string} dir
 * @param {string[]} allowed
 */
export function assertChangedOnly(dir, allowed) {
  const changed = read('git', ['status', '--porcelain'], { cwd: dir })
    .split('\n')
    .filter(Boolean)
    .map((line) => line.slice(3))
  const unexpected = changed.filter(
    (file) =>
      !allowed.some((entry) => (entry.endsWith('/') ? file.startsWith(entry) : file === entry)),
  )
  if (unexpected.length > 0) {
    throw new Error(
      `Unexpected changes, so a step ran against the wrong app: ${unexpected.join(', ')}`,
    )
  }
}

/** `6.0.5` → `6-0-5`, for branch names. */
export const dashed = (version) => version.replaceAll('.', '-')
