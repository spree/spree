import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { registerDbCommand } from '../src/commands/db'
import { dockerCompose, dockerComposeExec, dockerComposeRun, isServiceRunning } from '../src/docker'

let projectDir: string
let monorepoEdge = false

vi.mock('../src/context', () => ({
  detectProject: () => ({ mode: 'docker', projectDir, port: 3000 }),
  hasMonorepoSpreePath: () => monorepoEdge,
}))

vi.mock('../src/docker', () => ({
  dockerCompose: vi.fn().mockResolvedValue(undefined),
  dockerComposeExec: vi.fn().mockResolvedValue(undefined),
  dockerComposeRun: vi.fn().mockResolvedValue(undefined),
  isServiceRunning: vi.fn().mockResolvedValue(false),
}))

// p.confirm/p.spinner/p.cancel are not exercised here beyond not crashing; the
// default --yes path skips the prompt. Stub the interactive surface so the
// non-yes test can drive confirm.
const confirmMock = vi.fn()
vi.mock('@clack/prompts', () => ({
  confirm: (...args: unknown[]) => confirmMock(...args),
  isCancel: (v: unknown) => v === CANCEL,
  cancel: vi.fn(),
  log: { success: vi.fn(), info: vi.fn() },
  note: vi.fn(),
  spinner: () => ({ start: vi.fn(), stop: vi.fn() }),
}))

const CANCEL = Symbol('cancel')

class ExitError extends Error {
  constructor(public code: number) {
    super(`process.exit(${code})`)
  }
}

const RESET_TASK = [
  'bin/rails',
  'db:drop',
  'db:create',
  'spree:install:migrations',
  'db:migrate',
  'db:seed',
]

async function runDbReset(...argv: string[]): Promise<void> {
  const program = new Command()
  registerDbCommand(program)
  await program.parseAsync(['db:reset', ...argv], { from: 'user' })
}

async function runDbConsole(): Promise<void> {
  const program = new Command()
  registerDbCommand(program)
  await program.parseAsync(['db:console'], { from: 'user' })
}

describe('spree db:reset', () => {
  beforeEach(() => {
    projectDir = '/proj'
    monorepoEdge = false
    vi.clearAllMocks()
    vi.mocked(isServiceRunning).mockResolvedValue(false)
    vi.spyOn(process, 'exit').mockImplementation((code?: number) => {
      throw new ExitError(code ?? 0)
    })
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('runs the reset chain in a one-off container when the stack is fully down', async () => {
    vi.mocked(isServiceRunning).mockResolvedValue(false)

    await runDbReset('--yes')

    expect(dockerComposeRun).toHaveBeenCalledWith(RESET_TASK, '/proj')
    // Nothing to stop when the stack is already down.
    expect(dockerCompose).not.toHaveBeenCalled()
  })

  it('stops web + worker before the reset when the stack is up', async () => {
    vi.mocked(isServiceRunning).mockResolvedValue(true)

    await runDbReset('--yes')

    expect(dockerCompose).toHaveBeenCalledWith(['stop', 'web', 'worker'], '/proj')
    expect(dockerComposeRun).toHaveBeenCalledWith(RESET_TASK, '/proj')
    // stop must precede the destructive run.
    const stopOrder = vi.mocked(dockerCompose).mock.invocationCallOrder[0]
    const runOrder = vi.mocked(dockerComposeRun).mock.invocationCallOrder[0]
    expect(stopOrder).toBeLessThan(runOrder)
  })

  it('stops both even when only the worker is running', async () => {
    vi.mocked(isServiceRunning).mockImplementation(async (service: string) => service === 'worker')

    await runDbReset('--yes')

    expect(dockerCompose).toHaveBeenCalledWith(['stop', 'web', 'worker'], '/proj')
    expect(dockerComposeRun).toHaveBeenCalledWith(RESET_TASK, '/proj')
  })

  it('refuses in a monorepo edge project before touching the stack', async () => {
    monorepoEdge = true

    await expect(runDbReset('--yes')).rejects.toBeInstanceOf(ExitError)

    expect(isServiceRunning).not.toHaveBeenCalled()
    expect(dockerCompose).not.toHaveBeenCalled()
    expect(dockerComposeRun).not.toHaveBeenCalled()
  })

  it('refuses with a friendly message when `compose ps` itself fails', async () => {
    vi.mocked(isServiceRunning).mockRejectedValue(new Error('Cannot connect to the Docker daemon'))

    await expect(runDbReset('--yes')).rejects.toMatchObject({ code: 1 })

    expect(dockerCompose).not.toHaveBeenCalled()
    expect(dockerComposeRun).not.toHaveBeenCalled()
  })

  it('cancels without running anything when the operator declines the prompt', async () => {
    confirmMock.mockResolvedValue(false)

    await expect(runDbReset()).rejects.toMatchObject({ code: 0 })

    expect(dockerComposeRun).not.toHaveBeenCalled()
  })

  it('surfaces a host-client hint when the drop fails on an active connection', async () => {
    vi.mocked(isServiceRunning).mockResolvedValue(false)
    vi.mocked(dockerComposeRun).mockRejectedValue(
      Object.assign(new Error('rails aborted'), {
        stderr: 'ERROR:  database "spree_development" is being accessed by other users',
      }),
    )

    // The 55006 branch refuses with exit(1) rather than re-throwing the raw error.
    await expect(runDbReset('--yes')).rejects.toMatchObject({ code: 1 })
  })

  it('re-throws a non-connection failure from the reset chain', async () => {
    vi.mocked(isServiceRunning).mockResolvedValue(false)
    vi.mocked(dockerComposeRun).mockRejectedValue(new Error('boom: migration failed'))

    await expect(runDbReset('--yes')).rejects.toThrow(/migration failed/)
  })
})

describe('spree db:console', () => {
  beforeEach(() => {
    projectDir = '/proj'
    monorepoEdge = false
    vi.clearAllMocks()
    vi.mocked(isServiceRunning).mockResolvedValue(true)
    vi.spyOn(process, 'exit').mockImplementation((code?: number) => {
      throw new ExitError(code ?? 0)
    })
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('opens psql against the postgres service when it is running', async () => {
    vi.mocked(isServiceRunning).mockResolvedValue(true)

    await runDbConsole()

    expect(dockerComposeExec).toHaveBeenCalledWith(
      ['psql', '-U', 'postgres', 'spree_development'],
      '/proj',
      { service: 'postgres' },
    )
  })

  it('refuses with a start-the-stack hint when postgres is down', async () => {
    vi.mocked(isServiceRunning).mockResolvedValue(false)

    await expect(runDbConsole()).rejects.toMatchObject({ code: 1 })

    expect(dockerComposeExec).not.toHaveBeenCalled()
  })
})
