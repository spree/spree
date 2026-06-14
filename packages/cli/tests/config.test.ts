import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { CredentialError, resolveCredentials, writeProjectCredentials } from '../src/config'

describe('resolveCredentials', () => {
  const tempDirs: string[] = []
  const savedEnv: Record<string, string | undefined> = {
    SPREE_BASE_URL: process.env.SPREE_BASE_URL,
    SPREE_API_KEY: process.env.SPREE_API_KEY,
    XDG_CONFIG_HOME: process.env.XDG_CONFIG_HOME,
  }

  function makeTempDir(): string {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-config-'))
    tempDirs.push(dir)
    return dir
  }

  /** Points the profile store at an isolated config home. */
  function isolateConfigHome(): string {
    const home = makeTempDir()
    process.env.XDG_CONFIG_HOME = home
    return home
  }

  function writeProfiles(home: string, config: unknown): void {
    const dir = path.join(home, 'spree')
    fs.mkdirSync(dir, { recursive: true })
    fs.writeFileSync(path.join(dir, 'config.json'), JSON.stringify(config))
  }

  afterEach(() => {
    for (const [key, value] of Object.entries(savedEnv)) {
      if (value === undefined) delete process.env[key]
      else process.env[key] = value
    }
    for (const dir of tempDirs) fs.rmSync(dir, { recursive: true, force: true })
    tempDirs.length = 0
  })

  it('resolves from SPREE_BASE_URL + SPREE_API_KEY env vars', async () => {
    isolateConfigHome()
    process.env.SPREE_BASE_URL = 'https://env.example.com'
    process.env.SPREE_API_KEY = 'sk_env_token_123'

    const creds = await resolveCredentials({}, { cwd: makeTempDir(), allowMint: false })

    expect(creds).toMatchObject({
      baseUrl: 'https://env.example.com',
      apiKey: 'sk_env_token_123',
      source: 'env',
    })
    expect(creds.tokenPrefix).toBe('sk_env_token')
  })

  it('defaults the host to the local dev server when only SPREE_API_KEY is set', async () => {
    isolateConfigHome()
    process.env.SPREE_API_KEY = 'sk_env_token_123'
    // SPREE_BASE_URL intentionally unset.

    const creds = await resolveCredentials({}, { cwd: makeTempDir(), allowMint: false })

    expect(creds).toMatchObject({
      baseUrl: 'http://localhost:3000',
      apiKey: 'sk_env_token_123',
      source: 'env',
    })
  })

  it('defaults the host to local dev for a bare --api-key flag', async () => {
    isolateConfigHome()
    const creds = await resolveCredentials(
      { apiKey: 'sk_flag_only' },
      { cwd: makeTempDir(), allowMint: false },
    )
    expect(creds).toMatchObject({
      baseUrl: 'http://localhost:3000',
      apiKey: 'sk_flag_only',
      source: 'flags',
    })
  })

  it('lets flags override env', async () => {
    isolateConfigHome()
    process.env.SPREE_BASE_URL = 'https://env.example.com'
    process.env.SPREE_API_KEY = 'sk_env_token_123'

    const creds = await resolveCredentials(
      { baseUrl: 'https://flag.example.com', apiKey: 'sk_flag_token' },
      { cwd: makeTempDir(), allowMint: false },
    )

    expect(creds).toMatchObject({
      baseUrl: 'https://flag.example.com',
      apiKey: 'sk_flag_token',
      source: 'flags',
    })
  })

  it('uses existing project credentials without minting', async () => {
    isolateConfigHome()
    const projectDir = makeTempDir()
    fs.writeFileSync(path.join(projectDir, 'docker-compose.yml'), 'services:')
    writeProjectCredentials(projectDir, {
      baseUrl: 'http://localhost:3000',
      token: 'sk_project_token',
      scopes: ['read_all'],
      mintedAt: '2026-06-12T00:00:00Z',
    })

    const creds = await resolveCredentials({}, { cwd: projectDir, allowMint: false })

    expect(creds).toMatchObject({
      baseUrl: 'http://localhost:3000',
      apiKey: 'sk_project_token',
      source: 'project',
      scopes: ['read_all'],
    })
  })

  it('an explicit --profile outranks env', async () => {
    const home = isolateConfigHome()
    writeProfiles(home, {
      defaultProfile: 'prod',
      profiles: { prod: { baseUrl: 'https://prod.example.com', token: 'sk_prod_token' } },
    })
    process.env.SPREE_API_KEY = 'sk_env_token'
    process.env.SPREE_BASE_URL = 'https://env.example.com'

    const creds = await resolveCredentials(
      { profile: 'prod' },
      { cwd: makeTempDir(), allowMint: false },
    )

    expect(creds).toMatchObject({
      baseUrl: 'https://prod.example.com',
      apiKey: 'sk_prod_token',
      source: 'profile',
      profileName: 'prod',
    })
  })

  it('falls back to the default profile when nothing else resolves', async () => {
    const home = isolateConfigHome()
    writeProfiles(home, {
      defaultProfile: 'staging',
      profiles: { staging: { baseUrl: 'https://staging.example.com', token: 'sk_staging' } },
    })

    const creds = await resolveCredentials({}, { cwd: makeTempDir(), allowMint: false })

    expect(creds).toMatchObject({ source: 'profile', profileName: 'staging' })
  })

  it('throws CredentialError for an unknown --profile', async () => {
    isolateConfigHome()
    await expect(
      resolveCredentials({ profile: 'nope' }, { cwd: makeTempDir(), allowMint: false }),
    ).rejects.toThrow(CredentialError)
  })

  // Security: SPREE_BASE_URL alone must never re-point a saved/minted key at an
  // arbitrary host. The key anchors its layer; only an explicit flag re-points.
  it('does NOT pair SPREE_BASE_URL with a profile key (no silent exfiltration)', async () => {
    const home = isolateConfigHome()
    writeProfiles(home, {
      defaultProfile: 'prod',
      profiles: { prod: { baseUrl: 'https://prod.example.com', token: 'sk_prod_secret' } },
    })
    process.env.SPREE_BASE_URL = 'https://attacker.example'

    const creds = await resolveCredentials({}, { cwd: makeTempDir(), allowMint: false })

    // The profile key stays paired with the profile host, not the env host.
    expect(creds.baseUrl).toBe('https://prod.example.com')
    expect(creds.apiKey).toBe('sk_prod_secret')
  })

  it('does NOT pair SPREE_BASE_URL with a project key', async () => {
    isolateConfigHome()
    const projectDir = makeTempDir()
    fs.writeFileSync(path.join(projectDir, 'docker-compose.yml'), 'services:')
    writeProjectCredentials(projectDir, {
      baseUrl: 'http://localhost:3000',
      token: 'sk_project_token',
      scopes: ['read_all'],
      mintedAt: '2026-06-12T00:00:00Z',
    })
    process.env.SPREE_BASE_URL = 'https://attacker.example'

    const creds = await resolveCredentials({}, { cwd: projectDir, allowMint: false })

    expect(creds.baseUrl).toBe('http://localhost:3000')
    expect(creds.apiKey).toBe('sk_project_token')
  })

  it('does NOT auto-mint when an explicit --base-url targets a different host', async () => {
    isolateConfigHome()
    const projectDir = makeTempDir()
    fs.writeFileSync(path.join(projectDir, 'docker-compose.yml'), 'services:')
    // allowMint defaults true; the foreign --base-url must still suppress minting.
    await expect(
      resolveCredentials({ baseUrl: 'https://prod.example.com' }, { cwd: projectDir }),
    ).rejects.toThrow(CredentialError)
    expect(fs.existsSync(path.join(projectDir, '.spree', 'credentials.json'))).toBe(false)
  })

  it('an explicit --base-url re-points a flag --api-key (the sanctioned cross-source mix)', async () => {
    isolateConfigHome()
    const creds = await resolveCredentials(
      { baseUrl: 'https://staging.example.com', apiKey: 'sk_flag' },
      { cwd: makeTempDir(), allowMint: false },
    )
    expect(creds).toMatchObject({
      baseUrl: 'https://staging.example.com',
      apiKey: 'sk_flag',
      source: 'flags',
    })
  })

  it('backs up a corrupt config.json instead of resolving it as empty', async () => {
    const home = isolateConfigHome()
    const dir = path.join(home, 'spree')
    fs.mkdirSync(dir, { recursive: true })
    fs.writeFileSync(path.join(dir, 'config.json'), '{ not json')

    // Reading must not throw, and must move the bad file aside.
    await expect(
      resolveCredentials({ profile: 'x' }, { cwd: makeTempDir(), allowMint: false }),
    ).rejects.toThrow(/Unknown profile/)
    expect(fs.existsSync(path.join(dir, 'config.json.bak'))).toBe(true)
  })

  it('throws CredentialError when nothing resolves', async () => {
    isolateConfigHome()
    await expect(resolveCredentials({}, { cwd: makeTempDir(), allowMint: false })).rejects.toThrow(
      /No Admin API credentials found/,
    )
  })

  it('writes project credentials with owner-only permissions', () => {
    const projectDir = makeTempDir()
    writeProjectCredentials(projectDir, {
      baseUrl: 'http://localhost:3000',
      token: 'sk_secret',
      scopes: ['read_all'],
      mintedAt: '2026-06-12T00:00:00Z',
    })

    const mode = fs.statSync(path.join(projectDir, '.spree', 'credentials.json')).mode & 0o777
    expect(mode).toBe(0o600)
  })
})
