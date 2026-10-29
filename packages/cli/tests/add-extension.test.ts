import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import * as p from '@clack/prompts'
import { Command } from 'commander'
import { execa } from 'execa'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { registerAddCommand } from '../src/commands/add.js'
import { addExtension } from '../src/commands/add-extension.js'
import { ejectProject } from '../src/commands/eject.js'
import { dockerComposeCapture, dockerComposeExecOrRun, restartAppServices } from '../src/docker.js'
import {
  EXTENSIONS,
  gemfileDeclares,
  isValidGemName,
  isValidNpmName,
  lockedSpreeVersion,
  resolveExtension,
} from '../src/lib/extensions.js'
import type { ProjectContext } from '../src/types.js'

vi.mock('execa', () => ({ execa: vi.fn(async () => ({})) }))

vi.mock('@clack/prompts', () => ({
  log: { info: vi.fn(), warn: vi.fn(), step: vi.fn(), success: vi.fn() },
  spinner: () => ({ start: vi.fn(), stop: vi.fn() }),
  confirm: vi.fn(),
  isCancel: () => false,
  cancel: vi.fn(),
  intro: vi.fn(),
  outro: vi.fn(),
}))

vi.mock('../src/docker.js', () => ({
  dockerComposeCapture: vi.fn(async () => ''),
  dockerComposeExecOrRun: vi.fn(async () => undefined),
  restartAppServices: vi.fn(async () => undefined),
}))

vi.mock('../src/commands/eject.js', () => ({ ejectProject: vi.fn(async () => undefined) }))

const GEMFILE = `source 'https://rubygems.org'
gem 'spree', '>= 6.0.0.beta1'
gem 'spree_stripe', spree_version
# gem 'spree_adyen'
`

const LOCKFILE = `GEM
  specs:
    spree (6.0.0.rc3)
    spree_core (6.0.0.rc3)
`

const EJECTED_COMPOSE = 'services:\n  web:\n    build:\n      context: ./server\n'
const PREBUILT_COMPOSE = 'services:\n  web:\n    image: spree/spree\n'
const IMAGE_LOCKFILE = `${LOCKFILE}    spree_stripe (6.0.0.rc3)\n`

describe('extension catalog', () => {
  it('resolves a name by key, alias or full gem name, never by guessing', () => {
    expect(resolveExtension('paypal')?.gem).toBe('spree_paypal_checkout')
    expect(resolveExtension('paypal_checkout')?.gem).toBe('spree_paypal_checkout')
    expect(resolveExtension('spree_paypal_checkout')?.gem).toBe('spree_paypal_checkout')
    expect(resolveExtension('AvaTax')?.gem).toBe('spree_avatax_official')
    expect(resolveExtension('avatax-official')?.gem).toBe('spree_avatax_official')
    expect(resolveExtension('stirpe')).toBeUndefined()
    expect(resolveExtension('spree_paypal')).toBeUndefined()
  })

  it('gives every name exactly one meaning, distinct from the built-in components', () => {
    const names = Object.entries(EXTENSIONS).flatMap(([key, entry]) => [
      key,
      ...(entry.gem === key ? [] : [entry.gem]),
      ...(entry.aliases ?? []),
    ])
    expect(new Set(names).size).toBe(names.length)
    for (const component of ['dashboard', 'seller_dashboard', 'seller-dashboard', 'ai']) {
      expect(names).not.toContain(component)
    }
    for (const entry of Object.values(EXTENSIONS)) {
      expect(isValidGemName(entry.gem)).toBe(true)
    }
  })

  it('refuses names that could be read as a flag or a path', () => {
    expect(isValidGemName('acme_loyalty')).toBe(true)
    expect(isValidGemName('--git=https://example.com/x')).toBe(false)
    expect(isValidGemName('../x')).toBe(false)
    expect(isValidNpmName('@acme/loyalty-dashboard')).toBe(true)
    expect(isValidNpmName('-D')).toBe(false)
    expect(isValidNpmName('file:../x')).toBe(false)
  })

  it('reads declared gems and the locked Spree version', () => {
    expect(gemfileDeclares(GEMFILE, 'spree_stripe')).toBe(true)
    expect(gemfileDeclares(GEMFILE, 'spree_adyen')).toBe(false)
    expect(gemfileDeclares(GEMFILE, 'spree')).toBe(true)
    expect(gemfileDeclares(GEMFILE, 'spree_s')).toBe(false)
    expect(lockedSpreeVersion(LOCKFILE)).toBe('6.0.0.rc3')
    expect(lockedSpreeVersion(LOCKFILE.replaceAll('\n', '\r\n'))).toBe('6.0.0.rc3')
    expect(lockedSpreeVersion('GEM\n')).toBeUndefined()
  })
})

describe('addExtension', () => {
  let projectDir: string
  const originalIsTTY = process.stdin.isTTY

  function ctx(): ProjectContext {
    return { mode: 'docker', projectDir, port: 3000 }
  }

  function write(file: string, content: string): void {
    fs.mkdirSync(path.dirname(path.join(projectDir, file)), { recursive: true })
    fs.writeFileSync(path.join(projectDir, file), content)
  }

  function read(file: string): string {
    return fs.readFileSync(path.join(projectDir, file), 'utf-8')
  }

  function commands(): string[][] {
    return vi.mocked(dockerComposeExecOrRun).mock.calls.map(([argv]) => argv)
  }

  beforeEach(() => {
    projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-add-extension-'))
    write('server/Gemfile', GEMFILE)
    write('server/Gemfile.lock', LOCKFILE)
    write('docker-compose.yml', EJECTED_COMPOSE)
    vi.clearAllMocks()
    vi.mocked(dockerComposeCapture).mockImplementation(async (argv) =>
      argv[0] === 'cat' ? IMAGE_LOCKFILE : '',
    )
    vi.mocked(dockerComposeExecOrRun).mockResolvedValue(undefined)
    vi.spyOn(process, 'exit').mockImplementation((code?: number | string | null) => {
      throw new Error(`process.exit(${code})`)
    })
  })

  afterEach(() => {
    fs.rmSync(projectDir, { recursive: true, force: true })
    Object.defineProperty(process.stdin, 'isTTY', { value: originalIsTTY, configurable: true })
    vi.restoreAllMocks()
  })

  it('adds a gem released with Spree pinned to the project version, then migrates and restarts', async () => {
    await addExtension(ctx(), EXTENSIONS.mcp, { yes: false })

    expect(commands()).toEqual([
      ['bundle', 'add', 'spree_mcp', '--version', '>= 6.0.0.rc3'],
      ['bin/rails', 'spree:install:migrations', 'db:migrate'],
    ])
    expect(restartAppServices).toHaveBeenCalledWith(projectDir, expect.any(String))
    expect(ejectProject).not.toHaveBeenCalled()
  })

  it('adds a gem released on its own unpinned, and runs its install generator when it has one', async () => {
    vi.mocked(dockerComposeCapture).mockResolvedValue(
      'SpreePaypalCheckout:\n  spree_paypal_checkout:install\n',
    )

    await addExtension(ctx(), EXTENSIONS.paypal_checkout, { yes: false })

    expect(commands()).toEqual([
      ['bundle', 'add', 'spree_paypal_checkout'],
      ['bin/rails', 'generate', 'spree_paypal_checkout:install'],
      ['bin/rails', 'spree:install:migrations', 'db:migrate'],
    ])
  })

  it('reports a gem the prebuilt image already contains without ejecting', async () => {
    write('docker-compose.yml', PREBUILT_COMPOSE)

    await addExtension(ctx(), EXTENSIONS.stripe, { yes: true })

    expect(ejectProject).not.toHaveBeenCalled()
    expect(commands()).toEqual([])
    expect(restartAppServices).not.toHaveBeenCalled()
  })

  // The prebuilt image runs its own lockfile; a line added to the Gemfile by
  // hand without ejecting never reached it.
  it('ejects for a gem the Gemfile lists but the prebuilt image does not contain', async () => {
    write('docker-compose.yml', PREBUILT_COMPOSE)
    write('server/Gemfile', `${GEMFILE}gem 'spree_klaviyo'\n`)

    await addExtension(ctx(), EXTENSIONS.klaviyo, { yes: true })

    expect(ejectProject).toHaveBeenCalledWith(projectDir)
    expect(commands()).toEqual([['bin/rails', 'spree:install:migrations', 'db:migrate']])
  })

  it('repairs a gem already listed in an ejected project, keeping files its installer wrote', async () => {
    vi.mocked(dockerComposeCapture).mockResolvedValue('SpreeStripe:\n  spree_stripe:install\n')

    await addExtension(ctx(), EXTENSIONS.stripe, { yes: false })

    expect(commands()).toEqual([
      ['bin/rails', 'generate', 'spree_stripe:install', '--skip'],
      ['bin/rails', 'spree:install:migrations', 'db:migrate'],
    ])
  })

  it('ejects a project on the prebuilt image once the developer agrees', async () => {
    write('docker-compose.yml', PREBUILT_COMPOSE)

    await addExtension(ctx(), EXTENSIONS.adyen, { yes: true })

    expect(ejectProject).toHaveBeenCalledWith(projectDir)
    expect(commands()[0]).toEqual(['bundle', 'add', 'spree_adyen'])
  })

  it('stops without ejecting when there is no terminal to ask in and no --yes', async () => {
    write('docker-compose.yml', PREBUILT_COMPOSE)
    Object.defineProperty(process.stdin, 'isTTY', { value: false, configurable: true })

    await expect(addExtension(ctx(), EXTENSIONS.adyen, { yes: false })).rejects.toThrow(
      'process.exit(1)',
    )
    expect(ejectProject).not.toHaveBeenCalled()
    expect(commands()).toEqual([])
  })

  it('stops when the developer declines to eject', async () => {
    write('docker-compose.yml', PREBUILT_COMPOSE)
    Object.defineProperty(process.stdin, 'isTTY', { value: true, configurable: true })
    vi.mocked(p.confirm).mockResolvedValue(false)

    await expect(addExtension(ctx(), EXTENSIONS.adyen, { yes: false })).rejects.toThrow(
      'process.exit(0)',
    )
    expect(ejectProject).not.toHaveBeenCalled()
  })

  it('puts back the Gemfile, its lock and config when a step after bundle add fails, keeping copied migrations', async () => {
    write('server/config/routes.rb', 'Rails.application.routes.draw {}\n')
    vi.mocked(dockerComposeCapture).mockResolvedValue('SpreeKlaviyo:\n  spree_klaviyo:install\n')
    vi.mocked(dockerComposeExecOrRun).mockImplementation(async (argv) => {
      if (argv[0] === 'bundle') {
        fs.appendFileSync(path.join(projectDir, 'server/Gemfile'), "gem 'spree_klaviyo'\n")
        fs.appendFileSync(
          path.join(projectDir, 'server/Gemfile.lock'),
          '    spree_klaviyo (1.1.2)\n',
        )
      } else if (argv[1] === 'generate') {
        write('server/config/initializers/spree_klaviyo.rb', 'SpreeKlaviyo.setup\n')
        write('server/db/migrate/20261019000000_create_klaviyo.rb', 'class CreateKlaviyo; end\n')
        fs.appendFileSync(path.join(projectDir, 'server/config/routes.rb'), '# klaviyo\n')
      } else {
        throw new Error('migration failed')
      }
    })

    await expect(addExtension(ctx(), EXTENSIONS.klaviyo, { yes: false })).rejects.toThrow(
      'process.exit(1)',
    )
    expect(read('server/Gemfile')).toBe(GEMFILE)
    expect(read('server/Gemfile.lock')).toBe(LOCKFILE)
    expect(read('server/config/routes.rb')).toBe('Rails.application.routes.draw {}\n')
    expect(
      fs.existsSync(path.join(projectDir, 'server/config/initializers/spree_klaviyo.rb')),
    ).toBe(false)
    // Kept so a re-run skips migrations that already ran.
    expect(fs.readdirSync(path.join(projectDir, 'server/db/migrate'))).toEqual([
      '20261019000000_create_klaviyo.rb',
    ])
  })

  it('refuses to add a Spree-released gem when the locked Spree version is unknown', async () => {
    write('server/Gemfile.lock', 'GEM\n')

    await expect(addExtension(ctx(), EXTENSIONS.meilisearch, { yes: false })).rejects.toThrow(
      'process.exit(1)',
    )
    expect(commands()).toEqual([])
  })

  it('installs dashboard plugins into the apps that exist and skips the rest', async () => {
    write('apps/dashboard/package.json', '{}')
    write('apps/dashboard/pnpm-lock.yaml', '')

    await addExtension(
      ctx(),
      { label: 'Loyalty', dashboard: '@acme/loyalty', sellerDashboard: '@acme/loyalty-seller' },
      { yes: false },
    )

    expect(execa).toHaveBeenCalledTimes(1)
    expect(execa).toHaveBeenCalledWith('pnpm', ['add', '@acme/loyalty'], {
      cwd: path.join(projectDir, 'apps/dashboard'),
      stdio: 'inherit',
    })
    expect(p.log.warn).toHaveBeenCalledWith(expect.stringContaining('apps/seller-dashboard/'))
    expect(commands()).toEqual([])
  })
})

describe('spree add', () => {
  const originalIsTTY = process.stdin.isTTY

  async function run(...args: string[]): Promise<void> {
    const program = new Command()
    registerAddCommand(program)
    await program.parseAsync(['add', ...args], { from: 'user' })
  }

  beforeEach(() => {
    vi.spyOn(console, 'error').mockImplementation(() => {})
    vi.spyOn(process, 'exit').mockImplementation((code?: number | string | null) => {
      throw new Error(`process.exit(${code})`)
    })
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('refuses a name the catalog does not know, and lists what it does', async () => {
    await expect(run('stirpe')).rejects.toThrow('process.exit(2)')
    await expect(run('constructor')).rejects.toThrow('process.exit(2)')
    expect(console.error).toHaveBeenCalledWith(
      expect.stringContaining('paypal, adyen, klaviyo, avatax'),
    )
    expect(ejectProject).not.toHaveBeenCalled()
  })

  it('refuses gem and package names that could be read as flags', async () => {
    await expect(run('--gem', '--git=https://example.com/x')).rejects.toThrow('process.exit(2)')
    await expect(run('--npm', 'file:../x')).rejects.toThrow('process.exit(2)')
  })

  it('installs an official gem named with --gem as the catalog says, without asking', async () => {
    const projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-add-gem-'))
    fs.mkdirSync(path.join(projectDir, 'server'))
    fs.writeFileSync(path.join(projectDir, 'server/Gemfile'), GEMFILE)
    fs.writeFileSync(path.join(projectDir, 'server/Gemfile.lock'), LOCKFILE)
    fs.writeFileSync(path.join(projectDir, 'docker-compose.yml'), EJECTED_COMPOSE)
    vi.spyOn(process, 'cwd').mockReturnValue(projectDir)
    Object.defineProperty(process.stdin, 'isTTY', { value: false, configurable: true })
    vi.mocked(dockerComposeExecOrRun).mockClear()

    try {
      await run('--gem', 'spree_meilisearch')
    } finally {
      fs.rmSync(projectDir, { recursive: true, force: true })
      Object.defineProperty(process.stdin, 'isTTY', { value: originalIsTTY, configurable: true })
    }

    expect(vi.mocked(dockerComposeExecOrRun).mock.calls[0][0]).toEqual([
      'bundle',
      'add',
      'spree_meilisearch',
      '--version',
      '>= 6.0.0.rc3',
    ])
  })

  it('refuses a catalog name combined with --gem', async () => {
    await expect(run('stripe', '--gem', 'acme_loyalty')).rejects.toThrow('process.exit(2)')
  })
})
