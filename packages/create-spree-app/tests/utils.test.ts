import net from 'node:net'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { run } from '../src/run'
import {
  detectPackageManager,
  findFreePort,
  generateEncryptionKeys,
  generateSecretKeyBase,
  installCommand,
  runCommand,
  storefrontPm,
} from '../src/utils'

vi.mock('../src/run', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/run')>()),
  run: vi.fn(),
}))

describe('detectPackageManager', () => {
  const originalEnv = process.env.npm_config_user_agent

  beforeEach(() => {
    process.env.npm_config_user_agent = originalEnv
    vi.mocked(run).mockReset()
  })

  it('respects an explicit yarn agent', async () => {
    process.env.npm_config_user_agent = 'yarn/1.22.0 npm/? node/v20.0.0'
    await expect(detectPackageManager()).resolves.toBe('yarn')
  })

  it('respects an explicit pnpm agent', async () => {
    process.env.npm_config_user_agent = 'pnpm/8.0.0 npm/? node/v20.0.0'
    await expect(detectPackageManager()).resolves.toBe('pnpm')
  })

  // An npm agent is the default runner (`npx create-spree-app`), not a
  // choice — prefer pnpm when installed.
  it('prefers pnpm over an npm agent when pnpm is installed', async () => {
    process.env.npm_config_user_agent = 'npm/10.0.0 node/v20.0.0'
    await expect(detectPackageManager()).resolves.toBe('pnpm')
    expect(run).toHaveBeenCalledWith('pnpm', ['--version'], { stdio: 'ignore' })
  })

  it('prefers pnpm when the agent is unknown', async () => {
    delete process.env.npm_config_user_agent
    await expect(detectPackageManager()).resolves.toBe('pnpm')
  })

  it('falls back to npm when pnpm is not installed', async () => {
    process.env.npm_config_user_agent = 'npm/10.0.0 node/v20.0.0'
    vi.mocked(run).mockRejectedValue(new Error('spawn pnpm ENOENT'))
    await expect(detectPackageManager()).resolves.toBe('npm')
  })
})

describe('generateSecretKeyBase', () => {
  it('returns a 128-character hex string', () => {
    const key = generateSecretKeyBase()
    expect(key).toMatch(/^[0-9a-f]{128}$/)
  })

  it('generates unique values', () => {
    const key1 = generateSecretKeyBase()
    const key2 = generateSecretKeyBase()
    expect(key1).not.toBe(key2)
  })
})

describe('generateEncryptionKeys', () => {
  it('returns 32-character alphanumeric values like db:encryption:init', () => {
    const keys = generateEncryptionKeys()
    for (const value of Object.values(keys)) {
      expect(value).toMatch(/^[A-Za-z0-9]{32}$/)
    }
  })

  it('generates distinct values', () => {
    const keys = generateEncryptionKeys()
    expect(new Set(Object.values(keys)).size).toBe(3)
    expect(generateEncryptionKeys().primaryKey).not.toBe(keys.primaryKey)
  })
})

describe('installCommand', () => {
  it('returns "npm install" for npm', () => {
    expect(installCommand('npm')).toBe('npm install')
  })

  it('returns "yarn" for yarn', () => {
    expect(installCommand('yarn')).toBe('yarn')
  })

  it('returns "pnpm install" for pnpm', () => {
    expect(installCommand('pnpm')).toBe('pnpm install')
  })
})

describe('runCommand', () => {
  it('returns "npx" for npm', () => {
    expect(runCommand('npm')).toBe('npx')
  })

  it('returns "yarn" for yarn', () => {
    expect(runCommand('yarn')).toBe('yarn')
  })

  it('returns "pnpm" for pnpm', () => {
    expect(runCommand('pnpm')).toBe('pnpm')
  })
})

describe('storefrontPm', () => {
  it('maps yarn to pnpm — corepack-managed yarn refuses the pnpm-pinned storefront', () => {
    expect(storefrontPm('yarn')).toBe('pnpm')
  })

  it('keeps npm and pnpm as-is', () => {
    expect(storefrontPm('npm')).toBe('npm')
    expect(storefrontPm('pnpm')).toBe('pnpm')
  })
})

describe('findFreePort', () => {
  it('skips a port something already listens on', async () => {
    const server = net.createServer()
    await new Promise<void>((resolve) => server.listen(0, resolve))
    const taken = (server.address() as net.AddressInfo).port
    try {
      expect(await findFreePort(taken, taken + 20)).not.toBe(taken)
    } finally {
      server.close()
    }
  })

  it('returns another free port when the whole range is taken', async () => {
    const server = net.createServer()
    await new Promise<void>((resolve) => server.listen(0, resolve))
    const taken = (server.address() as net.AddressInfo).port
    try {
      const port = await findFreePort(taken, taken)
      expect(port).not.toBe(taken)
      expect(port).toBeGreaterThan(0)
    } finally {
      server.close()
    }
  })

  it('never hands out the same port twice', async () => {
    const first = await findFreePort(40100, 40120)
    expect(await findFreePort(first, first + 20)).not.toBe(first)
  })

  it('picks a free port when asked for port 0', async () => {
    expect(await findFreePort(0, 0)).toBeGreaterThan(0)
  })
})
