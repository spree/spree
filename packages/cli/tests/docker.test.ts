import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('execa', () => ({ execa: vi.fn().mockResolvedValue({ stdout: '' }) }))

let monorepoEdge = false
vi.mock('../src/context', () => ({
  hasMonorepoSpreePath: () => monorepoEdge,
}))

const cancelMock = vi.fn()
const logInfoMock = vi.fn()
vi.mock('@clack/prompts', () => ({
  cancel: (...args: unknown[]) => cancelMock(...args),
  log: { info: (...args: unknown[]) => logInfoMock(...args) },
}))

import { execa } from 'execa'
import {
  buildAdminStylesheets,
  dockerComposeCapture,
  dockerComposeExecOrRun,
  dockerComposeRun,
  rakeTask,
  watchAdminStylesheets,
} from '../src/docker'

const mockExeca = vi.mocked(execa)

// The exec-or-run helpers make several `execa` calls (the `compose ps` probe,
// then `exec`/`run`). Route by args: the probe contains `ps`, everything else
// is the command itself. Lets a single mock drive web-up vs web-down.
function routeExeca(webUp: boolean, commandStdout = ''): void {
  mockExeca.mockImplementation((async (_cmd: string, args: string[]) => {
    if (args.includes('ps')) return { stdout: webUp ? 'running' : '' }
    return { stdout: commandStdout }
  }) as never)
}

describe('dockerComposeRun', () => {
  afterEach(() => mockExeca.mockReset())

  it('builds `compose run --rm <service> <argv>` with inherited stdio', async () => {
    await dockerComposeRun(['bin/rails', 'console'], '/proj')

    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'run', '--rm', 'web', 'bin/rails', 'console'],
      { cwd: '/proj', stdio: 'inherit' },
    )
  })

  it('honors a non-default service', async () => {
    await dockerComposeRun(['psql'], '/proj', { service: 'postgres' })

    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'run', '--rm', 'postgres', 'psql'],
      { cwd: '/proj', stdio: 'inherit' },
    )
  })

  it('threads -e KEY=VALUE pairs before the service, like dockerComposeExec', async () => {
    await dockerComposeRun(['bin/rake', 'spree:upgrade'], '/proj', {
      env: { DRY_RUN: '1', STEP: 'channels' },
    })

    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      [
        'compose',
        'run',
        '--rm',
        '-e',
        'DRY_RUN=1',
        '-e',
        'STEP=channels',
        'web',
        'bin/rake',
        'spree:upgrade',
      ],
      { cwd: '/proj', stdio: 'inherit' },
    )
  })

  it('does not pass --no-deps (deps must start + health-wait)', async () => {
    await dockerComposeRun(['bin/rails', 'db:drop'], '/proj')

    const [, args] = mockExeca.mock.calls[0] as [string, string[]]
    expect(args).not.toContain('--no-deps')
  })

  it('inherits stdio wholesale by default (no stderr capture)', async () => {
    await dockerComposeRun(['bin/rails', 'console'], '/proj')

    const [, , opts] = mockExeca.mock.calls[0] as [string, string[], Record<string, unknown>]
    expect(opts).toMatchObject({ cwd: '/proj', stdio: 'inherit' })
  })

  it('tees stderr to `[pipe, inherit]` when captureStderr is set', async () => {
    // Plain `stdio: inherit` leaves ExecaError.stderr undefined; the tee keeps it
    // printed live AND buffered so db:reset can match the Postgres error.
    await dockerComposeRun(['bin/rails', 'db:drop'], '/proj', { captureStderr: true })

    const [, , opts] = mockExeca.mock.calls[0] as [string, string[], Record<string, unknown>]
    expect(opts).toMatchObject({
      cwd: '/proj',
      stdin: 'inherit',
      stdout: 'inherit',
      stderr: ['pipe', 'inherit'],
    })
    expect(opts).not.toHaveProperty('stdio')
  })
})

describe('buildAdminStylesheets', () => {
  afterEach(() => mockExeca.mockReset())

  it('runs the admin tailwind build via a non-interactive compose exec on web', async () => {
    await buildAdminStylesheets('/proj')

    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'exec', '-T', 'web', 'bin/rails', 'spree:admin:tailwindcss:build'],
      { cwd: '/proj', stdio: 'inherit' },
    )
  })
})

describe('watchAdminStylesheets', () => {
  afterEach(() => mockExeca.mockReset())

  it('starts the admin tailwind watcher detached inside web', async () => {
    await watchAdminStylesheets('/proj')

    // `-d` detaches so the watcher runs alongside the foreground web+worker
    // logs and dies with the web container on Ctrl+C.
    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'exec', '-d', 'web', 'bin/rails', 'spree:admin:tailwindcss:watch'],
      { cwd: '/proj', stdio: 'inherit' },
    )
  })
})

describe('dockerComposeExecOrRun', () => {
  class ExitError extends Error {
    constructor(public code: number) {
      super(`process.exit(${code})`)
    }
  }

  beforeEach(() => {
    monorepoEdge = false
    cancelMock.mockClear()
    logInfoMock.mockClear()
    mockExeca.mockReset()
    vi.spyOn(process, 'exit').mockImplementation((code?: number) => {
      throw new ExitError(code ?? 0)
    })
  })

  afterEach(() => vi.restoreAllMocks())

  it('execs into the running container when the service is up', async () => {
    routeExeca(true)

    await dockerComposeExecOrRun(['bin/rails', 'console'], '/proj')

    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'exec', 'web', 'bin/rails', 'console'],
      { cwd: '/proj', stdio: 'inherit' },
    )
    expect(mockExeca).not.toHaveBeenCalledWith(
      'docker',
      expect.arrayContaining(['run']),
      expect.anything(),
    )
  })

  it('falls back to a one-off `run` container when the service is down', async () => {
    routeExeca(false)

    await dockerComposeExecOrRun(['bin/rails', 'console'], '/proj')

    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'run', '--rm', 'web', 'bin/rails', 'console'],
      { cwd: '/proj', stdio: 'inherit' },
    )
    expect(logInfoMock).toHaveBeenCalled()
  })

  it('refuses the one-off fallback in a monorepo edge project', async () => {
    routeExeca(false)
    monorepoEdge = true

    await expect(dockerComposeExecOrRun(['bin/rails', 'console'], '/proj')).rejects.toMatchObject({
      code: 1,
    })

    expect(cancelMock).toHaveBeenCalled()
    expect(mockExeca).not.toHaveBeenCalledWith(
      'docker',
      expect.arrayContaining(['run']),
      expect.anything(),
    )
  })

  it('appends the edgeHint to the monorepo-edge refusal message', async () => {
    routeExeca(false)
    monorepoEdge = true

    await expect(
      dockerComposeExecOrRun(['bundle', 'install'], '/proj', {
        edgeHint: 'the edge stack heals gem drift on boot',
      }),
    ).rejects.toMatchObject({ code: 1 })

    const [message] = cancelMock.mock.calls[0] as [string]
    expect(message).toContain('the edge stack heals gem drift on boot')
  })
})

describe('dockerComposeCapture', () => {
  class ExitError extends Error {
    constructor(public code: number) {
      super(`process.exit(${code})`)
    }
  }

  beforeEach(() => {
    monorepoEdge = false
    cancelMock.mockClear()
    logInfoMock.mockClear()
    mockExeca.mockReset()
    vi.spyOn(process, 'exit').mockImplementation((code?: number) => {
      throw new ExitError(code ?? 0)
    })
  })

  afterEach(() => vi.restoreAllMocks())

  it('captures stdout via a non-interactive exec when the service is up', async () => {
    routeExeca(true, 'spree\nspree_core\n')

    await expect(dockerComposeCapture(['bundle', 'list', '--name-only'], '/proj')).resolves.toBe(
      'spree\nspree_core\n',
    )
    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'exec', '-T', 'web', 'bundle', 'list', '--name-only'],
      { cwd: '/proj' },
    )
  })

  it('falls back to a one-off `run --rm -T` container when the service is down', async () => {
    routeExeca(false, 'output')

    await expect(dockerComposeCapture(['bin/rails', 'db:seed'], '/proj')).resolves.toBe('output')
    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'run', '--rm', '-T', 'web', 'bin/rails', 'db:seed'],
      { cwd: '/proj' },
    )
    expect(logInfoMock).toHaveBeenCalled()
  })

  it('threads -e KEY=VALUE pairs before the service', async () => {
    routeExeca(true)

    await dockerComposeCapture(['bin/rails', 'spree:cli:create_admin'], '/proj', {
      env: { EMAIL: 'a@b.c' },
    })

    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'exec', '-T', '-e', 'EMAIL=a@b.c', 'web', 'bin/rails', 'spree:cli:create_admin'],
      { cwd: '/proj' },
    )
  })

  it('refuses the one-off fallback in a monorepo edge project', async () => {
    routeExeca(false)
    monorepoEdge = true

    await expect(dockerComposeCapture(['bin/rails', 'db:seed'], '/proj')).rejects.toMatchObject({
      code: 1,
    })
    expect(cancelMock).toHaveBeenCalled()
  })
})

describe('rakeTask', () => {
  beforeEach(() => {
    monorepoEdge = false
    logInfoMock.mockClear()
    mockExeca.mockReset()
  })

  afterEach(() => vi.restoreAllMocks())

  it('strips Rails boot noise from the captured output', async () => {
    routeExeca(true, '[Spree Events] subscribers loaded\napi_key_abc\n')

    await expect(rakeTask('spree:cli:ensure_api_key', '/proj')).resolves.toBe('api_key_abc')
    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'exec', '-T', 'web', 'bin/rails', 'spree:cli:ensure_api_key'],
      { cwd: '/proj' },
    )
  })

  it('falls back to a one-off container when web is down', async () => {
    routeExeca(false, 'seeded')

    await expect(rakeTask('db:seed', '/proj')).resolves.toBe('seeded')
    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'run', '--rm', '-T', 'web', 'bin/rails', 'db:seed'],
      { cwd: '/proj' },
    )
  })
})
