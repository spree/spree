import { spawn } from 'node:child_process'
import { execa } from 'execa'

const CTRL_C = '\x03'

/**
 * Whether this process can hand the terminal over to a shell in the project
 * directory once the servers stop. Only on an interactive POSIX terminal:
 * Windows has no process groups to forward Ctrl+C to.
 */
export function canOpenProjectShell(): boolean {
  return Boolean(process.stdin.isTTY && process.stdout.isTTY) && process.platform !== 'win32'
}

/**
 * Runs a long-lived command (first-run setup, then streaming logs) until it
 * exits or the user presses Ctrl+C. Resolves `true` when Ctrl+C stopped it.
 *
 * Ctrl+C normally sends SIGINT to the whole foreground process group, which
 * includes the `npx` / `pnpm dlx` wrapper that launched us — the wrapper exits,
 * the shell takes the terminal back, and nothing can run afterwards. So the
 * terminal goes into raw mode (Ctrl+C becomes a keypress, not a signal) and
 * the keypress is forwarded as SIGINT to the command's own process group only.
 */
export async function runUntilInterrupted(
  command: string,
  args: string[],
  cwd: string,
): Promise<boolean> {
  if (!canOpenProjectShell()) {
    await execa(command, args, { cwd, stdio: 'inherit' })
    return false
  }

  const child = execa(command, args, {
    cwd,
    detached: true,
    stdin: 'ignore',
    stdout: 'inherit',
    stderr: 'inherit',
  })
  const pid = child.pid

  let interrupted = false
  const signalGroup = (signal: NodeJS.Signals) => {
    if (pid === undefined) return
    try {
      process.kill(-pid, signal)
    } catch {
      // Already gone.
    }
  }
  const onKey = (data: Buffer) => {
    if (!data.toString().includes(CTRL_C)) return
    interrupted = true
    signalGroup('SIGINT')
  }
  // A detached group outlives us unless stopped explicitly.
  const onExit = () => signalGroup('SIGTERM')

  process.stdin.setRawMode(true)
  process.stdin.on('data', onKey)
  process.stdin.resume()
  process.on('exit', onExit)

  try {
    await child
  } catch (err) {
    if (!interrupted) throw err
  } finally {
    process.off('exit', onExit)
    process.stdin.off('data', onKey)
    process.stdin.setRawMode(false)
    process.stdin.pause()
  }
  return interrupted
}

/**
 * Opens the user's shell in `dir` and waits for it to exit. A program cannot
 * change its parent shell's directory, so this nested shell is how the user
 * lands in the new project after stopping the servers.
 */
export async function openShell(dir: string): Promise<void> {
  const shell = process.env.SHELL || '/bin/sh'
  // Ctrl+C inside the shell is the shell's business, never a reason to exit.
  const ignore = () => {}
  process.on('SIGINT', ignore)
  try {
    await new Promise<void>((resolve) => {
      const child = spawn(shell, [], { cwd: dir, stdio: 'inherit' })
      child.on('exit', () => resolve())
      child.on('error', () => resolve())
    })
  } finally {
    process.off('SIGINT', ignore)
  }
}
