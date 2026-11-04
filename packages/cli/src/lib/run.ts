import { x } from 'tinyexec'

type Stdio = 'pipe' | 'inherit' | 'ignore'

export interface RunOptions {
  cwd?: string
  /** Applies to all three streams unless one is set on its own. Defaults to `pipe`. */
  stdio?: Stdio
  stdin?: Stdio
  stdout?: Stdio
  /** `['pipe', 'inherit']` prints stderr live and also keeps it for the error. */
  stderr?: Stdio | ['pipe', 'inherit']
  /** When false, a failed command resolves with its exit code instead of throwing. */
  reject?: boolean
  timeout?: number
}

export interface RunResult {
  stdout: string
  stderr: string
  exitCode: number
}

/** A command that exited non-zero. The message carries its output, so callers can match on it. */
export class RunError extends Error implements RunResult {
  constructor(
    command: string,
    readonly exitCode: number,
    readonly stdout: string,
    readonly stderr: string,
  ) {
    super(
      [`Command failed with exit code ${exitCode}: ${command}`, stderr, stdout]
        .filter(Boolean)
        .join('\n\n'),
    )
    this.name = 'RunError'
  }
}

const stripFinalNewline = (text: string) => text.replace(/\r?\n$/, '')

/**
 * Runs a command without a shell. Arguments are passed as-is on every
 * platform, including to Windows `.cmd` shims such as `pnpm`.
 */
export async function run(
  file: string,
  args: string[] = [],
  options: RunOptions = {},
): Promise<RunResult> {
  const { cwd, stdio = 'pipe', reject = true, timeout } = options
  const teeStderr = Array.isArray(options.stderr)
  const child = x(file, args, {
    timeout,
    throwOnError: false,
    nodePath: false,
    nodeOptions: {
      cwd,
      stdio: [
        options.stdin ?? stdio,
        options.stdout ?? stdio,
        teeStderr ? 'pipe' : ((options.stderr as Stdio | undefined) ?? stdio),
      ],
    },
  })
  if (teeStderr) child.process?.stderr?.on('data', (chunk: Buffer) => process.stderr.write(chunk))

  let result: RunResult
  try {
    const output = await child
    result = {
      stdout: stripFinalNewline(output.stdout),
      stderr: stripFinalNewline(output.stderr),
      exitCode: child.exitCode ?? (child.signalCode ? 1 : 0),
    }
  } catch (cause) {
    // The command could not start (not installed) or ran past its timeout.
    const timedOut =
      cause instanceof Error && (cause.cause as Error | undefined)?.name === 'TimeoutError'
    const error = timedOut
      ? new Error(`Command timed out after ${timeout} ms: ${[file, ...args].join(' ')}`)
      : cause
    if (reject) throw error
    return {
      stdout: '',
      stderr: error instanceof Error ? error.message : String(error),
      exitCode: 1,
    }
  }

  if (result.exitCode !== 0 && reject) {
    throw new RunError([file, ...args].join(' '), result.exitCode, result.stdout, result.stderr)
  }
  return result
}
