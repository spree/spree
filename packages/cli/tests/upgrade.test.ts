import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('execa', () => ({ execa: vi.fn() }))

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
import { execa } from 'execa'
import {
  detectSpreeGems,
  detectSpreePackages,
  moveToReleaseLine,
  packageUpdateArgs,
  registerUpgradeCommand,
  sdkAdvisory,
} from '../src/commands/upgrade'

const LINE = {
  packages: ['@spree/sdk', '@spree/admin-sdk', '@spree/dashboard', '@spree/dashboard-core'],
  version: '6.0.0-rc.7',
}

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
    await expect(detectSpreeGems('/proj')).rejects.toThrow(/even after `bundle install`/)
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

  it('leaves current, tagged and local specs alone', () => {
    const source = JSON.stringify({
      dependencies: {
        '@spree/dashboard': '^6.0.0-rc.5',
        '@spree/dashboard-core': 'next',
        '@spree/admin-sdk': 'workspace:^',
      },
    })
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

  // Every docker and package-manager call goes through execa; record them in
  // order, leaving out the read-only probes (`compose ps`, `bundle list`, …).
  function routeExeca({ failOn }: { failOn?: string } = {}): void {
    mockExeca.mockImplementation((async (cmd: string, args: string[]) => {
      if (args.includes('ps')) return { stdout: 'running' }
      if (args.includes('list')) return { stdout: 'spree\nspree_core\n' }
      if (args.includes('config')) return { stdout: 'web\n' }
      const command = `${cmd} ${args.join(' ')}`
      commands.push(command)
      if (failOn && command.includes(failOn)) throw new Error(`${failOn} failed`)
      return { stdout: '' }
    }) as never)
  }

  function writeProject({ ejected }: { ejected: boolean }): void {
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
      JSON.stringify({ dependencies: { '@spree/dashboard': '^1.0.0' } }),
    )
  }

  async function runUpgrade(argv: string[] = []): Promise<void> {
    const program = new Command()
    registerUpgradeCommand(program)
    await program.parseAsync(['upgrade', '--yes', ...argv], { from: 'user' })
  }

  beforeEach(() => {
    commands = []
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
      'pnpm update @spree/dashboard',
      'docker compose exec web bin/rails spree:install:migrations db:migrate',
      'docker compose exec web bin/rake spree:upgrade',
      'docker compose restart web',
    ])
  })

  it('bumps the packages after the image pull and before the migrating recreate on an image-based project', async () => {
    writeProject({ ejected: false })

    await runUpgrade()

    expect(commands).toEqual([
      'docker compose pull',
      'pnpm update @spree/cli',
      'pnpm update @spree/dashboard',
      'docker compose up -d --no-deps web',
      'docker compose up -d --wait',
      'docker compose exec web bin/rake spree:upgrade',
    ])
  })

  it('has already bumped the packages when a backfill fails', async () => {
    writeProject({ ejected: true })
    routeExeca({ failOn: 'spree:upgrade' })

    await expect(runUpgrade()).rejects.toThrow(/spree:upgrade failed/)

    expect(commands).toContain('pnpm update @spree/dashboard')
    expect(commands.at(-1)).toBe('docker compose exec web bin/rake spree:upgrade')
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
    expect(commands).not.toContain('docker compose exec web bin/rake spree:upgrade')
  })

  it('runs only the rake task with --plan or --step', async () => {
    writeProject({ ejected: true })

    await runUpgrade(['--plan'])
    await runUpgrade(['--step', 'channels'])

    expect(commands).toEqual([
      'docker compose exec -e DRY_RUN=1 web bin/rake spree:upgrade',
      'docker compose exec -e STEP=channels web bin/rake spree:upgrade',
    ])
  })
})
