import { type Options as ExecaOptions, execa } from 'execa'

export async function dockerCompose(args: string[], projectDir: string, options?: ExecaOptions) {
  return execa('docker', ['compose', ...args], {
    cwd: projectDir,
    ...options,
  })
}

// web and worker share one bundle_cache named volume and, in the dev compose,
// start concurrently. On a COLD volume Docker copies the image's populated
// /usr/local/bundle into it ("copy-up") the first time a container mounts it —
// per container, with no cross-container lock. Two concurrent copy-ups race on
// mkdir of the same nested gem-extension dirs and one loses with "file exists"
// (nondeterministic, first-boot only).
//
// Fix: bring `web` up alone first and wait for it. That single container wins
// the copy-up uncontended; by the time the rest of the stack starts the volume
// is non-empty, Docker's emptiness gate is false, and no further copy-up (hence
// no race) happens. `up -d` blocks until the container is started, which is
// when the copy-up runs (during mount setup, before the entrypoint), so the
// volume is populated once this resolves. On a warm volume it's a ~1s no-op.
//
// Best-effort: a failed prime (image not built yet, daemon hiccup) is swallowed
// so the caller's real `up` builds/pulls and surfaces the genuine error — we
// remove a race, we never mask a failure.
export async function primeBundleVolume(
  projectDir: string,
  options?: { stdio?: ExecaOptions['stdio'] },
): Promise<void> {
  try {
    await dockerCompose(['up', '-d', '--no-deps', 'web'], projectDir, {
      stdio: options?.stdio ?? 'inherit',
    })
  } catch {
    // fall through to the caller's `up`, which reports any real failure
  }
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

// Whether a compose service has a running container — used by commands that
// can fall back to `compose run` when the stack is down. A defined service
// with no containers exits 0 with empty output (the legitimate false case);
// anything that makes `compose ps` itself fail — daemon down, broken compose
// file, unknown service — throws, so the caller surfaces the real error
// instead of acting on a wrong "stopped" answer.
export async function isServiceRunning(service: string, projectDir: string): Promise<boolean> {
  const { stdout } = await execa('docker', ['compose', 'ps', service, '--format', '{{.State}}'], {
    cwd: projectDir,
  })
  return stdout.split('\n').some((line) => line.trim() === 'running')
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

export interface DockerComposeRunOptions {
  service?: string
  env?: Record<string, string>
}

// Run a command in a one-off `compose run --rm` container — the twin of
// dockerComposeExec for when the service's long-running container is NOT up.
// Unlike `exec`, `run` builds a fresh container and (in Compose v2) starts the
// service's depends_on (postgres/redis/meilisearch), honoring their
// `condition: service_healthy` healthchecks before the command runs — so it
// works from a fully cold stack. We deliberately omit `--no-deps` (we WANT
// those deps started + health-waited) and `--service-ports` (these callers
// publish nothing, and skipping it avoids colliding with a running web's
// ports). `--rm` removes only this one-off container on exit; the deps it
// started are left warm for the next boot.
//
// stdio is inherited so the command stays transparent: an interactive console
// keeps its TTY, db:seed streams progress, and the inner exit code propagates.
export async function dockerComposeRun(
  argv: string[],
  projectDir: string,
  options: DockerComposeRunOptions = {},
): Promise<void> {
  const { service = 'web', env } = options
  const args = ['compose', 'run', '--rm']
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
