import { afterEach, describe, expect, it, vi } from 'vitest'

vi.mock('execa', () => ({ execa: vi.fn().mockResolvedValue({ stdout: '' }) }))

import { execa } from 'execa'
import { dockerComposeRun } from '../src/docker'

describe('dockerComposeRun', () => {
  const mockExeca = vi.mocked(execa)
  afterEach(() => mockExeca.mockReset())

  it('builds `compose run --rm <service> <argv>` with inherited stdio', async () => {
    await dockerComposeRun(['bin/rails', 'console'], '/proj')

    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'run', '--rm', 'web', 'bin/rails', 'console'],
      { cwd: '/proj', stdio: 'inherit' },
    )
  })

  it('honors a non-default service', async () => {
    await dockerComposeRun(['psql'], '/proj', { service: 'postgres' })

    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      ['compose', 'run', '--rm', 'postgres', 'psql'],
      { cwd: '/proj', stdio: 'inherit' },
    )
  })

  it('threads -e KEY=VALUE pairs before the service, like dockerComposeExec', async () => {
    await dockerComposeRun(['bin/rake', 'spree:upgrade'], '/proj', {
      env: { DRY_RUN: '1', STEP: 'channels' },
    })

    expect(mockExeca).toHaveBeenCalledWith(
      'docker',
      [
        'compose',
        'run',
        '--rm',
        '-e',
        'DRY_RUN=1',
        '-e',
        'STEP=channels',
        'web',
        'bin/rake',
        'spree:upgrade',
      ],
      { cwd: '/proj', stdio: 'inherit' },
    )
  })

  it('does not pass --no-deps (deps must start + health-wait)', async () => {
    await dockerComposeRun(['bin/rails', 'db:drop'], '/proj')

    const [, args] = mockExeca.mock.calls[0] as [string, string[]]
    expect(args).not.toContain('--no-deps')
  })
})
