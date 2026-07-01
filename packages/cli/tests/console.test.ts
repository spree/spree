import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { registerConsoleCommand } from '../src/commands/console'
import { dockerComposeExecOrRun } from '../src/docker'

let projectDir: string

vi.mock('../src/context', () => ({
  detectProject: () => ({ mode: 'docker', projectDir, port: 3000 }),
}))

vi.mock('../src/docker', () => ({
  dockerComposeExecOrRun: vi.fn().mockResolvedValue(undefined),
}))

async function runConsole(): Promise<void> {
  const program = new Command()
  registerConsoleCommand(program)
  await program.parseAsync(['console'], { from: 'user' })
}

describe('spree console', () => {
  beforeEach(() => {
    projectDir = '/proj'
    vi.clearAllMocks()
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  // Branching (exec vs one-off run vs monorepo-edge refusal) is covered by
  // dockerComposeExecOrRun's own tests in docker.test.ts; here we only assert
  // the command delegates with the right argv + edge hint.
  it('delegates to dockerComposeExecOrRun with the console command', async () => {
    await runConsole()

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(['bin/rails', 'console'], '/proj', {
      edgeHint: 'then open the console',
    })
  })
})
