import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'

vi.mock('execa', () => ({ execa: vi.fn() }))

import { execa } from 'execa'
import { detectSpreeGems, sdkAdvisory } from '../src/commands/upgrade'

describe('sdkAdvisory', () => {
  const tempDirs: string[] = []

  function makeTempDir(): string {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-upgrade-test-'))
    tempDirs.push(dir)
    return dir
  }

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true })
    }
    tempDirs.length = 0
  })

  function writeStorefrontPackageJson(dir: string, pkg: object): void {
    const storefrontDir = path.join(dir, 'apps', 'storefront')
    fs.mkdirSync(storefrontDir, { recursive: true })
    fs.writeFileSync(path.join(storefrontDir, 'package.json'), JSON.stringify(pkg))
  }

  it('names the declared @spree/sdk version when the storefront uses it', () => {
    const dir = makeTempDir()
    writeStorefrontPackageJson(dir, { dependencies: { '@spree/sdk': '^1.0.3' } })

    expect(sdkAdvisory(dir)).toBe(
      'Update @spree/sdk in apps/storefront (currently ^1.0.3) to the release matching the new Spree version',
    )
  })

  it('finds @spree/sdk in devDependencies too', () => {
    const dir = makeTempDir()
    writeStorefrontPackageJson(dir, { devDependencies: { '@spree/sdk': '1.1.0' } })

    expect(sdkAdvisory(dir)).toContain('currently 1.1.0')
  })

  it('falls back to generic advice without a storefront', () => {
    const dir = makeTempDir()

    expect(sdkAdvisory(dir)).toBe(
      'Update @spree/sdk in any storefront or integration consuming the API',
    )
  })

  it('falls back to generic advice when the storefront does not use the SDK', () => {
    const dir = makeTempDir()
    writeStorefrontPackageJson(dir, { dependencies: { next: '^15.0.0' } })

    expect(sdkAdvisory(dir)).toContain('any storefront or integration')
  })

  it('falls back to generic advice on unparseable package.json', () => {
    const dir = makeTempDir()
    const storefrontDir = path.join(dir, 'apps', 'storefront')
    fs.mkdirSync(storefrontDir, { recursive: true })
    fs.writeFileSync(path.join(storefrontDir, 'package.json'), '{ not json')

    expect(sdkAdvisory(dir)).toContain('any storefront or integration')
  })
})

describe('detectSpreeGems', () => {
  const mockExeca = vi.mocked(execa)
  afterEach(() => mockExeca.mockReset())

  it('parses spree gem names from bundle list output', async () => {
    mockExeca.mockResolvedValue({ stdout: 'spree\nspree_core\nspree_api\nrails\n' } as never)
    await expect(detectSpreeGems('/proj')).resolves.toEqual(['spree', 'spree_core', 'spree_api'])
  })

  it('returns [] when bundle is healthy but resolves no spree gems (grep rc=1, empty stderr)', async () => {
    mockExeca.mockRejectedValue(Object.assign(new Error('x'), { exitCode: 1, stderr: '' }) as never)
    await expect(detectSpreeGems('/proj')).resolves.toEqual([])
  })

  it('throws a bundle-install hint when bundler itself errors (rc=1, real stderr)', async () => {
    mockExeca.mockRejectedValue(
      Object.assign(new Error('x'), {
        exitCode: 1,
        stderr:
          'The git source https://github.com/spree/spree.git is not yet checked out. Please run bundle install',
      }) as never,
    )
    await expect(detectSpreeGems('/proj')).rejects.toThrow(/spree bundle install/)
    await expect(detectSpreeGems('/proj')).rejects.toThrow(/not yet checked out/)
  })

  it('re-throws non-grep failures (stack down, exitCode 255) with the bundle hint', async () => {
    mockExeca.mockRejectedValue(
      Object.assign(new Error('x'), { exitCode: 255, stderr: 'no such service: web' }) as never,
    )
    await expect(detectSpreeGems('/proj')).rejects.toThrow(
      /bundle looks out of sync|no such service/,
    )
  })
})
