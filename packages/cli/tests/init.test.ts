import { describe, it, expect, afterEach } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import { updateStorefrontEnv } from '../src/commands/init'

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
