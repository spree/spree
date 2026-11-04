import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('../src/lib/run', () => ({ run: vi.fn().mockResolvedValue({ stdout: '' }) }))

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

import {
  captureTask,
  dockerCompose,
  dockerComposeCapture,
  dockerComposeExecOrRun,
  dockerComposeRun,
  prepareDatabase,
  primeBundleVolume,
} from '../src/docker'
import { run } from '../src/lib/run'

const mockRun = vi.mocked(run)

// The exec-or-run helpers make several `run` calls (the `compose ps` probe,
// then `exec`/`run`). Route by args: the probe contains `ps`, everything else
// is the command itself. Lets a single mock drive web-up vs web-down.
function routeRun(webUp: boolean, commandStdout = ''): void {
  mockRun.mockImplementation((async (_cmd: string, args: string[]) => {
    if (args.includes('ps')) return { stdout: webUp ? 'running' : '' }
    return { stdout: commandStdout }
  }) as never)
}

describe('dockerComposeRun', () => {
  afterEach(() => mockRun.mockReset())

  it('builds `compose run --rm <service> <argv>` with inherited stdio', async () => {
    await dockerComposeRun(['bin/rails', 'console'], '/proj')

    expect(mockRun).toHaveBeenCalledWith(
      'docker',
      ['compose', 'run', '--rm', 'web', 'bin/rails', 'console'],
      { cwd: '/proj', stdio: 'inherit' },
    )
  })

  it('honors a non-default service', async () => {
    await dockerComposeRun(['psql'], '/proj', { service: 'postgres' })

    expect(mockRun).toHaveBeenCalledWith('docker', ['compose', 'run', '--rm', 'postgres', 'psql'], {
      cwd: '/proj',
      stdio: 'inherit',
    })
  })

  it('threads -e KEY=VALUE pairs before the service, like dockerComposeExec', async () => {
    await dockerComposeRun(['bin/rake', 'spree:upgrade'], '/proj', {
      env: { DRY_RUN: '1', STEP: 'channels' },
    })

    expect(mockRun).toHaveBeenCalledWith(
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

    const [, args] = mockRun.mock.calls[0] as [string, string[]]
    expect(args).not.toContain('--no-deps')
  })

  it('inherits stdio wholesale by default (no stderr capture)', async () => {
    await dockerComposeRun(['bin/rails', 'console'], '/proj')

    const [, , opts] = mockRun.mock.calls[0] as [string, string[], Record<string, unknown>]
    expect(opts).toMatchObject({ cwd: '/proj', stdio: 'inherit' })
  })

  it('tees stderr to `[pipe, inherit]` when captureStderr is set', async () => {
    // Plain `stdio: inherit` leaves the error's stderr undefined; the tee keeps it
    // printed live AND buffered so db:reset can match the Postgres error.
    await dockerComposeRun(['bin/rails', 'db:drop'], '/proj', { captureStderr: true })

    const [, , opts] = mockRun.mock.calls[0] as [string, string[], Record<string, unknown>]
    expect(opts).toMatchObject({
      cwd: '/proj',
      stdin: 'inherit',
      stdout: 'inherit',
      stderr: ['pipe', 'inherit'],
    })
    expect(opts).not.toHaveProperty('stdio')
  })
})

describe('dockerCompose', () => {
  afterEach(() => mockRun.mockReset())

  it('explains an exhausted Docker network pool and how to free it', async () => {
    const daemonError = new Error(
      'Command failed with exit code 1: docker compose up -d\nError response from daemon: all predefined address pools have been fully subnetted',
    )
    mockRun.mockRejectedValueOnce(daemonError)

    const error = await dockerCompose(['up', '-d'], '/proj').catch((caught: Error) => caught)

    expect(error).toBeInstanceOf(Error)
    expect((error as Error).message).toContain('docker network ls')
    expect((error as Error).cause).toBe(daemonError)
  })

  it('rethrows any other failure unchanged', async () => {
    const daemonError = new Error('Command failed with exit code 1: docker compose up -d')
    mockRun.mockRejectedValueOnce(daemonError)

    await expect(dockerCompose(['up', '-d'], '/proj')).rejects.toBe(daemonError)
  })
})

describe('primeBundleVolume', () => {
  afterEach(() => mockRun.mockReset())

  it('captures stderr while still streaming it to the terminal', async () => {
    await primeBundleVolume('/proj')

    expect(mockRun).toHaveBeenCalledWith('docker', ['compose', 'up', '-d', '--no-deps', 'web'], {
      cwd: '/proj',
      stdin: 'inherit',
      stdout: 'inherit',
      stderr: ['pipe', 'inherit'],
    })
  })

  it('stops on an exhausted Docker network pool so its hint reaches the operator', async () => {
    mockRun.mockRejectedValueOnce(
      new Error(
        'Error response from daemon: all predefined address pools have been fully subnetted',
      ),
    )

    await expect(primeBundleVolume('/proj')).rejects.toThrow('docker network ls')
  })

  it("leaves any other failure to the caller's own `up`", async () => {
    mockRun.mockRejectedValueOnce(new Error('pull access denied'))

    await expect(primeBundleVolume('/proj')).resolves.toBeUndefined()
  })
})

describe('prepareDatabase', () => {
  afterEach(() => mockRun.mockReset())

  it('waits for a healthy postgres, then runs db:prepare in a one-off web container', async () => {
    await prepareDatabase('/proj')

    expect(mockRun).toHaveBeenCalledTimes(2)
    expect(mockRun).toHaveBeenNthCalledWith(
      1,
      'docker',
      ['compose', 'up', '-d', '--wait', 'postgres'],
      {
        cwd: '/proj',
        stdio: 'pipe',
      },
    )
    expect(mockRun).toHaveBeenNthCalledWith(
      2,
      'docker',
      ['compose', 'run', '--rm', '--build', 'web', 'bin/rails', 'db:prepare'],
      { cwd: '/proj', stdio: 'pipe' },
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
    mockRun.mockReset()
    vi.spyOn(process, 'exit').mockImplementation((code?: number) => {
      throw new ExitError(code ?? 0)
    })
  })

  afterEach(() => vi.restoreAllMocks())

  it('execs into the running container when the service is up', async () => {
    routeRun(true)

    await dockerComposeExecOrRun(['bin/rails', 'console'], '/proj')

    expect(mockRun).toHaveBeenCalledWith(
      'docker',
      ['compose', 'exec', 'web', 'bin/rails', 'console'],
      { cwd: '/proj', stdio: 'inherit' },
    )
    expect(mockRun).not.toHaveBeenCalledWith(
      'docker',
      expect.arrayContaining(['run']),
      expect.anything(),
    )
  })

  it('falls back to a one-off `run` container when the service is down', async () => {
    routeRun(false)

    await dockerComposeExecOrRun(['bin/rails', 'console'], '/proj')

    expect(mockRun).toHaveBeenCalledWith(
      'docker',
      ['compose', 'run', '--rm', 'web', 'bin/rails', 'console'],
      { cwd: '/proj', stdio: 'inherit' },
    )
    expect(logInfoMock).toHaveBeenCalled()
  })

  it('refuses the one-off fallback in a monorepo edge project', async () => {
    routeRun(false)
    monorepoEdge = true

    await expect(dockerComposeExecOrRun(['bin/rails', 'console'], '/proj')).rejects.toMatchObject({
      code: 1,
    })

    expect(cancelMock).toHaveBeenCalled()
    expect(mockRun).not.toHaveBeenCalledWith(
      'docker',
      expect.arrayContaining(['run']),
      expect.anything(),
    )
  })

  it('appends the edgeHint to the monorepo-edge refusal message', async () => {
    routeRun(false)
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
    mockRun.mockReset()
    vi.spyOn(process, 'exit').mockImplementation((code?: number) => {
      throw new ExitError(code ?? 0)
    })
  })

  afterEach(() => vi.restoreAllMocks())

  it('captures stdout via a non-interactive exec when the service is up', async () => {
    routeRun(true, 'spree\nspree_core\n')

    await expect(dockerComposeCapture(['bundle', 'list', '--name-only'], '/proj')).resolves.toBe(
      'spree\nspree_core\n',
    )
    expect(mockRun).toHaveBeenCalledWith(
      'docker',
      ['compose', 'exec', '-T', 'web', 'bundle', 'list', '--name-only'],
      { cwd: '/proj' },
    )
  })

  it('falls back to a one-off `run --rm -T` container when the service is down', async () => {
    routeRun(false, 'output')

    await expect(dockerComposeCapture(['bin/rails', 'db:seed'], '/proj')).resolves.toBe('output')
    expect(mockRun).toHaveBeenCalledWith(
      'docker',
      ['compose', 'run', '--rm', '-T', 'web', 'bin/rails', 'db:seed'],
      { cwd: '/proj' },
    )
    expect(logInfoMock).toHaveBeenCalled()
  })

  it('threads -e KEY=VALUE pairs before the service', async () => {
    routeRun(true)

    await dockerComposeCapture(['bin/rails', 'spree:cli:create_admin'], '/proj', {
      env: { EMAIL: 'a@b.c' },
    })

    expect(mockRun).toHaveBeenCalledWith(
      'docker',
      ['compose', 'exec', '-T', '-e', 'EMAIL=a@b.c', 'web', 'bin/rails', 'spree:cli:create_admin'],
      { cwd: '/proj' },
    )
  })

  it('refuses the one-off fallback in a monorepo edge project', async () => {
    routeRun(false)
    monorepoEdge = true

    await expect(dockerComposeCapture(['bin/rails', 'db:seed'], '/proj')).rejects.toMatchObject({
      code: 1,
    })
    expect(cancelMock).toHaveBeenCalled()
  })
})

describe('captureTask', () => {
  beforeEach(() => {
    monorepoEdge = false
    logInfoMock.mockClear()
    mockRun.mockReset()
  })

  afterEach(() => vi.restoreAllMocks())

  it('strips backend boot noise from the captured output', async () => {
    routeRun(true, '[Spree Events] subscribers loaded\napi_key_abc\n')

    await expect(captureTask('spree:cli:ensure_api_key', '/proj')).resolves.toBe('api_key_abc')
    expect(mockRun).toHaveBeenCalledWith(
      'docker',
      ['compose', 'exec', '-T', 'web', 'bin/rails', 'spree:cli:ensure_api_key'],
      { cwd: '/proj' },
    )
  })

  it('falls back to a one-off container when web is down', async () => {
    routeRun(false, 'seeded')

    await expect(captureTask('db:seed', '/proj')).resolves.toBe('seeded')
    expect(mockRun).toHaveBeenCalledWith(
      'docker',
      ['compose', 'run', '--rm', '-T', 'web', 'bin/rails', 'db:seed'],
      { cwd: '/proj' },
    )
  })
})
