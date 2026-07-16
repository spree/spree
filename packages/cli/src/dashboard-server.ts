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

export interface DashboardDevServer {
  /**
   * The URL Vite actually reports once ready (it auto-bumps the port when
   * 5173 is taken). Falls back to the default URL if Vite never reports.
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
 * Returns null when there is no dashboard app or its dependencies aren't
 * installed yet (with a hint — first-run setup installs them, so this only
 * shows on projects that skipped it).
 */
export function startDashboardDevServer(projectDir: string): DashboardDevServer | null {
  const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
  if (!fs.existsSync(path.join(dashboardDir, 'package.json'))) return null
  if (!fs.existsSync(path.join(dashboardDir, 'node_modules'))) {
    p.log.warn(
      `${pc.bold('apps/dashboard/')} has no dependencies installed — skipping its dev server. ` +
        `Install them (cd apps/dashboard && ${detectPackageManager(projectDir, dashboardDir)} install) and rerun.`,
    )
    return null
  }

  const pm = detectPackageManager(projectDir, dashboardDir)
  const child: ChildProcess = spawn(pm, ['run', 'dev'], {
    cwd: dashboardDir,
    stdio: ['ignore', 'pipe', 'pipe'],
  })

  let resolveUrl: (url: string) => void = () => {}
  const url = new Promise<string>((resolve) => {
    resolveUrl = resolve
  })
  // Vite is normally ready in well under a second; a generous fallback keeps
  // `--open` from hanging if its output format ever changes.
  const fallback = setTimeout(() => resolveUrl(`http://localhost:${DASHBOARD_PORT}`), 30_000)
  fallback.unref()

  const forward = (stream: NodeJS.ReadableStream, out: NodeJS.WriteStream) => {
    let pending = ''
    stream.on('data', (chunk: Buffer) => {
      pending += chunk.toString()
      const lines = pending.split('\n')
      pending = lines.pop() ?? ''
      for (const line of lines) {
        out.write(`${LOG_PREFIX}${line}\n`)
        const match = line.replace(ANSI, '').match(/Local:\s+(http:\/\/\S+?)\/?\s*$/)
        if (match) {
          clearTimeout(fallback)
          resolveUrl(match[1])
        }
      }
    })
  }
  if (child.stdout) forward(child.stdout, process.stdout)
  if (child.stderr) forward(child.stderr, process.stderr)

  let stopping = false
  child.on('exit', (code) => {
    // A crash (not our stop, not the shared-terminal SIGINT) shouldn't take
    // the API down — surface it and let the stack keep running.
    if (!stopping && code !== null && code !== 0) {
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
      clearTimeout(fallback)
      if (child.exitCode === null && !child.killed) child.kill('SIGTERM')
    },
  }
}
