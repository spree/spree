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
  noStart: true,
  packageManager: 'pnpm',
} as const

describe('runPrompts', () => {
  // From Spree 6 the React Dashboard IS the admin — the Rails admin engine is
  // gone — so a scaffold without one has no back office. It is therefore not
  // a question, and `--react-dashboard` is a no-op rather than a gate.
  it('always includes the admin apps, with no prompt and regardless of flags', async () => {
    const { confirm } = await import('@clack/prompts')

    expect((await runPrompts({ ...ANSWERED })).dashboard).toBe(true)
    expect((await runPrompts({ ...ANSWERED, reactDashboard: false })).dashboard).toBe(true)
    expect((await runPrompts({ ...ANSWERED, reactDashboard: true })).dashboard).toBe(true)

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
