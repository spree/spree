import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'

/**
 * The env vars spree-starter reads Active Record encryption keys from (see its
 * config/application.rb). Spree encrypts webhook signing keys, gateway customer
 * ids and OAuth tokens at rest only when all three are configured.
 */
export const ENCRYPTION_ENV_VARS = [
  'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY',
  'ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY',
  'ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT',
] as const

export type EncryptionEnvVar = (typeof ENCRYPTION_ENV_VARS)[number]

const ALPHANUMERIC = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

/**
 * A random alphanumeric string — the format `bin/rails db:encryption:init`
 * prints (`SecureRandom.alphanumeric(32)` per value).
 */
export function randomAlphanumeric(length = 32): string {
  let result = ''
  for (let i = 0; i < length; i++) {
    result += ALPHANUMERIC[crypto.randomInt(ALPHANUMERIC.length)]
  }
  return result
}

/** A fresh set of the three Active Record encryption values. */
export function generateEncryptionKeys(): Record<EncryptionEnvVar, string> {
  return {
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY: randomAlphanumeric(),
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY: randomAlphanumeric(),
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT: randomAlphanumeric(),
  }
}

export function formatEncryptionEnv(keys: Record<EncryptionEnvVar, string>): string {
  return ENCRYPTION_ENV_VARS.map((name) => `${name}=${keys[name]}`).join('\n')
}

function assignmentPattern(name: string): RegExp {
  return new RegExp(`^[ \\t]*(?:export[ \\t]+)?${name}[ \\t]*=(.*)$`, 'm')
}

/** The encryption vars `.env` content already assigns a non-empty value. */
export function configuredEncryptionVars(content: string): EncryptionEnvVar[] {
  return ENCRYPTION_ENV_VARS.filter((name) => {
    const match = content.match(assignmentPattern(name))
    if (!match) return false
    const value = match[1].trim().replace(/^(['"])(.*)\1$/, '$2')
    return value.length > 0
  })
}

/**
 * Returns `.env` content with the given keys set. Empty assignments (e.g.
 * copied from `.env.example`) are filled in place; missing vars are appended.
 * Never call this for vars that already hold a value — see
 * `configuredEncryptionVars`.
 */
export function withEncryptionKeys(
  content: string,
  keys: Record<EncryptionEnvVar, string>,
): string {
  let result = content
  const append: EncryptionEnvVar[] = []

  for (const name of ENCRYPTION_ENV_VARS) {
    const pattern = assignmentPattern(name)
    if (pattern.test(result)) {
      result = result.replace(pattern, `${name}=${keys[name]}`)
    } else {
      append.push(name)
    }
  }

  if (append.length > 0) {
    if (result.length > 0 && !result.endsWith('\n')) result += '\n'
    result +=
      '# Active Record encryption — back these up; never change them once data is encrypted\n'
    result += `${append.map((name) => `${name}=${keys[name]}`).join('\n')}\n`
  }

  return result
}

/**
 * Whether the Rails app's config reads the encryption env vars. Projects
 * scaffolded from an older spree-starter don't, so setting the vars alone
 * would not enable encryption there.
 */
export function appReadsEncryptionEnv(apiDir: string): boolean {
  const configDir = path.join(apiDir, 'config')
  if (!fs.existsSync(configDir)) return false

  const stack = [configDir]
  while (stack.length > 0) {
    const dir = stack.pop() as string
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name)
      if (entry.isDirectory()) {
        stack.push(full)
      } else if (entry.name.endsWith('.rb')) {
        if (fs.readFileSync(full, 'utf-8').includes('ACTIVE_RECORD_ENCRYPTION_')) return true
      }
    }
  }
  return false
}

/** The snippet to add to config/application.rb in apps that don't read the vars yet. */
export const APPLICATION_RB_SNIPPET = `    %i[primary_key deterministic_key key_derivation_salt].each do |key|
      value = ENV["ACTIVE_RECORD_ENCRYPTION_#{key.upcase}"].presence ||
        credentials.dig(:active_record_encryption, key).presence
      config.active_record.encryption[key] = value if value
    end`
