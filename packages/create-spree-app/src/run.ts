import { x } from 'tinyexec'

/**
 * Runs a command without a shell and throws when it exits non-zero. Arguments
 * are passed as-is on every platform, including to Windows `.cmd` shims.
 */
export async function run(
  file: string,
  args: string[],
  options: { cwd?: string; stdio: 'inherit' | 'ignore' },
): Promise<void> {
  await x(file, args, { throwOnError: true, nodePath: false, nodeOptions: options })
}
