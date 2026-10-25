import { describe, expect, it, vi } from 'vitest'

vi.mock('@clack/prompts', () => ({
  text: vi.fn(),
  confirm: vi.fn(),
  cancel: vi.fn(),
  isCancel: () => false,
}))

import { runPrompts } from '../src/prompts'

// Flags cover every question, so runPrompts returns without touching @clack.
const ANSWERED = {
  directory: './my-store',
  noStorefront: true,
  noSellerDashboard: false,
  noAgentSkills: false,
  noDocsMcp: false,
  noStart: true,
  packageManager: 'pnpm',
} as const

describe('runPrompts', () => {
  it('includes the dashboard without asking, unless --no-dashboard is passed', async () => {
    const { confirm } = await import('@clack/prompts')

    expect((await runPrompts({ ...ANSWERED })).dashboard).toBe(true)
    expect((await runPrompts({ ...ANSWERED, noDashboard: true })).dashboard).toBe(false)

    expect(vi.mocked(confirm)).not.toHaveBeenCalled()
  })

  it('asks about the seller panel, defaulting to yes', async () => {
    const { confirm } = await import('@clack/prompts')
    vi.mocked(confirm).mockResolvedValueOnce(false)

    const options = await runPrompts({ ...ANSWERED, noSellerDashboard: undefined })

    expect(options.sellerDashboard).toBe(false)
    expect(vi.mocked(confirm)).toHaveBeenCalledWith(
      expect.objectContaining({
        message: expect.stringContaining('Include Seller Panel?'),
        initialValue: true,
      }),
    )
  })

  it('asks one question about the agent skills and docs MCP server, defaulting to yes', async () => {
    const { confirm } = await import('@clack/prompts')
    vi.mocked(confirm).mockClear()
    vi.mocked(confirm).mockResolvedValueOnce(true)

    const options = await runPrompts({
      ...ANSWERED,
      noAgentSkills: undefined,
      noDocsMcp: undefined,
    })

    expect(options.agentSkills).toBe(true)
    expect(options.docsMcp).toBe(true)
    expect(vi.mocked(confirm)).toHaveBeenCalledTimes(1)
    expect(vi.mocked(confirm)).toHaveBeenCalledWith(
      expect.objectContaining({
        message: expect.stringContaining('Set up AI coding agents?'),
        initialValue: true,
      }),
    )
  })

  // Scripted runs (CI) pass only the flag they care about and cannot answer.
  it('does not ask when either agent flag is passed, defaulting the other half to yes', async () => {
    const { confirm } = await import('@clack/prompts')
    vi.mocked(confirm).mockClear()

    const options = await runPrompts({ ...ANSWERED, noAgentSkills: true, noDocsMcp: undefined })

    expect(options.agentSkills).toBe(false)
    expect(options.docsMcp).toBe(true)
    expect(vi.mocked(confirm)).not.toHaveBeenCalled()
  })

  // Sample data is loaded on demand with `spree sample-data`, never as part of
  // the scaffold: the seed runs before the store is configured through the
  // first-run setup UI.
  it('never asks about sample data', async () => {
    const options = await runPrompts({ ...ANSWERED })

    expect(options).not.toHaveProperty('sampleData')
  })
})
