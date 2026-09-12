import fs from 'node:fs'
import path from 'node:path'
import { DEFAULT_SPREE_PORT } from './constants.js'
import type { ProjectContext } from './types.js'

export function detectProject(cwd: string = process.cwd()): ProjectContext {
  const projectDir = resolveProjectDir(cwd)
  const composeFile = path.join(projectDir, 'docker-compose.yml')

  if (!fs.existsSync(composeFile)) {
    throw new Error(
      'Not a Spree project directory. No docker-compose.yml found.\n' +
        'Run this command from a directory created with create-spree-app.',
    )
  }

  const port = readPortFromEnv(projectDir)

  return {
    mode: 'docker',
    projectDir,
    port,
  }
}

// The Rails API directory a scaffolded project keeps its app in. `server` is
// what create-spree-app writes now; `backend` is what it wrote before the
// Rails app became API-only, and is still accepted so existing projects keep
// working.
export const API_DIRS = ['server', 'backend'] as const

// The API directory an existing project actually uses: whichever of API_DIRS
// is present, preferring `server`. Falls back to `server` so error messages
// name the current layout when neither exists.
export function findApiDir(projectDir: string): string {
  return API_DIRS.find((dir) => fs.existsSync(path.join(projectDir, dir))) ?? 'server'
}

// create-spree-app clones spree-starter into <root>/server/ and copies its
// compose files UP to the wrapper root, rewriting the dev bind-mount to
// `./server:/rails` and writing the only real `.env` at the root. The cloned
// `server/docker-compose.yml` is left behind as a stale leftover (mounts
// `.:/rails`, expects a sibling `.env` that does not exist). Running the CLI
// from `server/` would target that broken file. When we can prove `cwd` is
// the wrapper's API directory and the parent is the real (adjusted) root,
// re-root there so every command runs against the runnable compose + root `.env`.
function resolveProjectDir(cwd: string): string {
  const dirName = path.basename(cwd)
  if (!API_DIRS.includes(dirName as (typeof API_DIRS)[number])) return cwd

  const parent = path.dirname(cwd)

  // The parent is the real wrapper root only if its compose was adjusted by the
  // scaffold to mount THIS dir (`./server:/rails`). The rewrite lands in the
  // dev overlay (the base file is copied verbatim), so scan both. A coincidental
  // nested layout — a `server/` dir under an unrelated compose project — won't
  // contain this exact marker, so re-root stays a no-op there.
  const mountMarker = new RegExp(`\\./${dirName}:/rails(:\\w+)?(\\s|$)`, 'm')
  for (const name of ['docker-compose.yml', 'docker-compose.dev.yml']) {
    const file = path.join(parent, name)
    if (!fs.existsSync(file)) continue
    try {
      // matches "- ./server:/rails" and "- ./server:/rails:cached" etc.
      if (mountMarker.test(fs.readFileSync(file, 'utf-8'))) {
        return parent
      }
    } catch {
      // unreadable file — ignore, keep checking
    }
  }

  return cwd
}

// Monorepo edge projects (SPREE_PATH in .env) are booted from the monorepo
// root with the dev + edge compose overlay — the project-local
// docker-compose.yml the CLI would target is not the running config.
// Commands that materialize compose config (up, build) must refuse here;
// label-based commands (exec, stop, restart, logs) resolve the same
// compose project either way and keep working.
export function hasMonorepoSpreePath(projectDir: string): boolean {
  const envPath = path.join(projectDir, '.env')
  if (!fs.existsSync(envPath)) return false
  try {
    const contents = fs.readFileSync(envPath, 'utf-8')
    return /^\s*SPREE_PATH\s*=/m.test(contents)
  } catch {
    return false
  }
}

// A project is "ejected" once `spree eject` swaps in the dev compose, whose
// service carries a `build:` section pointing at the API directory — the prebuilt-image
// compose has none. Gates steps that only apply to the bind-mounted,
// build-from-source dev stack (e.g. compiling admin assets the image would have
// baked in but the bind-mount now masks).
export function isEjectedProject(projectDir: string): boolean {
  const composeFile = path.join(projectDir, 'docker-compose.yml')
  if (!fs.existsSync(composeFile)) return false
  try {
    // Cheap YAML probe — `build:` at the start of a line is the only valid
    // position for a service-level build directive.
    return /^\s*build\s*:/m.test(fs.readFileSync(composeFile, 'utf-8'))
  } catch {
    return false
  }
}

/**
 * The sample-data choice create-spree-app persists in `.env`, so a deferred
 * first run (through `spree dev`) honors the answer given at scaffold time.
 * Returns `undefined` when `.env` doesn't declare one (older projects,
 * hand-rolled `.env`) — callers decide the default. A declared value also
 * fingerprints the project as scaffolded by a create-spree-app that persists
 * setup state, which `spree dev` uses to detect unfinished setup.
 */
export function readSampleDataFromEnv(projectDir: string): boolean | undefined {
  try {
    const content = fs.readFileSync(path.join(projectDir, '.env'), 'utf-8')
    const match = content.match(/^SPREE_SAMPLE_DATA=(true|false)\b/m)
    return match ? match[1] === 'true' : undefined
  } catch {
    return undefined
  }
}

export function readPortFromEnv(projectDir: string): number {
  const envPath = path.join(projectDir, '.env')

  if (!fs.existsSync(envPath)) {
    return DEFAULT_SPREE_PORT
  }

  const content = fs.readFileSync(envPath, 'utf-8')
  const match = content.match(/^SPREE_PORT=(\d+)/m)

  return match ? Number(match[1]) : DEFAULT_SPREE_PORT
}
