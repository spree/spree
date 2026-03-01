import { execaCommand } from 'execa'
import crypto from 'node:crypto'
import net from 'node:net'
import { platform } from 'node:os'
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

export async function getAvailablePort(preferred: number): Promise<number> {
  for (let port = preferred; port < preferred + 100; port++) {
    if (await isPortAvailable(port)) return port
  }
  throw new Error(`No available port found in range ${preferred}-${preferred + 99}`)
}

function isPortAvailable(port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const server = net.createServer()
    server.once('error', () => resolve(false))
    server.once('listening', () => server.close(() => resolve(true)))
    server.listen(port)
  })
}

export async function openBrowser(url: string): Promise<void> {
  const os = platform()
  const cmd = os === 'darwin' ? 'open' : os === 'win32' ? 'start' : 'xdg-open'

  try {
    await execaCommand(`${cmd} ${url}`, { stdio: 'ignore' })
  } catch {
    // Silently fail — browser open is best-effort
  }
}
