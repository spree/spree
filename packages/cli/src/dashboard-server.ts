import { type ChildProcess, spawn } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import pc from 'picocolors'
import { detectPackageManager } from './commands/add.js'
import { DASHBOARD_PORT } from './constants.js'

export function hasDashboardApp(projectDir: string): boolean {
  return fs.existsSync(path.join(projectDir, 'apps', 'dashboard', 'package.json'))
}

/**
 * Whether the dashboard dev server can actually start — the app exists and
 * its dependencies are installed. Callers key the admin summary, `--open`,
 * and the spawn off this one answer so they can't disagree.
 */
export function dashboardDevRunnable(projectDir: string): boolean {
  const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
  return (
    fs.existsSync(path.join(dashboardDir, 'package.json')) &&
    fs.existsSync(path.join(dashboardDir, 'node_modules'))
  )
}

/** The install hint printed when the app exists but isn't runnable. */
export function warnDashboardNotRunnable(projectDir: string): void {
  const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
  p.log.warn(
    `${pc.bold('apps/dashboard/')} has no dependencies installed — skipping its dev server. ` +
      `Install them (cd apps/dashboard && ${detectPackageManager(projectDir, dashboardDir)} install) and rerun.`,
  )
}

export interface DashboardDevServer {
  /**
   * The URL Vite actually reports once ready (it auto-bumps the port when
   * 5173 is taken). Always settles — falls back to the default URL on
   * timeout, spawn failure, early exit, or stop().
   */
  url: Promise<string>
  stop: () => void
}

// Column-aligned with compose's `web-1        | ` log prefixes, so the
// multiplexed stream reads as one stack.
const LOG_PREFIX = pc.dim('dashboard    | ')

// Strips ANSI color codes for matching (Vite's output is colored). Built
// from a char code — regex literals disallow control-character escapes.
const ANSI = new RegExp(`${String.fromCharCode(27)}\\[[0-9;]*m`, 'g')

/**
 * Start the dashboard's Vite dev server as a sibling of the Docker stack —
 * `spree dev` and first-run setup co-run it, so one command brings up the
 * whole dev environment. Output is line-prefixed into the shared stream.
 * Any failure degrades to a warning: a dashboard that can't start or
 * crashes must never take the API down.
 */
export function startDashboardDevServer(projectDir: string): DashboardDevServer | null {
  if (!dashboardDevRunnable(projectDir)) return null

  const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
  const pm = detectPackageManager(projectDir, dashboardDir)
  // detached (POSIX): its own process group, so stop() can signal the whole
  // tree — `pm run dev` wraps Vite in a child, and SIGTERM to the wrapper
  // alone can leave Vite orphaned holding the port. Windows gets shell mode
  // for the .cmd shims and plain kill (no group signals).
  const windows = process.platform === 'win32'
  const child: ChildProcess = spawn(pm, ['run', 'dev'], {
    cwd: dashboardDir,
    stdio: ['ignore', 'pipe', 'pipe'],
    detached: !windows,
    shell: windows,
  })

  const fallbackUrl = `http://localhost:${DASHBOARD_PORT}`
  let settled = false
  let resolveUrl: (url: string) => void = () => {}
  const url = new Promise<string>((resolve) => {
    resolveUrl = resolve
  })
  const settle = (value: string) => {
    settled = true
    clearTimeout(fallback)
    resolveUrl(value)
  }
  // Vite is normally ready in well under a second; a generous fallback keeps
  // `--open` from hanging if its output format ever changes.
  const fallback = setTimeout(() => settle(fallbackUrl), 30_000)
  fallback.unref()

  const forward = (stream: NodeJS.ReadableStream, out: NodeJS.WriteStream) => {
    let pending = ''
    stream.on('data', (chunk: Buffer) => {
      pending += chunk.toString()
      const lines = pending.split('\n')
      pending = lines.pop() ?? ''
      for (const line of lines) {
        out.write(`${LOG_PREFIX}${line}\n`)
        if (!settled) {
          const match = line.replace(ANSI, '').match(/Local:\s+(http:\/\/\S+?)\/?\s*$/)
          if (match) settle(match[1])
        }
      }
    })
  }
  if (child.stdout) forward(child.stdout, process.stdout)
  if (child.stderr) forward(child.stderr, process.stderr)

  let stopping = false

  // A spawn failure (missing binary, PATH issues) emits 'error' — unhandled
  // it would crash the CLI, the opposite of crash isolation.
  child.on('error', (error) => {
    settle(fallbackUrl)
    p.log.warn(
      `Could not start the dashboard dev server (${error.message}) — start it manually with ` +
        `${pc.bold(`cd apps/dashboard && ${pm} run dev`)}. The API keeps running.`,
    )
  })

  child.on('exit', (code, signal) => {
    settle(fallbackUrl)
    // Only a genuine crash warns: not our stop(), and not a signal exit —
    // Ctrl+C reaches the child before stop() runs, as SIGINT (signal) or a
    // 130 exit code depending on the package manager.
    if (!stopping && signal === null && code !== null && code !== 0 && code !== 130) {
      p.log.warn(
        `The dashboard dev server exited (code ${code}) — restart it with ` +
          `${pc.bold(`cd apps/dashboard && ${pm} run dev`)}. The API keeps running.`,
      )
    }
  })

  return {
    url,
    stop: () => {
      stopping = true
      settle(fallbackUrl)
      if (child.exitCode !== null || child.killed) return
      if (!windows && child.pid) {
        // Signal the whole process group so Vite goes down with its wrapper.
        try {
          process.kill(-child.pid, 'SIGTERM')
          return
        } catch {
          // group already gone — fall through to the direct kill
        }
      }
      child.kill('SIGTERM')
    },
  }
}
