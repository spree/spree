import { type ChildProcess, spawn, spawnSync } from 'node:child_process'
import { readFileSync, unlinkSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { E2E_DIR } from './paths'

export const API_GEM_DIR = resolve(E2E_DIR, '../../../spree/api')

export function rmIfExists(path: string) {
  try {
    unlinkSync(path)
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code !== 'ENOENT') throw e
  }
}

/**
 * Runs Ruby in the dummy app and returns the JSON object it prints last —
 * whatever the script needs to hand back to the specs.
 */
export function runRailsBootstrap(ruby: string, env: NodeJS.ProcessEnv): string {
  // The script goes through argv to sidestep shell quoting (the Ruby contains
  // both single and double quotes).
  const result = spawnSync('bundle', ['exec', 'spec/dummy/bin/rails', 'runner', ruby], {
    cwd: API_GEM_DIR,
    encoding: 'utf-8',
    timeout: 120_000,
    maxBuffer: 10 * 1024 * 1024,
    env,
  })
  if (result.status !== 0) {
    throw new Error(`Bootstrap runner failed:\n${result.stderr}\n${result.stdout}`)
  }
  const jsonMatch = result.stdout.match(/\{.*\}\s*$/)
  if (!jsonMatch) {
    throw new Error(`Failed to parse bootstrap output:\n${result.stdout}`)
  }
  return jsonMatch[0]
}

async function waitForServer(url: string, timeoutMs = 30_000): Promise<void> {
  const start = Date.now()
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(url)
      if (res.status < 500) return
    } catch {
      /* not ready */
    }
    await new Promise((r) => setTimeout(r, 500))
  }
  throw new Error(`Server did not start within ${timeoutMs}ms at ${url}`)
}

export async function startRails(port: string, env: NodeJS.ProcessEnv, pidFile: string) {
  const serverProcess: ChildProcess = spawn(
    'bundle',
    ['exec', 'spec/dummy/bin/rails', 'server', '-p', port, '-e', 'test'],
    { cwd: API_GEM_DIR, stdio: ['ignore', 'pipe', 'pipe'], env },
  )

  serverProcess.stderr?.on('data', (data: Buffer) => {
    const msg = data.toString()
    if (msg.includes('Error') || msg.includes('error')) console.error('[rails]', msg)
  })

  if (serverProcess.pid) writeFileSync(pidFile, String(serverProcess.pid))

  await waitForServer(`http://localhost:${port}/api/v3/admin/me`)
}

export function stopRails(pidFile: string) {
  let pid: number
  try {
    pid = Number.parseInt(readFileSync(pidFile, 'utf-8'), 10)
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code === 'ENOENT') return
    throw e
  }

  try {
    process.kill(pid, 'SIGTERM')
  } catch {
    // Process already dead.
  }

  rmIfExists(pidFile)
}
