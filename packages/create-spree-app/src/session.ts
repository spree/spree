import { execa } from 'execa'

const CTRL_C = '\x03'

/**
 * Whether Ctrl+C can be caught as a keypress: only on an interactive POSIX
 * terminal. Windows has no process groups to forward it to.
 */
function canCatchCtrlC(): boolean {
  return Boolean(process.stdin.isTTY && process.stdout.isTTY) && process.platform !== 'win32'
}

/**
 * Runs a long-lived command (first-run setup, then streaming logs) until it
 * exits or the user presses Ctrl+C. Resolves `true` when Ctrl+C stopped it.
 *
 * Ctrl+C normally sends SIGINT to the whole foreground process group, which
 * includes the `npx` / `pnpm dlx` wrapper that launched us — the wrapper exits,
 * and this process dies before it can print what to do next. So the
 * terminal goes into raw mode (Ctrl+C becomes a keypress, not a signal) and
 * the keypress is forwarded as SIGINT to the command's own process group only.
 */
export async function runUntilInterrupted(
  command: string,
  args: string[],
  cwd: string,
): Promise<boolean> {
  if (!canCatchCtrlC()) {
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
