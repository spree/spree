import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { registerConsoleCommand } from '../src/commands/console'
import { dockerComposeExec, dockerComposeRun, isServiceRunning } from '../src/docker'

let projectDir: string
let monorepoEdge = false

vi.mock('../src/context', () => ({
  detectProject: () => ({ mode: 'docker', projectDir, port: 3000 }),
  hasMonorepoSpreePath: () => monorepoEdge,
}))

vi.mock('../src/docker', () => ({
  dockerComposeExec: vi.fn().mockResolvedValue(undefined),
  dockerComposeRun: vi.fn().mockResolvedValue(undefined),
  isServiceRunning: vi.fn().mockResolvedValue(false),
}))

vi.mock('@clack/prompts', () => ({
  cancel: vi.fn(),
  log: { info: vi.fn() },
}))

class ExitError extends Error {
  constructor(public code: number) {
    super(`process.exit(${code})`)
  }
}

async function runConsole(): Promise<void> {
  const program = new Command()
  registerConsoleCommand(program)
  await program.parseAsync(['console'], { from: 'user' })
}

describe('spree console', () => {
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

  it('execs into the running web container', async () => {
    vi.mocked(isServiceRunning).mockResolvedValue(true)

    await runConsole()

    expect(dockerComposeExec).toHaveBeenCalledWith(['bin/rails', 'console'], '/proj')
    expect(dockerComposeRun).not.toHaveBeenCalled()
  })

  it('falls back to a one-off container when web is down', async () => {
    vi.mocked(isServiceRunning).mockResolvedValue(false)

    await runConsole()

    expect(dockerComposeRun).toHaveBeenCalledWith(['bin/rails', 'console'], '/proj')
    expect(dockerComposeExec).not.toHaveBeenCalled()
  })

  it('refuses the one-off fallback in a monorepo edge project', async () => {
    vi.mocked(isServiceRunning).mockResolvedValue(false)
    monorepoEdge = true

    await expect(runConsole()).rejects.toMatchObject({ code: 1 })

    expect(dockerComposeRun).not.toHaveBeenCalled()
    expect(dockerComposeExec).not.toHaveBeenCalled()
  })
})
