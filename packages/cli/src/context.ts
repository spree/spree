import fs from 'node:fs'
import path from 'node:path'
import { DEFAULT_SPREE_PORT } from './constants.js'
import type { ProjectContext } from './types.js'

export function detectProject(cwd: string = process.cwd()): ProjectContext {
  const composeFile = path.join(cwd, 'docker-compose.yml')

  if (!fs.existsSync(composeFile)) {
    throw new Error(
      'Not a Spree project directory. No docker-compose.yml found.\n' +
        'Run this command from a directory created with create-spree-app.',
    )
  }

  const port = readPortFromEnv(cwd)

  return {
    mode: 'docker',
    projectDir: cwd,
    port,
  }
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
