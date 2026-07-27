import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { registerMigrateCommand } from '../src/commands/migrate'
import { dockerComposeExec, dockerComposeExecOrRun, isServiceRunning } from '../src/docker'

let projectDir: string

vi.mock('../src/context', () => ({
  detectProject: () => ({ mode: 'docker', projectDir, port: 3000 }),
}))

vi.mock('../src/docker', () => ({
  dockerComposeExec: vi.fn().mockResolvedValue(undefined),
  dockerComposeExecOrRun: vi.fn().mockResolvedValue(undefined),
  isServiceRunning: vi.fn().mockResolvedValue(true),
}))

vi.mock('@clack/prompts', () => ({ note: vi.fn() }))

async function runMigrate(argv: string[]): Promise<void> {
  // The real root program enables positional options (src/index.ts), which
  // commander requires for subcommands using passThroughOptions.
  const program = new Command().enablePositionalOptions()
  registerMigrateCommand(program)
  await program.parseAsync(argv, { from: 'user' })
}

describe('spree migrate', () => {
  beforeEach(() => {
    projectDir = '/proj'
    vi.clearAllMocks()
    vi.mocked(isServiceRunning).mockResolvedValue(true)
    vi.spyOn(console, 'log').mockImplementation(() => {})
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('runs install + migrate as separate steps when web is up', async () => {
    await runMigrate(['migrate', 'VERSION=20260101000000'])

    expect(dockerComposeExec).toHaveBeenNthCalledWith(
      1,
      ['bin/rails', 'spree:install:migrations'],
      '/proj',
    )
    expect(dockerComposeExec).toHaveBeenNthCalledWith(
      2,
      ['bin/rails', 'db:migrate', 'VERSION=20260101000000'],
      '/proj',
    )
    expect(dockerComposeExecOrRun).not.toHaveBeenCalled()
  })

  it('collapses both steps into one one-off invocation when web is down', async () => {
    vi.mocked(isServiceRunning).mockResolvedValue(false)

    await runMigrate(['migrate', 'VERSION=20260101000000'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'spree:install:migrations', 'db:migrate', 'VERSION=20260101000000'],
      '/proj',
      { edgeHint: expect.any(String) },
    )
    expect(dockerComposeExec).not.toHaveBeenCalled()
  })

  // Branching (exec vs one-off run vs monorepo-edge refusal) for the
  // subcommands below is covered by dockerComposeExecOrRun's own tests in
  // docker.test.ts; here we only assert they delegate with the right argv.
  it('migrate:rollback delegates with forwarded args', async () => {
    await runMigrate(['migrate:rollback', 'STEP=2'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'db:rollback', 'STEP=2'],
      '/proj',
    )
  })

  it('migrate:status delegates', async () => {
    await runMigrate(['migrate:status'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(['bin/rails', 'db:migrate:status'], '/proj')
  })
})
