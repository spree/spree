import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { registerDevCommand } from '../src/commands/dev'
import { dockerCompose } from '../src/docker'
import { cancelOnPortConflict } from '../src/ports'
import { mockProcessExit } from './helpers/process-exit'

let projectDir: string

vi.mock('../src/context', () => ({
  detectProject: () => ({ mode: 'project', projectDir, port: 3000 }),
  hasMonorepoSpreePath: () => false,
  isEjectedProject: () => false,
}))

vi.mock('../src/docker', () => ({
  dockerCompose: vi.fn(),
  primeBundleVolume: vi.fn().mockResolvedValue(undefined),
  buildAdminStylesheets: vi.fn().mockResolvedValue(undefined),
  watchAdminStylesheets: vi.fn().mockResolvedValue(undefined),
}))

vi.mock('../src/ports', () => ({ cancelOnPortConflict: vi.fn() }))

const cancelMock = vi.fn()
const outroMock = vi.fn()
vi.mock('@clack/prompts', () => ({
  note: vi.fn(),
  log: { info: vi.fn() },
  cancel: (...args: unknown[]) => cancelMock(...args),
  outro: (...args: unknown[]) => outroMock(...args),
}))

async function runDev(): Promise<void> {
  const program = new Command()
  registerDevCommand(program)
  await program.parseAsync(['dev'], { from: 'user' })
}

describe('spree dev — compose failure handling', () => {
  let exit: ReturnType<typeof mockProcessExit>

  beforeEach(() => {
    projectDir = '/proj'
    vi.clearAllMocks()
    exit = mockProcessExit()
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('shows the port-conflict diagnosis instead of the generic error', async () => {
    vi.mocked(dockerCompose).mockResolvedValue({ exitCode: 1 } as never)
    vi.mocked(cancelOnPortConflict).mockResolvedValue(true)

    await expect(runDev()).rejects.toMatchObject({ code: 1 })
    expect(cancelOnPortConflict).toHaveBeenCalledWith(projectDir)
    // The generic fallback must not fire when a conflict was diagnosed.
    expect(cancelMock).not.toHaveBeenCalled()
  })

  it('falls back to the generic error when no conflict is found', async () => {
    vi.mocked(dockerCompose).mockResolvedValue({ exitCode: 1 } as never)
    vi.mocked(cancelOnPortConflict).mockResolvedValue(false)

    await expect(runDev()).rejects.toMatchObject({ code: 1 })
    expect(cancelMock).toHaveBeenCalledWith(expect.stringContaining('exited with code 1'))
  })

  it('treats a Ctrl+C shutdown (130) as clean, not a conflict', async () => {
    vi.mocked(dockerCompose).mockResolvedValue({ exitCode: 130 } as never)

    await runDev()

    expect(exit).not.toHaveBeenCalled()
    expect(cancelOnPortConflict).not.toHaveBeenCalled()
    expect(outroMock).toHaveBeenCalled()
  })
})
