import { type Options as ExecaOptions, execa } from 'execa'

export async function dockerCompose(args: string[], projectDir: string, options?: ExecaOptions) {
  return execa('docker', ['compose', ...args], {
    cwd: projectDir,
    ...options,
  })
}

export async function rakeTask(
  task: string,
  projectDir: string,
  env?: Record<string, string>,
): Promise<string> {
  const args = ['compose', 'exec', '-T']

  if (env) {
    for (const [key, value] of Object.entries(env)) {
      args.push('-e', `${key}=${value}`)
    }
  }

  args.push('web', 'bin/rails', task)

  const { stdout } = await execa('docker', args, { cwd: projectDir })

  // Rails boot prints noise to stdout (e.g. "[Spree Events] ...") — strip it
  return stdout
    .split('\n')
    .filter((line) => !line.startsWith('['))
    .join('\n')
    .trim()
}

export interface DockerComposeExecOptions {
  service?: string
  tty?: boolean
  env?: Record<string, string>
}

// Run a command inside a service container. The foundation for `spree exec`,
// `spree rails`, `spree bundle`, `spree rake`, and `spree console`.
//
// Defaults to the `web` service and an interactive TTY. Pass `tty: false`
// (which adds `-T`) for non-interactive callers that capture stdout — those
// should use `rakeTask` above, which already does this.
//
// stdio is inherited so the command behaves transparently: a Rails console
// stays interactive, a `bundle add` prints progress, an error exits with the
// inner command's exit code.
export async function dockerComposeExec(
  argv: string[],
  projectDir: string,
  options: DockerComposeExecOptions = {},
): Promise<void> {
  const { service = 'web', tty = true, env } = options
  const args = ['compose', 'exec']
  if (!tty) args.push('-T')
  if (env) {
    for (const [key, value] of Object.entries(env)) {
      args.push('-e', `${key}=${value}`)
    }
  }
  args.push(service, ...argv)

  await execa('docker', args, { cwd: projectDir, stdio: 'inherit' })
}

export async function streamLogs(service: string, projectDir: string): Promise<void> {
  await execa('docker', ['compose', 'logs', '-f', service], {
    cwd: projectDir,
    stdio: 'inherit',
  })
}
