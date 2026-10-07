import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'

vi.mock('execa', () => ({ execa: vi.fn() }))

import { execa } from 'execa'
import {
  detectSpreeGems,
  detectSpreePackages,
  packageUpdateArgs,
  sdkAdvisory,
} from '../src/commands/upgrade'

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

  // detectSpreeGems goes through dockerComposeCapture, which probes the web
  // container first (`compose ps`) — route the probe to "running" so the
  // command call itself drives each scenario.
  function routeBundleList(command: () => Promise<{ stdout: string }>): void {
    mockExeca.mockImplementation((async (_cmd: string, args: string[]) => {
      if (args.includes('ps')) return { stdout: 'running' }
      return command()
    }) as never)
  }

  it('parses spree gem names from bundle list output', async () => {
    routeBundleList(async () => ({ stdout: 'spree\nspree_core\nspree_api\nrails\n' }))
    await expect(detectSpreeGems('/proj')).resolves.toEqual(['spree', 'spree_core', 'spree_api'])
  })

  it('returns [] when bundle is healthy but resolves no spree gems', async () => {
    routeBundleList(async () => ({ stdout: 'rails\npg\n' }))
    await expect(detectSpreeGems('/proj')).resolves.toEqual([])
  })

  it('throws a bundle-install hint when bundler itself errors', async () => {
    routeBundleList(async () => {
      throw Object.assign(new Error('x'), {
        exitCode: 1,
        stderr:
          'The git source https://github.com/spree/spree.git is not yet checked out. Please run bundle install',
      })
    })
    await expect(detectSpreeGems('/proj')).rejects.toThrow(/spree bundle install/)
    await expect(detectSpreeGems('/proj')).rejects.toThrow(/not yet checked out/)
  })

  it('wraps daemon-level failures (exitCode 255) with the bundle hint', async () => {
    routeBundleList(async () => {
      throw Object.assign(new Error('x'), { exitCode: 255, stderr: 'no such service: web' })
    })
    await expect(detectSpreeGems('/proj')).rejects.toThrow(
      /bundle looks out of sync|no such service/,
    )
  })
})

describe('detectSpreePackages', () => {
  const dirs: string[] = []
  afterEach(() => {
    for (const dir of dirs) fs.rmSync(dir, { recursive: true, force: true })
    dirs.length = 0
  })

  function withPackageJson(pkg: object | string): string {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-packages-test-'))
    dirs.push(dir)
    fs.writeFileSync(
      path.join(dir, 'package.json'),
      typeof pkg === 'string' ? pkg : JSON.stringify(pkg),
    )
    return dir
  }

  it('lists registry-resolved @spree/* packages from both dependency groups', () => {
    const dir = withPackageJson({
      dependencies: { '@spree/dashboard': '^1.0.0-beta.8', react: '^19.2.6' },
      devDependencies: { '@spree/cli': '~3.1.0', '@spree/docs': 'latest' },
    })
    expect(detectSpreePackages(dir)).toEqual(['@spree/dashboard', '@spree/cli', '@spree/docs'])
  })

  it('leaves local and git specs alone', () => {
    const dir = withPackageJson({
      dependencies: {
        '@spree/dashboard': 'workspace:^',
        '@spree/dashboard-core': 'file:../dashboard-core',
        '@spree/admin-sdk': 'github:spree/spree#main',
      },
    })
    expect(detectSpreePackages(dir)).toEqual([])
  })

  it('returns [] without a readable package.json', () => {
    expect(detectSpreePackages(withPackageJson('{ not json'))).toEqual([])
    expect(detectSpreePackages('/nonexistent')).toEqual([])
  })
})

describe('packageUpdateArgs', () => {
  it('uses update for pnpm and npm', () => {
    expect(packageUpdateArgs('pnpm', ['@spree/cli'], '/proj', '/proj')).toEqual([
      'update',
      '@spree/cli',
    ])
    expect(packageUpdateArgs('npm', ['@spree/cli'], '/proj', '/proj')).toEqual([
      'update',
      '@spree/cli',
    ])
  })

  it('keeps declared ranges on Yarn Classic and Yarn Berry', () => {
    const projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-yarn-test-'))
    const appDir = path.join(projectDir, 'apps', 'dashboard')
    fs.mkdirSync(appDir, { recursive: true })
    try {
      expect(packageUpdateArgs('yarn', ['@spree/dashboard'], projectDir, appDir)).toEqual([
        'upgrade',
        '@spree/dashboard',
      ])
      fs.writeFileSync(path.join(projectDir, '.yarnrc.yml'), 'nodeLinker: node-modules\n')
      expect(packageUpdateArgs('yarn', ['@spree/dashboard'], projectDir, appDir)).toEqual([
        'up',
        '-R',
        '@spree/dashboard',
      ])
    } finally {
      fs.rmSync(projectDir, { recursive: true, force: true })
    }
  })
})
