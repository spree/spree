import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { registerMigrateCommand } from '../src/commands/migrate'
import { dockerComposeExecOrRun } from '../src/docker'

let projectDir: string

vi.mock('../src/context', () => ({
  detectProject: () => ({ mode: 'docker', projectDir, port: 3000 }),
}))

vi.mock('../src/docker', () => ({
  dockerComposeExecOrRun: vi.fn().mockResolvedValue(undefined),
}))

vi.mock('@clack/prompts', () => ({ note: vi.fn() }))

async function runMigrate(argv: string[]): Promise<void> {
  // The real root program enables positional options (src/index.ts), which
  // commander requires for subcommands using passThroughOptions.
  const program = new Command().enablePositionalOptions().exitOverride()
  registerMigrateCommand(program)
  await program.parseAsync(argv, { from: 'user' })
}

// Branching (exec vs one-off run vs monorepo-edge refusal) is covered by
// dockerComposeExecOrRun's own tests in docker.test.ts; here we only assert
// the commands delegate with the right argv.
describe('spree migrate', () => {
  let stderr: ReturnType<typeof vi.spyOn>

  beforeEach(() => {
    projectDir = '/proj'
    vi.clearAllMocks()
    vi.spyOn(console, 'log').mockImplementation(() => {})
    stderr = vi.spyOn(console, 'error').mockImplementation(() => {})
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('installs and runs pending migrations in one invocation', async () => {
    await runMigrate(['migrate'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'spree:install:migrations', 'db:migrate'],
      '/proj',
      { edgeHint: expect.any(String) },
    )
    expect(stderr).not.toHaveBeenCalled()
  })

  it('still forwards raw migrate args, with a deprecation notice', async () => {
    await runMigrate(['migrate', 'VERSION=20260101000000'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'spree:install:migrations', 'db:migrate', 'VERSION=20260101000000'],
      '/proj',
      { edgeHint: expect.any(String) },
    )
    expect(stderr).toHaveBeenCalledWith(expect.stringContaining('deprecated'))
  })

  it('migrate:rollback --steps rolls back n migrations', async () => {
    await runMigrate(['migrate:rollback', '--steps', '2'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'db:rollback', 'STEP=2'],
      '/proj',
    )
    expect(stderr).not.toHaveBeenCalled()
  })

  it('migrate:rollback STEP=n still works and points at --steps', async () => {
    await runMigrate(['migrate:rollback', 'STEP=2'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'db:rollback', 'STEP=2'],
      '/proj',
    )
    expect(stderr).toHaveBeenCalledWith(expect.stringContaining('--steps 2'))
  })

  it('migrate:rollback rejects a non-positive --steps', async () => {
    await expect(runMigrate(['migrate:rollback', '--steps', '0'])).rejects.toThrow(
      /positive whole number/,
    )
    expect(dockerComposeExecOrRun).not.toHaveBeenCalled()
  })

  it('migrate:status delegates', async () => {
    await runMigrate(['migrate:status'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(['bin/rails', 'db:migrate:status'], '/proj')
  })
})
