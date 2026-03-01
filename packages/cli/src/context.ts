import fs from 'node:fs'
import path from 'node:path'
import type { ProjectContext } from './types.js'
import { DEFAULT_SPREE_PORT } from './constants.js'

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

export function readPortFromEnv(projectDir: string): number {
  const envPath = path.join(projectDir, '.env')

  if (!fs.existsSync(envPath)) {
    return DEFAULT_SPREE_PORT
  }

  const content = fs.readFileSync(envPath, 'utf-8')
  const match = content.match(/^SPREE_PORT=(\d+)/m)

  return match ? Number(match[1]) : DEFAULT_SPREE_PORT
}
