import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { storefrontWholesaleChannel, updateStorefrontEnv } from '../src/commands/init'

const tempDirs: string[] = []

function makeTempDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-init-test-'))
  tempDirs.push(dir)
  return dir
}

// Creates a project dir whose storefront .env.local has the given content.
function makeProjectWithStorefrontEnv(content: string): string {
  const dir = makeTempDir()
  const storefrontDir = path.join(dir, 'apps', 'storefront')
  fs.mkdirSync(storefrontDir, { recursive: true })
  fs.writeFileSync(path.join(storefrontDir, '.env.local'), content)
  return dir
}

function readStorefrontEnv(dir: string): string {
  return fs.readFileSync(path.join(dir, 'apps', 'storefront', '.env.local'), 'utf-8')
}

afterEach(() => {
  for (const dir of tempDirs) {
    fs.rmSync(dir, { recursive: true, force: true })
  }
  tempDirs.length = 0
})

describe('updateStorefrontEnv', () => {
  it('replaces placeholder key with real API key', () => {
    const dir = makeProjectWithStorefrontEnv(
      'SPREE_API_URL=http://localhost:3000\nSPREE_PUBLISHABLE_KEY=pk_REPLACE_ME_AFTER_DOCKER_START\n',
    )

    updateStorefrontEnv(dir, 'pk_test_abc123')

    const content = readStorefrontEnv(dir)
    expect(content).toContain('SPREE_PUBLISHABLE_KEY=pk_test_abc123')
    expect(content).not.toContain('pk_REPLACE_ME_AFTER_DOCKER_START')
  })

  it('replaces any existing key value', () => {
    const dir = makeProjectWithStorefrontEnv(
      'SPREE_API_URL=http://localhost:3000\nSPREE_PUBLISHABLE_KEY=pk_old_key\n',
    )

    updateStorefrontEnv(dir, 'pk_new_key')

    expect(readStorefrontEnv(dir)).toContain('SPREE_PUBLISHABLE_KEY=pk_new_key')
  })

  it('preserves other env variables', () => {
    const dir = makeProjectWithStorefrontEnv(
      'SPREE_API_URL=http://localhost:4567\nSPREE_PUBLISHABLE_KEY=pk_REPLACE_ME_AFTER_DOCKER_START\n',
    )

    updateStorefrontEnv(dir, 'pk_real_key')

    const content = readStorefrontEnv(dir)
    expect(content).toContain('SPREE_API_URL=http://localhost:4567')
    expect(content).toContain('SPREE_PUBLISHABLE_KEY=pk_real_key')
  })

  it('does nothing when .env.local does not exist', () => {
    const dir = makeTempDir()
    expect(() => updateStorefrontEnv(dir, 'pk_test')).not.toThrow()
  })

  it('does not touch the wholesale channel opt-in', () => {
    const dir = makeProjectWithStorefrontEnv(
      'SPREE_PUBLISHABLE_KEY=pk_old\nSPREE_WHOLESALE_CHANNEL=wholesale\n',
    )

    updateStorefrontEnv(dir, 'pk_default')

    const content = readStorefrontEnv(dir)
    expect(content).toContain('SPREE_PUBLISHABLE_KEY=pk_default')
    expect(content).toContain('SPREE_WHOLESALE_CHANNEL=wholesale')
  })
})

describe('storefrontWholesaleChannel', () => {
  it('returns the channel code when SPREE_WHOLESALE_CHANNEL has a value', () => {
    const dir = makeProjectWithStorefrontEnv('SPREE_WHOLESALE_CHANNEL=wholesale\n')
    expect(storefrontWholesaleChannel(dir)).toBe('wholesale')
  })

  it('returns null when the variable is empty, commented, or absent', () => {
    expect(
      storefrontWholesaleChannel(makeProjectWithStorefrontEnv('SPREE_WHOLESALE_CHANNEL=\n')),
    ).toBeNull()
    expect(
      storefrontWholesaleChannel(
        makeProjectWithStorefrontEnv('# SPREE_WHOLESALE_CHANNEL=wholesale\n'),
      ),
    ).toBeNull()
    expect(
      storefrontWholesaleChannel(makeProjectWithStorefrontEnv('SPREE_PUBLISHABLE_KEY=pk_x\n')),
    ).toBeNull()
  })

  it('returns null when .env.local does not exist', () => {
    expect(storefrontWholesaleChannel(makeTempDir())).toBeNull()
  })
})
