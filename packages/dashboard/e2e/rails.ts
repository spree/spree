import { type ChildProcess, spawn, spawnSync } from 'node:child_process'
import { readFileSync, unlinkSync, writeFileSync } from 'node:fs'
import { createServer } from 'node:net'
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

// Anything already listening on the port would answer the readiness probe
// long before Rails boots, handing the suite someone else's database.
async function assertPortFree(port: string): Promise<void> {
  await new Promise<void>((resolvePromise, reject) => {
    const probe = createServer()
    probe.once('error', () =>
      reject(new Error(`Port ${port} is already in use — stop whatever is listening on it`)),
    )
    probe.listen(Number(port), () => probe.close(() => resolvePromise()))
  })
}

// A server that exits before answering fails the start instead of timing out.
async function waitForServer(
  url: string,
  serverProcess: ChildProcess,
  timeoutMs = 30_000,
): Promise<void> {
  let exitCode: number | null = null
  serverProcess.once('exit', (code) => {
    exitCode = code ?? -1
  })

  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    if (exitCode !== null)
      throw new Error(`Rails exited with code ${exitCode} before ${url} answered`)
    try {
      const res = await fetch(url, {
        signal: AbortSignal.timeout(Math.max(deadline - Date.now(), 1)),
      })
      if (exitCode === null && res.status < 500) return
    } catch {
      /* not ready */
    }
    await new Promise((r) => setTimeout(r, 500))
  }
  throw new Error(`Server did not start within ${timeoutMs}ms at ${url}`)
}

export async function startRails(port: string, env: NodeJS.ProcessEnv, pidFile: string) {
  await assertPortFree(port)

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

  await waitForServer(`http://localhost:${port}/api/v3/admin/me`, serverProcess)
}

function isRunning(pid: number): boolean {
  try {
    process.kill(pid, 0)
    return true
  } catch {
    return false
  }
}

// Waits for the server to exit, so a run started straight after this one
// cannot find the old server still holding its port or database.
export async function stopRails(pidFile: string, timeoutMs = 15_000) {
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

  const deadline = Date.now() + timeoutMs
  while (isRunning(pid) && Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 200))
  }
  if (isRunning(pid)) process.kill(pid, 'SIGKILL')

  rmIfExists(pidFile)
}
