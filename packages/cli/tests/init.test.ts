import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { mintCliCredentials, updateStorefrontEnv } from '../src/commands/init'
import { readProjectCredentials, writeProjectCredentials } from '../src/config'

describe('updateStorefrontEnv', () => {
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

describe('mintCliCredentials', () => {
  const tempDirs: string[] = []

  function makeTempDir(): string {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-mint-test-'))
    tempDirs.push(dir)
    return dir
  }

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true })
    }
    tempDirs.length = 0
  })

  // Reuses a stored key instead of minting (and orphaning one) on every run.
  // Reaching the rake call with no credentials present would throw — that this
  // resolves proves the existing token short-circuits before any minting.
  it('returns the existing token without minting a new key', async () => {
    const dir = makeTempDir()
    writeProjectCredentials(dir, {
      baseUrl: 'http://localhost:3000',
      token: 'sk_existing_token',
      scopes: ['read_all'],
      mintedAt: '2026-06-12T00:00:00Z',
    })

    await expect(mintCliCredentials(dir, 3000)).resolves.toBe('sk_existing_token')
  })

  // A port change between runs must not leave `spree api` pointed at the old
  // host: reuse the stored key but reconcile baseUrl to the current port.
  it('reconciles baseUrl to the current port while reusing the key', async () => {
    const dir = makeTempDir()
    writeProjectCredentials(dir, {
      baseUrl: 'http://localhost:3000',
      token: 'sk_existing_token',
      scopes: ['read_all'],
      mintedAt: '2026-06-12T00:00:00Z',
    })

    await expect(mintCliCredentials(dir, 4000)).resolves.toBe('sk_existing_token')

    const updated = readProjectCredentials(dir)
    expect(updated?.baseUrl).toBe('http://localhost:4000')
    expect(updated?.token).toBe('sk_existing_token')
    expect(updated?.mintedAt).toBe('2026-06-12T00:00:00Z')
  })
})
