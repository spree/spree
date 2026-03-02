import { execa, type Options as ExecaOptions } from 'execa'

/** Escape a string for safe interpolation into a Ruby single-quoted string. */
export function escapeRubyString(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/'/g, "\\'")
}

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

export async function railsRunner(
  script: string,
  projectDir: string,
): Promise<string> {
  const { stdout } = await execa(
    'docker',
    ['compose', 'exec', '-T', 'web', 'bin/rails', 'runner', script],
    { cwd: projectDir },
  )

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
