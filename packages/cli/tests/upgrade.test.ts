import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('execa', () => ({ execa: vi.fn() }))

const LINE = vi.hoisted(() => ({
  packages: [
    '@spree/sdk',
    '@spree/admin-sdk',
    '@spree/dashboard',
    '@spree/dashboard-core',
    '@spree/dashboard-ui',
  ],
  version: '6.0.0-rc.7',
}))

vi.mock('../src/lib/release-line', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/lib/release-line')>()),
  RELEASE_LINE: LINE,
}))

let projectDir: string

vi.mock('../src/context', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/context')>()),
  detectProject: () => ({ mode: 'docker', projectDir, port: 3000 }),
}))

vi.mock('../src/commands/add', () => ({
  APP_DIRS: ['dashboard'],
  detectPackageManager: () => 'pnpm',
  generateRouteTree: vi.fn(),
}))

vi.mock('@clack/prompts', () => ({
  log: { step: vi.fn(), info: vi.fn(), warn: vi.fn() },
  note: vi.fn(),
  confirm: vi.fn(),
  isCancel: () => false,
  cancel: vi.fn(),
}))

import * as p from '@clack/prompts'
import * as prompts from '@clack/prompts'
import { execa } from 'execa'
import {
  alignPeerRanges,
  detectSpreeGems,
  detectSpreePackages,
  isExactVersion,
  isOlderVersion,
  moveToReleaseLine,
  packageAddArgs,
  packageDedupeArgs,
  packageUpdateArgs,
  registerUpgradeCommand,
  sdkAdvisory,
  spreePeerRanges,
} from '../src/commands/upgrade'
import { npmVersionOf, releaseLineFor } from '../src/lib/release-line'

describe('npmVersionOf', () => {
  it('spells gem versions the way the packages are published', () => {
    expect(npmVersionOf('6.0.0.rc7')).toBe('6.0.0-rc.7')
    expect(npmVersionOf('6.0.0.rc10')).toBe('6.0.0-rc.10')
    expect(npmVersionOf('6.0.0.beta1')).toBe('6.0.0-beta.1')
    expect(npmVersionOf('6.0.0.alpha')).toBe('6.0.0-alpha')
    expect(npmVersionOf('6.1.2')).toBe('6.1.2')
    expect(npmVersionOf('6.0')).toBeUndefined()
  })
})

describe('releaseLineFor', () => {
  it('follows the server version, older or newer than the built-in line', () => {
    expect(releaseLineFor('6.0.0.rc8', LINE)).toEqual({ ...LINE, version: '6.0.0-rc.8' })
    expect(releaseLineFor('6.0.0.rc6', LINE)).toEqual({ ...LINE, version: '6.0.0-rc.6' })
  })

  it('moves nothing for a server from before the packages shared its version', () => {
    expect(releaseLineFor('5.6.2', LINE)).toEqual({ packages: [], version: '5.6.2' })
  })

  it('keeps the built-in line for a version it cannot read', () => {
    expect(releaseLineFor('main', LINE)).toBe(LINE)
  })
})

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
    writeStorefrontPackageJson(dir, { dependencies: { '@spree/sdk': '^6.0.0-rc.5' } })

    expect(sdkAdvisory(dir, LINE)).toBe(
      'Update @spree/sdk in apps/storefront (currently ^6.0.0-rc.5) to the release matching the new Spree version',
    )
  })

  it('names the exact range when the storefront is on an SDK line older than Spree 6', () => {
    const dir = makeTempDir()
    writeStorefrontPackageJson(dir, { dependencies: { '@spree/sdk': '^2.0.0-rc.5' } })

    expect(sdkAdvisory(dir, LINE)).toBe(
      'Update @spree/sdk in apps/storefront from ^2.0.0-rc.5 to ^6.0.0-rc.7: from Spree 6.0 the SDK shares the Spree version',
    )
  })

  it('finds @spree/sdk in devDependencies too', () => {
    const dir = makeTempDir()
    writeStorefrontPackageJson(dir, { devDependencies: { '@spree/sdk': '6.1.0' } })

    expect(sdkAdvisory(dir, LINE)).toContain('currently 6.1.0')
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

  it('runs bundle install and lists again when the bundle is out of sync', async () => {
    let listCalls = 0
    const calls: string[] = []
    mockExeca.mockImplementation((async (_cmd: string, args: string[]) => {
      if (args.includes('ps')) return { stdout: 'running' }
      if (args.includes('list')) {
        listCalls += 1
        if (listCalls === 1)
          throw Object.assign(new Error('x'), {
            exitCode: 1,
            stderr: 'The git source https://github.com/spree/spree.git is not yet checked out.',
          })
        return { stdout: 'spree\nspree_core\n' }
      }
      calls.push(args.join(' '))
      return { stdout: '' }
    }) as never)

    await expect(detectSpreeGems('/proj')).resolves.toEqual(['spree', 'spree_core'])
    expect(calls).toEqual(['compose exec web bundle install'])
  })

  it('throws with the bundler error when listing still fails after bundle install', async () => {
    mockExeca.mockImplementation((async (_cmd: string, args: string[]) => {
      if (args.includes('ps')) return { stdout: 'running' }
      if (args.includes('install')) return { stdout: '' }
      throw Object.assign(new Error('x'), { exitCode: 1, stderr: 'Could not find gem spree_core' })
    }) as never)
    await expect(detectSpreeGems('/proj')).rejects.toThrow(/even after reinstalling/)
    await expect(detectSpreeGems('/proj')).rejects.toThrow(/Could not find gem spree_core/)
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
    expect(detectSpreePackages(dir)).toEqual([
      { name: '@spree/dashboard', spec: '^1.0.0-beta.8', dev: false },
      { name: '@spree/cli', spec: '~3.1.0', dev: true },
      { name: '@spree/docs', spec: 'latest', dev: true },
    ])
  })

  it('lists exact versions too', () => {
    const dir = withPackageJson({ dependencies: { '@spree/dashboard': '6.0.0-rc.6' } })
    expect(detectSpreePackages(dir)).toEqual([
      { name: '@spree/dashboard', spec: '6.0.0-rc.6', dev: false },
    ])
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

describe('spreePeerRanges', () => {
  const mockExeca = vi.mocked(execa)
  afterEach(() => mockExeca.mockReset())

  it('keeps the higher floor where two packages name the same peer, and skips @spree/* peers', async () => {
    const answers: Record<string, unknown> = {
      '@spree/dashboard@^6.0.0': { 'react-hook-form': '^7.90.0', '@spree/dashboard-ui': '>=6.0.0' },
      // A range several versions match answers with one entry per version.
      '@spree/dashboard-ui@^6.0.0': [
        { 'react-hook-form': '^7.60.0' },
        { 'react-hook-form': '^7.75.0', i18next: '^26.2.0' },
      ],
    }
    mockExeca.mockImplementation((async (_cmd: string, args: string[]) => ({
      stdout: JSON.stringify(answers[args[1]]),
    })) as never)

    const ranges = await spreePeerRanges('/app', [
      { name: '@spree/dashboard-ui', spec: '^6.0.0' },
      { name: '@spree/dashboard', spec: '^6.0.0' },
    ])

    expect(ranges).toEqual({ 'react-hook-form': '^7.90.0', i18next: '^26.2.0' })
    expect(mockExeca).toHaveBeenCalledWith(
      'npm',
      ['view', '@spree/dashboard@^6.0.0', 'peerDependencies', '--json'],
      { cwd: '/app' },
    )
  })

  it('reads peers named like Object.prototype members as plain names', async () => {
    mockExeca.mockImplementation((async () => ({
      stdout: JSON.stringify({ constructor: '^1.0.0', toString: '^2.0.0' }),
    })) as never)

    expect(await spreePeerRanges('/app', [{ name: '@spree/dashboard', spec: '^6.0.0' }])).toEqual({
      constructor: '^1.0.0',
      toString: '^2.0.0',
    })
  })

  it('refuses peer ranges that are not plain version ranges', async () => {
    mockExeca.mockImplementation((async () => ({
      stdout: JSON.stringify({
        react: 'npm:other-react@99.0.0',
        'react-dom': 'file:../react-dom',
        i18next: '^99.0.0", "evil": "1.0.0',
        zod: '^4.0.0\n',
        'date-fns': '1.2.3 nonsense',
        'react-hook-form': '>=7.90.0 <8 || ^9',
      }),
    })) as never)

    expect(await spreePeerRanges('/app', [{ name: '@spree/dashboard', spec: '^6.0.0' }])).toEqual({
      'react-hook-form': '>=7.90.0 <8 || ^9',
    })
  })

  it('skips a package the registry cannot answer for', async () => {
    mockExeca.mockImplementation((async (_cmd: string, args: string[]) => {
      if (args[1].startsWith('@spree/dashboard@')) throw new Error('E404')
      return { stdout: args[1].startsWith('@spree/cli@') ? '' : JSON.stringify({ zod: '>=3.0.0' }) }
    }) as never)

    const ranges = await spreePeerRanges('/app', [
      { name: '@spree/dashboard', spec: '^6.0.0' },
      { name: '@spree/cli', spec: '^6.0.0' },
      { name: '@spree/admin-sdk', spec: '^6.0.0' },
    ])

    expect(ranges).toEqual({ zod: '>=3.0.0' })
    expect(prompts.log.warn).toHaveBeenCalledWith(
      expect.stringContaining('@spree/dashboard@^6.0.0'),
    )
  })
})

describe('alignPeerRanges', () => {
  let dir: string
  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-peer-ranges-test-'))
  })
  afterEach(() => fs.rmSync(dir, { recursive: true, force: true }))

  const PEERS = {
    'react-hook-form': '^7.90.0',
    i18next: '^26.5.3',
    react: '^19.3.1',
    zod: '>=3.0.0',
  }

  it('raises ranges that start below what Spree requires, keeping the formatting', () => {
    fs.writeFileSync(
      path.join(dir, 'package.json'),
      [
        '{',
        '    "dependencies": {',
        '        "react-hook-form": "^7.75.0",',
        '        "react": "^19.3.2",',
        '        "zod": "^4.0.0"',
        '    },',
        '    "devDependencies": { "i18next": "26.2.0" }',
        '}',
        '',
      ].join('\n'),
    )

    expect(alignPeerRanges(dir, PEERS)).toEqual([
      { name: 'react-hook-form', from: '^7.75.0', to: '^7.90.0', dev: false, exact: false },
      { name: 'i18next', from: '26.2.0', to: '^26.5.3', dev: true, exact: true },
    ])
    expect(fs.readFileSync(path.join(dir, 'package.json'), 'utf-8')).toBe(
      [
        '{',
        '    "dependencies": {',
        '        "react-hook-form": "^7.90.0",',
        '        "react": "^19.3.2",',
        '        "zod": "^4.0.0"',
        '    },',
        '    "devDependencies": { "i18next": "^26.5.3" }',
        '}',
        '',
      ].join('\n'),
    )
  })

  it('leaves a range inside any alternative of the peer range alone', () => {
    fs.writeFileSync(
      path.join(dir, 'package.json'),
      JSON.stringify({ dependencies: { 'react-hook-form': '^7.95.0', i18next: '^8.0.0' } }),
    )

    expect(
      alignPeerRanges(dir, { 'react-hook-form': '^9 || ^7.90.0', i18next: '^9 || ^7' }),
    ).toEqual([{ name: 'i18next', from: '^8.0.0', to: '^9 || ^7', dev: false, exact: false }])
    expect(
      JSON.parse(fs.readFileSync(path.join(dir, 'package.json'), 'utf-8')).dependencies,
    ).toEqual({
      'react-hook-form': '^7.95.0',
      i18next: '^9 || ^7',
    })
  })

  it('leaves a dependency listed in both groups alone, with a warning', () => {
    const source = JSON.stringify({
      dependencies: { 'react-hook-form': '7.80.0' },
      devDependencies: { 'react-hook-form': '^7.75.0' },
    })
    fs.writeFileSync(path.join(dir, 'package.json'), source)

    expect(alignPeerRanges(dir, PEERS)).toEqual([])
    expect(fs.readFileSync(path.join(dir, 'package.json'), 'utf-8')).toBe(source)
    expect(prompts.log.warn).toHaveBeenCalledWith(expect.stringContaining('react-hook-form'))
  })

  it('leaves local and tagged specs, and dependencies Spree does not require, alone', () => {
    const source = JSON.stringify({
      dependencies: { 'react-hook-form': 'workspace:*', i18next: 'latest', lodash: '^4.0.0' },
    })
    fs.writeFileSync(path.join(dir, 'package.json'), source)

    expect(alignPeerRanges(dir, PEERS)).toEqual([])
    expect(fs.readFileSync(path.join(dir, 'package.json'), 'utf-8')).toBe(source)
  })

  it('returns [] without a readable package.json', () => {
    expect(alignPeerRanges('/nonexistent', PEERS)).toEqual([])
  })
})

describe('moveToReleaseLine', () => {
  let dir: string
  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-release-line-test-'))
  })
  afterEach(() => fs.rmSync(dir, { recursive: true, force: true }))

  function writePackageJson(source: string): void {
    fs.writeFileSync(path.join(dir, 'package.json'), source)
  }

  function readPackageJson(): string {
    return fs.readFileSync(path.join(dir, 'package.json'), 'utf-8')
  }

  it('moves packages released with Spree off older lines, keeping the formatting', () => {
    writePackageJson(
      [
        '{',
        '    "dependencies": {',
        '        "@spree/dashboard": "^1.0.0-rc.7",',
        '        "@spree/dashboard-core": ">=0.13.1 <2.0.0",',
        '        "react": "^19.2.6"',
        '    },',
        '    "devDependencies": { "@spree/admin-sdk": "~1.0.0", "@spree/cli": "^3.4.1" }',
        '}',
        '',
      ].join('\n'),
    )

    expect(moveToReleaseLine(dir, LINE)).toEqual([
      { name: '@spree/dashboard', from: '^1.0.0-rc.7', to: '^6.0.0-rc.7' },
      { name: '@spree/dashboard-core', from: '>=0.13.1 <2.0.0', to: '^6.0.0-rc.7' },
      { name: '@spree/admin-sdk', from: '~1.0.0', to: '^6.0.0-rc.7' },
    ])
    expect(readPackageJson()).toBe(
      [
        '{',
        '    "dependencies": {',
        '        "@spree/dashboard": "^6.0.0-rc.7",',
        '        "@spree/dashboard-core": "^6.0.0-rc.7",',
        '        "react": "^19.2.6"',
        '    },',
        '    "devDependencies": { "@spree/admin-sdk": "^6.0.0-rc.7", "@spree/cli": "^3.4.1" }',
        '}',
        '',
      ].join('\n'),
    )
  })

  it('leaves current, exact, tagged and local specs alone', () => {
    const source = JSON.stringify({
      dependencies: {
        '@spree/dashboard': '^6.0.0-rc.5',
        '@spree/dashboard-ui': '1.0.0-rc.5',
        '@spree/dashboard-core': 'next',
        '@spree/admin-sdk': 'workspace:^',
      },
    })
    writePackageJson(source)

    expect(moveToReleaseLine(dir, LINE)).toEqual([])
    expect(readPackageJson()).toBe(source)
  })

  it('gives release candidate pins a range once the line is a final version', () => {
    writePackageJson(
      JSON.stringify({
        dependencies: {
          '@spree/dashboard': '6.0.0-rc.7',
          '@spree/dashboard-ui': '6.0.0',
          '@spree/admin-sdk': '6.0.1-rc.1',
        },
      }),
    )

    expect(moveToReleaseLine(dir, { ...LINE, version: '6.0.0' })).toEqual([
      { name: '@spree/dashboard', from: '6.0.0-rc.7', to: '^6.0.0' },
    ])
  })

  it('keeps release candidate pins exact while the line is still a release candidate', () => {
    const source = JSON.stringify({ dependencies: { '@spree/dashboard': '6.0.0-rc.6' } })
    writePackageJson(source)

    expect(moveToReleaseLine(dir, LINE)).toEqual([])
    expect(readPackageJson()).toBe(source)
  })

  it('returns [] without a readable package.json', () => {
    expect(moveToReleaseLine(dir, LINE)).toEqual([])
    writePackageJson('{ not json')
    expect(moveToReleaseLine(dir, LINE)).toEqual([])
  })
})

describe('isExactVersion', () => {
  it('tells single versions from ranges and tags', () => {
    expect(isExactVersion('1.0.0')).toBe(true)
    expect(isExactVersion('6.0.0-rc.7')).toBe(true)
    expect(isExactVersion('^6.0.0-rc.7')).toBe(false)
    expect(isExactVersion('~3.1.0')).toBe(false)
    expect(isExactVersion('>=0.5.0 <2.0.0')).toBe(false)
    expect(isExactVersion('1.x')).toBe(false)
    expect(isExactVersion('latest')).toBe(false)
  })
})

describe('isOlderVersion', () => {
  it('orders exact versions by semver precedence', () => {
    expect(isOlderVersion('6.0.0-rc.6', '6.0.0-rc.7')).toBe(true)
    expect(isOlderVersion('6.0.0-rc.9', '6.0.0-rc.10')).toBe(true)
    expect(isOlderVersion('1.0.0-rc.5', '6.0.0-rc.7')).toBe(true)
    expect(isOlderVersion('6.0.0-rc.7', '6.0.0')).toBe(true)
    expect(isOlderVersion('6.0.0-beta.1', '6.0.0-rc.1')).toBe(true)
    expect(isOlderVersion('6.0.0-rc', '6.0.0-rc.1')).toBe(true)
    expect(isOlderVersion('6.0.0-rc.1', '6.0.0-rc.rc')).toBe(true)

    expect(isOlderVersion('6.0.0-rc.7', '6.0.0-rc.7')).toBe(false)
    expect(isOlderVersion('6.0.0', '6.0.0-rc.7')).toBe(false)
    expect(isOlderVersion('6.0.1', '6.0.0')).toBe(false)
    expect(isOlderVersion('6.0.0-rc.10', '6.0.0-rc.9')).toBe(false)
    expect(isOlderVersion('7.0.0-rc.1', '6.9.9')).toBe(false)
  })
})

describe('packageAddArgs', () => {
  it('saves exact versions in the group they are declared in', () => {
    expect(packageAddArgs('pnpm', ['@spree/dashboard@6.0.0'], false)).toEqual([
      'add',
      '--save-exact',
      '@spree/dashboard@6.0.0',
    ])
    expect(packageAddArgs('pnpm', ['@spree/dashboard@6.0.0'], true)).toEqual([
      'add',
      '--save-exact',
      '--save-dev',
      '@spree/dashboard@6.0.0',
    ])
    expect(packageAddArgs('npm', ['@spree/dashboard@6.0.0'], false)).toEqual([
      'install',
      '--save-exact',
      '@spree/dashboard@6.0.0',
    ])
    expect(packageAddArgs('npm', ['@spree/dashboard@6.0.0'], true)).toEqual([
      'install',
      '--save-exact',
      '--save-dev',
      '@spree/dashboard@6.0.0',
    ])
    expect(packageAddArgs('yarn', ['@spree/dashboard@6.0.0'], false)).toEqual([
      'add',
      '--exact',
      '@spree/dashboard@6.0.0',
    ])
    expect(packageAddArgs('yarn', ['@spree/dashboard@6.0.0'], true)).toEqual([
      'add',
      '--exact',
      '--dev',
      '@spree/dashboard@6.0.0',
    ])
  })
})

describe('packageDedupeArgs', () => {
  let projectDir: string
  beforeEach(() => {
    projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-dedupe-test-'))
  })
  afterEach(() => fs.rmSync(projectDir, { recursive: true, force: true }))

  it('dedupes on pnpm, npm and Yarn Berry, and skips Yarn Classic', () => {
    expect(packageDedupeArgs('pnpm', projectDir, projectDir)).toEqual(['dedupe'])
    expect(packageDedupeArgs('npm', projectDir, projectDir)).toEqual(['dedupe'])
    expect(packageDedupeArgs('yarn', projectDir, projectDir)).toBeNull()
    fs.writeFileSync(path.join(projectDir, '.yarnrc.yml'), 'nodeLinker: node-modules\n')
    expect(packageDedupeArgs('yarn', projectDir, projectDir)).toEqual(['dedupe'])
  })

  it('recognises Yarn Berry from the packageManager field', () => {
    fs.writeFileSync(
      path.join(projectDir, 'package.json'),
      JSON.stringify({ packageManager: 'yarn@4.5.1' }),
    )
    expect(packageDedupeArgs('yarn', projectDir, projectDir)).toEqual(['dedupe'])
    expect(packageUpdateArgs('yarn', ['@spree/dashboard'], projectDir, projectDir)).toEqual([
      'up',
      '-R',
      '@spree/dashboard',
    ])

    fs.writeFileSync(
      path.join(projectDir, 'package.json'),
      JSON.stringify({ packageManager: 'yarn@1.22.22' }),
    )
    expect(packageDedupeArgs('yarn', projectDir, projectDir)).toBeNull()
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

describe('spree upgrade', () => {
  const mockExeca = vi.mocked(execa)
  let commands: string[]
  let versionProbes: string[]
  let registryProbes: string[]

  // Every docker and package-manager call goes through execa; record them in
  // order, leaving out the read-only probes (`compose ps`, `bundle list`, …).
  // `spreeVersion` is what the server's bundle reports for spree_core.
  // `peers` is what the registry answers for each @spree/* package's
  // peerDependencies (`npm view`, read-only like the probes above).
  function routeExeca({
    failOn,
    spreeVersion = '6.0.0.rc7',
    peers = {},
  }: {
    failOn?: string
    spreeVersion?: string | null
    peers?: Record<string, Record<string, string>>
  } = {}): void {
    mockExeca.mockImplementation((async (cmd: string, args: string[]) => {
      if (cmd === 'npm' && args[0] === 'view') {
        registryProbes.push(`${cmd} ${args.join(' ')}`)
        const name = args[1].slice(0, args[1].lastIndexOf('@'))
        return { stdout: peers[name] ? JSON.stringify(peers[name]) : '' }
      }
      if (args.includes('ps')) return { stdout: 'running' }
      if (args.includes('--name-only')) return { stdout: 'spree\nspree_core\n' }
      if (args.includes('list')) {
        versionProbes.push(`${cmd} ${args.join(' ')}`)
        if (spreeVersion === null) throw new Error('bundler failed')
        return { stdout: `  * spree (${spreeVersion})\n  * spree_core (${spreeVersion})\n` }
      }
      if (args.includes('config')) return { stdout: 'web\n' }
      const command = `${cmd} ${args.join(' ')}`
      commands.push(command)
      if (failOn && command.includes(failOn)) throw new Error(`${failOn} failed`)
      return { stdout: '' }
    }) as never)
  }

  function writeProject({
    ejected,
    dashboardDependencies = { '@spree/dashboard': '^1.0.0' },
  }: {
    ejected: boolean
    dashboardDependencies?: Record<string, string>
  }): void {
    projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-upgrade-run-test-'))
    fs.writeFileSync(
      path.join(projectDir, 'docker-compose.yml'),
      ejected
        ? 'services:\n  web:\n    build: ./server\n'
        : 'services:\n  web:\n    image: spree\n',
    )
    fs.writeFileSync(
      path.join(projectDir, 'package.json'),
      JSON.stringify({ devDependencies: { '@spree/cli': '^3.2.0' } }),
    )
    const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
    fs.mkdirSync(dashboardDir, { recursive: true })
    fs.writeFileSync(
      path.join(dashboardDir, 'package.json'),
      JSON.stringify({ dependencies: dashboardDependencies }),
    )
  }

  async function runUpgrade(argv: string[] = []): Promise<void> {
    const program = new Command()
    registerUpgradeCommand(program)
    await program.parseAsync(['upgrade', '--yes', ...argv], { from: 'user' })
  }

  beforeEach(() => {
    commands = []
    versionProbes = []
    registryProbes = []
    vi.mocked(prompts.log.warn).mockClear()
    routeExeca()
  })

  afterEach(() => {
    mockExeca.mockReset()
    fs.rmSync(projectDir, { recursive: true, force: true })
  })

  it('bumps the packages after the gems and before migrations and backfills on an ejected project', async () => {
    writeProject({ ejected: true })

    await runUpgrade()

    expect(commands).toEqual([
      'docker compose exec web bundle update spree spree_core',
      'pnpm update @spree/cli',
      'pnpm dedupe',
      'pnpm update @spree/dashboard',
      'pnpm dedupe',
      'docker compose exec web bin/rails spree:install:migrations db:migrate',
      'docker compose exec web bin/rails spree:upgrade',
      'docker compose restart web',
    ])
  })

  it('bumps the packages after the image pull and before the migrating recreate on an image-based project', async () => {
    writeProject({ ejected: false })

    await runUpgrade()

    expect(commands).toEqual([
      'docker compose pull',
      'pnpm update @spree/cli',
      'pnpm dedupe',
      'pnpm update @spree/dashboard',
      'pnpm dedupe',
      'docker compose up -d --no-deps web',
      'docker compose up -d --wait',
      'docker compose exec web bin/rails spree:upgrade',
    ])
  })

  it("moves the old line's ranges to the Spree version before updating", async () => {
    writeProject({ ejected: true })

    await runUpgrade()

    const dashboard = JSON.parse(
      fs.readFileSync(path.join(projectDir, 'apps', 'dashboard', 'package.json'), 'utf-8'),
    )
    expect(dashboard.dependencies['@spree/dashboard']).toBe('^6.0.0-rc.7')
  })

  it('installs pinned packages at the Spree version and keeps them pinned', async () => {
    writeProject({
      ejected: true,
      dashboardDependencies: {
        '@spree/dashboard': '6.0.0-rc.6',
        '@spree/dashboard-ui': '6.0.0-rc.6',
        '@spree/dashboard-core': '6.0.0-rc.7',
        '@spree/admin-sdk': '^6.0.0-rc.6',
      },
    })

    await runUpgrade()

    expect(commands).toEqual([
      'docker compose exec web bundle update spree spree_core',
      'pnpm update @spree/cli',
      'pnpm dedupe',
      'pnpm update @spree/admin-sdk',
      'pnpm add --save-exact @spree/dashboard@6.0.0-rc.7 @spree/dashboard-ui@6.0.0-rc.7',
      'pnpm dedupe',
      'docker compose exec web bin/rails spree:install:migrations db:migrate',
      'docker compose exec web bin/rails spree:upgrade',
      'docker compose restart web',
    ])
  })

  it('leaves pins newer than the Spree version it was built with', async () => {
    writeProject({
      ejected: true,
      dashboardDependencies: { '@spree/dashboard': '6.0.0', '@spree/dashboard-ui': '6.0.1' },
    })

    await runUpgrade()

    expect(commands.filter((command) => command.startsWith('pnpm'))).toEqual([
      'pnpm update @spree/cli',
      'pnpm dedupe',
      'pnpm dedupe',
    ])
  })

  it('moves the packages to the Spree version the server runs, not the one built in', async () => {
    writeProject({
      ejected: true,
      dashboardDependencies: {
        '@spree/dashboard': '6.0.0-rc.7',
        '@spree/dashboard-core': '^1.0.0',
      },
    })
    routeExeca({ spreeVersion: '6.0.0.rc8' })

    await runUpgrade()

    expect(commands.filter((command) => command.startsWith('pnpm'))).toEqual([
      'pnpm update @spree/cli',
      'pnpm dedupe',
      'pnpm update @spree/dashboard-core',
      'pnpm add --save-exact @spree/dashboard@6.0.0-rc.8',
      'pnpm dedupe',
    ])
    const dashboard = JSON.parse(
      fs.readFileSync(path.join(projectDir, 'apps', 'dashboard', 'package.json'), 'utf-8'),
    )
    expect(dashboard.dependencies['@spree/dashboard-core']).toBe('^6.0.0-rc.8')
  })

  it('gives release candidate pins a range back when the final release lands', async () => {
    writeProject({
      ejected: true,
      dashboardDependencies: {
        '@spree/dashboard': '6.0.0-rc.7',
        '@spree/dashboard-ui': '6.0.0-rc.7',
        '@spree/dashboard-core': '6.0.0-rc.7',
      },
    })
    const dashboardPackageJson = path.join(projectDir, 'apps', 'dashboard', 'package.json')
    const manifest = JSON.parse(fs.readFileSync(dashboardPackageJson, 'utf-8'))
    manifest.devDependencies = { '@spree/admin-sdk': '6.0.0-rc.7' }
    fs.writeFileSync(dashboardPackageJson, JSON.stringify(manifest))
    routeExeca({ spreeVersion: '6.0.0' })

    await runUpgrade()

    expect(commands.filter((command) => command.startsWith('pnpm'))).toEqual([
      'pnpm update @spree/cli',
      'pnpm dedupe',
      'pnpm update @spree/dashboard @spree/dashboard-ui @spree/dashboard-core @spree/admin-sdk',
      'pnpm dedupe',
    ])
    const dashboard = JSON.parse(fs.readFileSync(dashboardPackageJson, 'utf-8'))
    expect(dashboard.dependencies).toEqual({
      '@spree/dashboard': '^6.0.0',
      '@spree/dashboard-ui': '^6.0.0',
      '@spree/dashboard-core': '^6.0.0',
    })
    expect(dashboard.devDependencies).toEqual({ '@spree/admin-sdk': '^6.0.0' })
  })

  it('moves app dependencies below the peer ranges Spree requires, in the same update as the packages', async () => {
    writeProject({
      ejected: true,
      dashboardDependencies: {
        '@spree/dashboard': '^6.0.0-rc.6',
        '@spree/dashboard-ui': '6.0.0-rc.6',
        'react-hook-form': '^7.75.0',
        i18next: '26.2.0',
        react: '^19.3.1',
      },
    })
    routeExeca({
      peers: {
        '@spree/dashboard': { 'react-hook-form': '^7.90.0', react: '^19.3.1' },
        '@spree/dashboard-ui': { i18next: '^26.5.3', 'react-hook-form': '^7.75.0' },
      },
    })

    await runUpgrade()

    expect(registryProbes).toContain(
      'npm view @spree/dashboard-ui@6.0.0-rc.7 peerDependencies --json',
    )
    expect(commands.filter((command) => command.startsWith('pnpm'))).toEqual([
      'pnpm update @spree/cli',
      'pnpm dedupe',
      'pnpm update @spree/dashboard react-hook-form',
      'pnpm add --save-exact @spree/dashboard-ui@6.0.0-rc.7 i18next@^26.5.3',
      'pnpm dedupe',
    ])
    const dashboard = JSON.parse(
      fs.readFileSync(path.join(projectDir, 'apps', 'dashboard', 'package.json'), 'utf-8'),
    )
    expect(dashboard.dependencies).toMatchObject({
      'react-hook-form': '^7.90.0',
      i18next: '^26.5.3',
      react: '^19.3.1',
    })
  })

  it('keeps a pin on a final version exact', async () => {
    writeProject({ ejected: true, dashboardDependencies: { '@spree/dashboard': '6.0.0' } })
    routeExeca({ spreeVersion: '6.0.1' })

    await runUpgrade()

    expect(commands).toContain('pnpm add --save-exact @spree/dashboard@6.0.1')
  })

  it('reads a pulled image from a one-off container, since the running one is still the old image', async () => {
    writeProject({ ejected: false })

    await runUpgrade()

    expect(versionProbes).toEqual(['docker compose run --rm --no-deps -T web bundle list'])
  })

  it('falls back to the built-in Spree version, with a warning, when the server cannot say', async () => {
    writeProject({ ejected: true, dashboardDependencies: { '@spree/dashboard': '6.0.0-rc.6' } })
    routeExeca({ spreeVersion: null })

    await runUpgrade()

    expect(commands).toContain('pnpm add --save-exact @spree/dashboard@6.0.0-rc.7')
    expect(vi.mocked(prompts.log.warn)).toHaveBeenCalledWith(
      expect.stringContaining("Could not read the server's Spree version"),
    )
  })

  it('moves nothing on a server from before the packages shared its version', async () => {
    writeProject({ ejected: true, dashboardDependencies: { '@spree/dashboard': '1.0.0-rc.6' } })
    routeExeca({ spreeVersion: '5.6.2' })

    await runUpgrade()

    expect(commands.filter((command) => command.startsWith('pnpm'))).toEqual([
      'pnpm update @spree/cli',
      'pnpm dedupe',
      'pnpm dedupe',
    ])
  })

  it('has already bumped the packages when a backfill fails', async () => {
    writeProject({ ejected: true })
    routeExeca({ failOn: 'spree:upgrade' })

    await expect(runUpgrade()).rejects.toThrow(/spree:upgrade failed/)

    expect(commands).toContain('pnpm update @spree/dashboard')
    expect(commands.at(-1)).toBe('docker compose exec web bin/rails spree:upgrade')
  })

  describe('when `compose ps` fails', () => {
    function failProbe(stderr: string): void {
      mockExeca.mockImplementation((async (_cmd: string, args: string[]) => {
        if (args.includes('ps')) {
          throw Object.assign(
            new Error(
              "Command failed with exit code 1: docker compose ps web --format '{{.State}}'",
            ),
            { exitCode: 1, stderr },
          )
        }
        return { stdout: '' }
      }) as never)
    }

    beforeEach(() => {
      writeProject({ ejected: false })
      vi.spyOn(process, 'exit').mockImplementation(((code: number) => {
        throw Object.assign(new Error('exit'), { code })
      }) as never)
    })

    afterEach(() => {
      vi.restoreAllMocks()
    })

    it('says Docker is not running when the daemon is down', async () => {
      failProbe(
        'failed to connect to the docker API at unix:///var/run/docker.sock; check if the path is correct and if the daemon is running',
      )

      await expect(runUpgrade()).rejects.toMatchObject({ code: 1 })

      expect(vi.mocked(p.cancel)).toHaveBeenCalledWith(
        expect.stringMatching(/^Docker is not running\./),
      )
      expect(commands).toEqual([])
    })

    it('says Docker is not installed when the docker command is missing', async () => {
      mockExeca.mockImplementation((async () => {
        throw Object.assign(new Error('Command failed with ENOENT: docker compose ps web'), {
          code: 'ENOENT',
          originalMessage: 'spawn docker ENOENT',
          stderr: '',
        })
      }) as never)

      await expect(runUpgrade()).rejects.toMatchObject({ code: 1 })

      expect(vi.mocked(p.cancel)).toHaveBeenCalledWith(
        expect.stringMatching(/^Docker is not installed/),
      )
    })

    it("shows Docker's own reason for any other failure", async () => {
      failProbe('no such service: web')

      await expect(runUpgrade()).rejects.toMatchObject({ code: 1 })

      const message = vi.mocked(p.cancel).mock.calls.at(-1)?.[0]
      expect(message).toMatch(/no such service: web/)
      expect(message).not.toMatch(/Command failed/)
    })
  })

  it('skips only the upgrade tasks when the operator declines them', async () => {
    writeProject({ ejected: true })
    vi.mocked(p.confirm).mockImplementation(
      (async ({ message }: { message: string }) => !message.includes('upgrade tasks')) as never,
    )

    const program = new Command()
    registerUpgradeCommand(program)
    await program.parseAsync(['upgrade'], { from: 'user' })

    expect(commands).toContain(
      'docker compose exec web bin/rails spree:install:migrations db:migrate',
    )
    expect(commands).not.toContain('docker compose exec web bin/rails spree:upgrade')
  })

  it('runs only the rake task with --plan or --step', async () => {
    writeProject({ ejected: true })

    await runUpgrade(['--plan'])
    await runUpgrade(['--step', 'channels'])

    expect(commands).toEqual([
      'docker compose exec -e DRY_RUN=1 web bin/rails spree:upgrade',
      'docker compose exec -e STEP=channels web bin/rails spree:upgrade',
    ])
  })
})
