import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { initEncryption } from '../src/commands/encryption'
import {
  appReadsEncryptionEnv,
  configuredEncryptionVars,
  credentialsFiles,
  ENCRYPTION_ENV_VARS,
  formatEncryptionEnv,
  generateEncryptionKeys,
  randomAlphanumeric,
  withEncryptionKeys,
} from '../src/lib/encryption'

vi.mock('@clack/prompts', () => ({
  log: { success: vi.fn(), warn: vi.fn(), info: vi.fn() },
  note: vi.fn(),
}))

const tempDirs: string[] = []

function makeTempDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-encryption-test-'))
  tempDirs.push(dir)
  return dir
}

afterEach(() => {
  for (const dir of tempDirs) {
    fs.rmSync(dir, { recursive: true, force: true })
  }
  tempDirs.length = 0
})

const keys = {
  ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY: 'primary',
  ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY: 'deterministic',
  ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT: 'salt',
}

describe('generateEncryptionKeys', () => {
  it('generates 32-character alphanumeric values like db:encryption:init', () => {
    const generated = generateEncryptionKeys()
    for (const name of ENCRYPTION_ENV_VARS) {
      expect(generated[name]).toMatch(/^[A-Za-z0-9]{32}$/)
    }
  })

  it('generates distinct values', () => {
    const generated = generateEncryptionKeys()
    expect(new Set(Object.values(generated)).size).toBe(3)
    expect(randomAlphanumeric()).not.toBe(randomAlphanumeric())
  })

  it('formats as env assignments', () => {
    expect(formatEncryptionEnv(keys)).toBe(
      'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=primary\n' +
        'ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=deterministic\n' +
        'ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=salt',
    )
  })
})

describe('configuredEncryptionVars', () => {
  it('ignores empty, quoted-empty and commented assignments', () => {
    const content =
      'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=\n' +
      'ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=""\n' +
      '# ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=abc\n'
    expect(configuredEncryptionVars(content)).toEqual([])
  })

  it('treats a whitespace-prefixed inline comment as an empty value', () => {
    const content =
      'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY= # add later\n' +
      'ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=abc # set\n' +
      'ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT="a #b"\n'
    expect(configuredEncryptionVars(content)).toEqual([
      'ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY',
      'ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT',
    ])
  })

  it('detects set values, including export-prefixed ones', () => {
    const content =
      'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=abc\nexport ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=def\n'
    expect(configuredEncryptionVars(content)).toEqual([
      'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY',
      'ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT',
    ])
  })
})

describe('withEncryptionKeys', () => {
  it('appends the keys, keeping existing content', () => {
    const result = withEncryptionKeys('SECRET_KEY_BASE=abc', keys)
    expect(result).toMatch(/^SECRET_KEY_BASE=abc\n# Active Record encryption/)
    expect(result).toContain(`${formatEncryptionEnv(keys)}\n`)
  })

  it('fills empty assignments in place instead of duplicating them', () => {
    const result = withEncryptionKeys(
      'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=\nSPREE_PORT=3000\n',
      keys,
    )
    expect(result.match(/ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=/g)).toHaveLength(1)
    expect(result).toMatch(/^ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=primary\nSPREE_PORT=3000\n/)
    expect(result).toContain('ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=salt')
  })
})

describe('initEncryption', () => {
  it('writes generated keys to the project .env', () => {
    const dir = makeTempDir()
    fs.writeFileSync(path.join(dir, '.env'), 'SECRET_KEY_BASE=abc\n')

    initEncryption(dir)

    const env = fs.readFileSync(path.join(dir, '.env'), 'utf-8')
    expect(env).toContain('SECRET_KEY_BASE=abc')
    for (const name of ENCRYPTION_ENV_VARS) {
      expect(env).toMatch(new RegExp(`^${name}=[A-Za-z0-9]{32}$`, 'm'))
    }
  })

  it('creates a missing .env owner-only', () => {
    const dir = makeTempDir()

    initEncryption(dir)

    const env = fs.readFileSync(path.join(dir, '.env'), 'utf-8')
    expect(env).toMatch(/^ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=[A-Za-z0-9]{32}$/m)
    if (process.platform !== 'win32') {
      expect(fs.statSync(path.join(dir, '.env')).mode & 0o777).toBe(0o600)
    }
  })

  it('leaves .env unchanged when the app has Rails credentials', () => {
    const dir = makeTempDir()
    fs.mkdirSync(path.join(dir, 'server', 'config'), { recursive: true })
    fs.writeFileSync(path.join(dir, 'server', 'config', 'credentials.yml.enc'), 'x')
    fs.writeFileSync(path.join(dir, '.env'), 'SECRET_KEY_BASE=abc\n')

    initEncryption(dir)

    expect(fs.readFileSync(path.join(dir, '.env'), 'utf-8')).toBe('SECRET_KEY_BASE=abc\n')
  })

  it('never overwrites existing keys', () => {
    const dir = makeTempDir()
    const original = 'SECRET_KEY_BASE=abc\nACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=keep-me\n'
    fs.writeFileSync(path.join(dir, '.env'), original)

    initEncryption(dir)

    expect(fs.readFileSync(path.join(dir, '.env'), 'utf-8')).toBe(original)
  })
})

describe('credentialsFiles', () => {
  it('lists the app credentials files', () => {
    const dir = makeTempDir()
    fs.mkdirSync(path.join(dir, 'config', 'credentials'), { recursive: true })
    expect(credentialsFiles(dir)).toEqual([])
    fs.writeFileSync(path.join(dir, 'config', 'credentials.yml.enc'), 'x')
    fs.writeFileSync(path.join(dir, 'config', 'credentials', 'production.yml.enc'), 'x')
    expect(credentialsFiles(dir)).toEqual([
      'config/credentials.yml.enc',
      'config/credentials/production.yml.enc',
    ])
  })
})

describe('appReadsEncryptionEnv', () => {
  it('is false for an app without the env config', () => {
    const dir = makeTempDir()
    fs.mkdirSync(path.join(dir, 'config', 'initializers'), { recursive: true })
    fs.writeFileSync(path.join(dir, 'config', 'application.rb'), 'module App; end\n')
    expect(appReadsEncryptionEnv(dir)).toBe(false)
  })

  it('is true when any config file reads the env vars', () => {
    const dir = makeTempDir()
    fs.mkdirSync(path.join(dir, 'config', 'initializers'), { recursive: true })
    fs.writeFileSync(
      path.join(dir, 'config', 'initializers', 'encryption.rb'),
      'ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]\n',
    )
    expect(appReadsEncryptionEnv(dir)).toBe(true)
  })
})
