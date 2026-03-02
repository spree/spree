import { execa, type Options as ExecaOptions } from 'execa'

export async function dockerCompose(
  args: string[],
  projectDir: string,
  options?: ExecaOptions,
) {
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

export async function railsConsole(projectDir: string): Promise<void> {
  await execa('docker', ['compose', 'exec', 'web', 'bin/rails', 'c'], {
    cwd: projectDir,
    stdio: 'inherit',
  })
}

export async function streamLogs(
  service: string,
  projectDir: string,
): Promise<void> {
  await execa('docker', ['compose', 'logs', '-f', service], {
    cwd: projectDir,
    stdio: 'inherit',
  })
}
