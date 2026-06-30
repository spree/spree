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

// create-spree-app clones spree-starter into <root>/backend/ and copies its
// compose files UP to the wrapper root, rewriting the dev bind-mount to
// `./backend:/rails` and writing the only real `.env` at the root. The cloned
// `backend/docker-compose.yml` is left behind as a stale leftover (mounts
// `.:/rails`, expects a sibling `.env` that does not exist). Running the CLI
// from `backend/` would target that broken file. When we can prove `cwd` is
// the wrapper's `backend/` and the parent is the real (adjusted) root, re-root
// there so every command runs against the runnable compose + root `.env`.
function resolveProjectDir(cwd: string): string {
  if (path.basename(cwd) !== 'backend') return cwd

  const parent = path.dirname(cwd)
  if (!fs.existsSync(path.join(parent, 'docker-compose.yml'))) return cwd

  // The parent is the real wrapper root only if its compose was adjusted by the
  // scaffold to mount THIS dir (`./backend:/rails`). The rewrite lands in the
  // dev overlay (the base file is copied verbatim), so scan both. A coincidental
  // nested layout — a `backend/` dir under an unrelated compose project — won't
  // contain this exact marker, so re-root stays a no-op there.
  for (const name of ['docker-compose.yml', 'docker-compose.dev.yml']) {
    const file = path.join(parent, name)
    if (!fs.existsSync(file)) continue
    try {
      // matches "- ./backend:/rails" and "- ./backend:/rails:cached" etc.
      if (/\.\/backend:\/rails(:\w+)?(\s|$)/m.test(fs.readFileSync(file, 'utf-8'))) {
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

export function readPortFromEnv(projectDir: string): number {
  const envPath = path.join(projectDir, '.env')

  if (!fs.existsSync(envPath)) {
    return DEFAULT_SPREE_PORT
  }

  const content = fs.readFileSync(envPath, 'utf-8')
  const match = content.match(/^SPREE_PORT=(\d+)/m)

  return match ? Number(match[1]) : DEFAULT_SPREE_PORT
}
