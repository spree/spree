import { Command } from 'commander'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { registerShellCommand } from '../src/commands/shell'
import { dockerComposeExecOrRun } from '../src/docker'

let projectDir: string

vi.mock('../src/context', () => ({
  detectProject: () => ({ mode: 'docker', projectDir, port: 3000 }),
}))

vi.mock('../src/docker', () => ({
  dockerComposeExecOrRun: vi.fn().mockResolvedValue(undefined),
}))

async function runShell(command: string): Promise<void> {
  const program = new Command()
  registerShellCommand(program)
  await program.parseAsync([command], { from: 'user' })
}

describe('spree shell', () => {
  beforeEach(() => {
    projectDir = '/proj'
    vi.clearAllMocks()
  })

  // Branching (exec vs one-off run vs monorepo-edge refusal) is covered by
  // dockerComposeExecOrRun's own tests in docker.test.ts; here we only assert
  // the command delegates with the right argv + edge hint.
  it('delegates to dockerComposeExecOrRun with bash', async () => {
    await runShell('shell')

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(['bash'], '/proj', {
      edgeHint: 'then open the shell',
    })
  })

  it('is also invocable as `spree bash`', async () => {
    await runShell('bash')

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(['bash'], '/proj', {
      edgeHint: 'then open the shell',
    })
  })
})
