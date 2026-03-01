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

export async function railsRunner(
  script: string,
  projectDir: string,
): Promise<string> {
  const { stdout } = await execa(
    'docker',
    ['compose', 'exec', '-T', 'web', 'bin/rails', 'runner', script],
    { cwd: projectDir },
  )
  return stdout
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
