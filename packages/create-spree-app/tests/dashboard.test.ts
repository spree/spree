import { beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('execa', () => ({ execa: vi.fn() }))

import { execa } from 'execa'
import { scaffoldDashboard } from '../src/dashboard'

// Both admin SPAs ship in every project: from Spree 6 the Dashboard IS the
// admin, and the starter's Dockerfile bakes whichever of the two it finds
// under apps/. A scaffold that silently produced only one would leave either
// no back office or no seller panel in the built image.
describe('scaffoldDashboard', () => {
  beforeEach(() => vi.mocked(execa).mockClear())

  function componentsScaffoldedInto(projectDir: string): string[] {
    return vi
      .mocked(execa)
      .mock.calls.filter(([, args]) => (args as string[])?.[0] === 'spree')
      .filter(([, , opts]) => (opts as { cwd?: string })?.cwd === projectDir)
      .map(([, args]) => (args as string[])[2])
  }

  it('scaffolds both the dashboard and the seller panel', async () => {
    await scaffoldDashboard('/tmp/project', { install: true, packageManager: 'pnpm' })

    expect(componentsScaffoldedInto('/tmp/project')).toEqual(['dashboard', 'seller-dashboard'])
  })

  it('runs each through the project-local CLI, quietly', async () => {
    await scaffoldDashboard('/tmp/project', { install: true, packageManager: 'npm' })

    // npm reaches the local CLI through npx; --quiet suppresses the command's
    // own summary because the scaffold prints its own.
    for (const [cmd, args, opts] of vi.mocked(execa).mock.calls) {
      expect(cmd).toBe('npx')
      expect(args).toContain('--quiet')
      expect((opts as { cwd?: string }).cwd).toBe('/tmp/project')
    }
  })

  it('passes --no-install through to both apps when installing is skipped', async () => {
    await scaffoldDashboard('/tmp/project', { install: false, packageManager: 'pnpm' })

    const calls = vi.mocked(execa).mock.calls
    expect(calls).toHaveLength(2)
    for (const [, args] of calls) {
      expect(args).toContain('--no-install')
    }
  })

  it('stops at the first failure rather than leaving a half-scaffolded pair', async () => {
    vi.mocked(execa).mockRejectedValueOnce(new Error('spree add dashboard failed'))

    await expect(
      scaffoldDashboard('/tmp/project', { install: true, packageManager: 'pnpm' }),
    ).rejects.toThrow('spree add dashboard failed')

    expect(componentsScaffoldedInto('/tmp/project')).toEqual(['dashboard'])
  })
})
