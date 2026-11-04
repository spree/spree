import { beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('../src/run', () => ({ run: vi.fn() }))

import { scaffoldApp } from '../src/dashboard'
import { run } from '../src/run'

describe('scaffoldApp', () => {
  beforeEach(() => vi.mocked(run).mockClear())

  it('runs `spree add <app>` through the project-local CLI, quietly', async () => {
    await scaffoldApp('/tmp/project', 'seller-dashboard', { install: true, packageManager: 'npm' })

    // npm reaches the local CLI through npx; --quiet suppresses the command's
    // own summary because the scaffold prints its own.
    expect(vi.mocked(run)).toHaveBeenCalledWith(
      'npx',
      ['spree', 'add', 'seller-dashboard', '--quiet'],
      expect.objectContaining({ cwd: '/tmp/project' }),
    )
  })

  it('passes --no-install through when installing is skipped', async () => {
    await scaffoldApp('/tmp/project', 'dashboard', { install: false, packageManager: 'pnpm' })

    expect(vi.mocked(run).mock.calls[0][1]).toContain('--no-install')
  })
})
