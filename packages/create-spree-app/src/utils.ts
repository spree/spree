import { execaCommand } from 'execa'
import crypto from 'node:crypto'
import type { PackageManager } from './types.js'

export function detectPackageManager(): PackageManager {
  const agent = process.env.npm_config_user_agent ?? ''
  if (agent.startsWith('yarn')) return 'yarn'
  if (agent.startsWith('pnpm')) return 'pnpm'
  return 'npm'
}

export async function isDockerRunning(): Promise<boolean> {
  try {
    await execaCommand('docker info', { stdio: 'ignore' })
    return true
  } catch {
    return false
  }
}

export function generateSecretKeyBase(): string {
  return crypto.randomBytes(64).toString('hex')
}

export function installCommand(pm: PackageManager): string {
  return pm === 'yarn' ? 'yarn' : `${pm} install`
}

export function runCommand(pm: PackageManager): string {
  if (pm === 'npm') return 'npx'
  if (pm === 'yarn') return 'yarn'
  return 'pnpm'
}

