import { describe, it, expect, beforeEach } from 'vitest'
import { detectPackageManager, generateSecretKeyBase, installCommand, runCommand } from '../src/utils'

describe('detectPackageManager', () => {
  const originalEnv = process.env.npm_config_user_agent

  beforeEach(() => {
    process.env.npm_config_user_agent = originalEnv
  })

  it('detects yarn', () => {
    process.env.npm_config_user_agent = 'yarn/1.22.0 npm/? node/v20.0.0'
    expect(detectPackageManager()).toBe('yarn')
  })

  it('detects pnpm', () => {
    process.env.npm_config_user_agent = 'pnpm/8.0.0 npm/? node/v20.0.0'
    expect(detectPackageManager()).toBe('pnpm')
  })

  it('defaults to npm', () => {
    process.env.npm_config_user_agent = 'npm/10.0.0 node/v20.0.0'
    expect(detectPackageManager()).toBe('npm')
  })

  it('defaults to npm when env var is missing', () => {
    delete process.env.npm_config_user_agent
    expect(detectPackageManager()).toBe('npm')
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
