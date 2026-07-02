import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { registerInitCommand, updateStorefrontEnv } from '../src/commands/init'
import { dockerCompose } from '../src/docker'
import { cancelOnPortConflict } from '../src/ports'

vi.mock('../src/context', () => ({
  detectProject: () => ({ mode: 'project', projectDir: '/proj', port: 3000 }),
}))

vi.mock('../src/docker', () => ({
  dockerCompose: vi.fn().mockResolvedValue(undefined),
  primeBundleVolume: vi.fn().mockResolvedValue(undefined),
  rakeTask: vi.fn().mockResolvedValue(''),
  streamLogs: vi.fn().mockResolvedValue(undefined),
}))

vi.mock('../src/ports', () => ({ cancelOnPortConflict: vi.fn() }))

vi.mock('../src/config', () => ({ mintProjectCredentials: vi.fn() }))

vi.mock('@clack/prompts', () => ({
  log: { step: vi.fn(), info: vi.fn() },
  spinner: () => ({ start: vi.fn(), stop: vi.fn() }),
  note: vi.fn(),
}))

class ExitError extends Error {
  constructor(public code: number) {
    super(`process.exit(${code})`)
  }
}

const tempDirs: string[] = []

function makeTempDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-init-test-'))
  tempDirs.push(dir)
  return dir
}

afterEach(() => {
  for (const dir of tempDirs) {
    fs.rmSync(dir, { recursive: true, force: true })
  }
  tempDirs.length = 0
})

describe('updateStorefrontEnv', () => {
  it('replaces placeholder key with real API key', () => {
    const dir = makeTempDir()
    const envPath = path.join(dir, 'apps', 'storefront')
    fs.mkdirSync(envPath, { recursive: true })
    fs.writeFileSync(
      path.join(envPath, '.env.local'),
      'SPREE_API_URL=http://localhost:3000\nSPREE_PUBLISHABLE_KEY=pk_REPLACE_ME_AFTER_DOCKER_START\n',
    )

    updateStorefrontEnv(dir, 'pk_test_abc123')

    const content = fs.readFileSync(path.join(envPath, '.env.local'), 'utf-8')
    expect(content).toContain('SPREE_PUBLISHABLE_KEY=pk_test_abc123')
    expect(content).not.toContain('pk_REPLACE_ME_AFTER_DOCKER_START')
  })

  it('replaces any existing key value', () => {
    const dir = makeTempDir()
    const envPath = path.join(dir, 'apps', 'storefront')
    fs.mkdirSync(envPath, { recursive: true })
    fs.writeFileSync(
      path.join(envPath, '.env.local'),
      'SPREE_API_URL=http://localhost:3000\nSPREE_PUBLISHABLE_KEY=pk_old_key\n',
    )

    updateStorefrontEnv(dir, 'pk_new_key')

    const content = fs.readFileSync(path.join(envPath, '.env.local'), 'utf-8')
    expect(content).toContain('SPREE_PUBLISHABLE_KEY=pk_new_key')
  })

  it('preserves other env variables', () => {
    const dir = makeTempDir()
    const envPath = path.join(dir, 'apps', 'storefront')
    fs.mkdirSync(envPath, { recursive: true })
    fs.writeFileSync(
      path.join(envPath, '.env.local'),
      'SPREE_API_URL=http://localhost:4567\nSPREE_PUBLISHABLE_KEY=pk_REPLACE_ME_AFTER_DOCKER_START\n',
    )

    updateStorefrontEnv(dir, 'pk_real_key')

    const content = fs.readFileSync(path.join(envPath, '.env.local'), 'utf-8')
    expect(content).toContain('SPREE_API_URL=http://localhost:4567')
    expect(content).toContain('SPREE_PUBLISHABLE_KEY=pk_real_key')
  })

  it('does nothing when .env.local does not exist', () => {
    const dir = makeTempDir()
    expect(() => updateStorefrontEnv(dir, 'pk_test')).not.toThrow()
  })
})

describe('spree init — service startup failure', () => {
  async function runInit(): Promise<void> {
    const program = new Command()
    registerInitCommand(program)
    await program.parseAsync(['init', '--no-open'], { from: 'user' })
  }

  beforeEach(() => {
    vi.clearAllMocks()
    // `pull` succeeds; `up -d` fails on a bound host port.
    vi.mocked(dockerCompose).mockImplementation((async (args: string[]) => {
      if (Array.isArray(args) && args[0] === 'up') throw new Error('port is already allocated')
      return undefined
    }) as never)
  })

  it('reports a port conflict and exits when services fail to start', async () => {
    vi.mocked(cancelOnPortConflict).mockResolvedValue(true)
    const exit = vi.spyOn(process, 'exit').mockImplementation(((code?: number) => {
      throw new ExitError(code ?? 0)
    }) as never)

    await expect(runInit()).rejects.toMatchObject({ code: 1 })
    expect(cancelOnPortConflict).toHaveBeenCalledWith('/proj')

    exit.mockRestore()
  })

  it('re-throws a startup failure that is not a port conflict', async () => {
    vi.mocked(cancelOnPortConflict).mockResolvedValue(false)

    await expect(runInit()).rejects.toThrow('port is already allocated')
  })
})
