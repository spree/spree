import { Command } from 'commander'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { registerRspecCommand } from '../src/commands/rspec'
import { dockerComposeExecOrRun } from '../src/docker'

let projectDir: string

vi.mock('../src/context', () => ({
  detectProject: () => ({ mode: 'docker', projectDir, port: 3000 }),
}))

vi.mock('../src/docker', () => ({
  dockerComposeExecOrRun: vi.fn().mockResolvedValue(undefined),
}))

async function runRspec(args: string[] = []): Promise<void> {
  const program = new Command().enablePositionalOptions()
  registerRspecCommand(program)
  await program.parseAsync(['rspec', ...args], { from: 'user' })
}

describe('spree rspec', () => {
  beforeEach(() => {
    projectDir = '/proj'
    vi.clearAllMocks()
  })

  // Branching (exec vs one-off run vs monorepo-edge refusal) is covered by
  // dockerComposeExecOrRun's own tests in docker.test.ts; here we assert the
  // delegation shape: `bundle exec rspec` + forwarded args + RAILS_ENV=test.
  it('runs the full suite with RAILS_ENV=test when called bare', async () => {
    await runRspec()

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(['bundle', 'exec', 'rspec'], '/proj', {
      env: { RAILS_ENV: 'test' },
      edgeHint: 'then re-run spree rspec',
    })
  })

  it('forwards file paths and line numbers', async () => {
    await runRspec(['spec/models/spree/brand_spec.rb:15'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bundle', 'exec', 'rspec', 'spec/models/spree/brand_spec.rb:15'],
      '/proj',
      expect.objectContaining({ env: { RAILS_ENV: 'test' } }),
    )
  })

  // Leading flags have no preceding positional, so they rely on
  // allowUnknownOption (passThroughOptions alone only covers flags after one).
  it('forwards leading rspec flags instead of parsing them', async () => {
    await runRspec(['--format', 'documentation'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bundle', 'exec', 'rspec', '--format', 'documentation'],
      '/proj',
      expect.objectContaining({ env: { RAILS_ENV: 'test' } }),
    )
  })

  it('forwards flags following a path untouched', async () => {
    await runRspec(['spec/features/', '--fail-fast'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bundle', 'exec', 'rspec', 'spec/features/', '--fail-fast'],
      '/proj',
      expect.objectContaining({ env: { RAILS_ENV: 'test' } }),
    )
  })
})
