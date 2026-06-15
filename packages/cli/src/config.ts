import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import pc from 'picocolors'
import { DEFAULT_SPREE_PORT } from './constants.js'
import { detectProject } from './context.js'
import { rakeTask } from './docker.js'

/** Host a flag/env key defaults to when none is given — the local dev server. */
const LOCAL_DEV_URL = `http://localhost:${DEFAULT_SPREE_PORT}`

/**
 * Credential resolution for `spree api` / `spree auth`.
 *
 * The API key anchors a layer: host and key resolve together per source, so a
 * saved/minted secret key is never paired with a host from another source. An
 * explicit `--base-url` (or `--api-key`) flag overrides the resolved field —
 * the only sanctioned cross-source mix, since the user typed it deliberately.
 *
 *   1. flags            --base-url / --api-key (and --profile, which selects a
 *                       saved profile explicitly and then outranks env)
 *   2. env              SPREE_API_KEY (+ SPREE_BASE_URL, defaulting to the
 *                       local dev server); SPREE_BASE_URL alone never pairs
 *                       with a lower-layer key
 *   3. project          .spree/credentials.json next to docker-compose.yml,
 *                       auto-minted (read_all) on first use via the dev stack
 *   4. profile          ~/.config/spree/config.json, default profile
 */

export interface CredentialFlags {
  baseUrl?: string
  apiKey?: string
  profile?: string
}

export type CredentialSource = 'flags' | 'env' | 'project' | 'profile'

export interface ResolvedCredentials {
  baseUrl: string
  apiKey: string
  source: CredentialSource
  profileName?: string
  /** First 12 chars of the key — safe to display. */
  tokenPrefix: string
  /** Known only for project-minted keys (profiles store the key opaquely). */
  scopes?: string[]
}

export interface ProfileEntry {
  baseUrl: string
  token: string
}

export interface CliConfig {
  defaultProfile?: string
  profiles: Record<string, ProfileEntry>
}

export interface ProjectCredentials {
  baseUrl: string
  token: string
  scopes: string[]
  mintedAt: string
}

/** Thrown for resolution/usage problems — mapped to exit code 2. */
export class CredentialError extends Error {}

export function configDir(): string {
  return process.env.XDG_CONFIG_HOME
    ? path.join(process.env.XDG_CONFIG_HOME, 'spree')
    : path.join(os.homedir(), '.config', 'spree')
}

export function configPath(): string {
  return path.join(configDir(), 'config.json')
}

/** True when a thrown fs error is "no such file" (vs a permission/IO fault). */
function isNotFound(error: unknown): boolean {
  return (error as NodeJS.ErrnoException)?.code === 'ENOENT'
}

export function readConfig(): CliConfig {
  let raw: string
  try {
    raw = fs.readFileSync(configPath(), 'utf-8')
  } catch (error) {
    if (isNotFound(error)) return { profiles: {} } // no config file yet — first run
    // A permission/IO fault is not "first run" — surface it rather than
    // silently starting fresh (which would later overwrite the unreadable file).
    throw error
  }

  try {
    const parsed = JSON.parse(raw) as Partial<CliConfig>
    return { ...parsed, profiles: parsed.profiles ?? {} }
  } catch {
    // The file exists but is corrupt. Back it up rather than silently
    // returning an empty config — otherwise the next `writeConfig` would
    // overwrite (and destroy) whatever profiles were in there.
    const backup = `${configPath()}.bak`
    try {
      fs.renameSync(configPath(), backup)
    } catch {
      // best effort
    }
    process.stderr.write(
      `${pc.yellow(`warning: ${configPath()} was not valid JSON; moved it to ${backup} and starting fresh.`)}\n`,
    )
    return { profiles: {} }
  }
}

export function writeConfig(config: CliConfig): void {
  fs.mkdirSync(configDir(), { recursive: true, mode: 0o700 })
  writeFilePrivate(configPath(), `${JSON.stringify(config, null, 2)}\n`)
}

/**
 * Writes a file readable only by the owner. `mode` on writeFileSync is
 * ignored when the file already exists, so chmod unconditionally afterward to
 * tighten any pre-existing (possibly world-readable) credential file.
 */
function writeFilePrivate(file: string, contents: string): void {
  fs.writeFileSync(file, contents, { mode: 0o600 })
  fs.chmodSync(file, 0o600)
}

export function projectCredentialsPath(projectDir: string): string {
  return path.join(projectDir, '.spree', 'credentials.json')
}

export function readProjectCredentials(projectDir: string): ProjectCredentials | null {
  let raw: string
  try {
    raw = fs.readFileSync(projectCredentialsPath(projectDir), 'utf-8')
  } catch (error) {
    if (isNotFound(error)) return null // not minted yet
    throw error // permission/IO fault — don't mask it as "mint a fresh key"
  }
  try {
    return JSON.parse(raw) as ProjectCredentials
  } catch {
    return null // corrupt file — fall back to re-mint
  }
}

export function writeProjectCredentials(projectDir: string, credentials: ProjectCredentials): void {
  const file = projectCredentialsPath(projectDir)
  const dir = path.dirname(file)
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 })
  // Make the directory self-ignoring so the minted key never gets committed,
  // independent of the project's own .gitignore vintage (the create-spree-app
  // entry only covers freshly scaffolded projects). Ensure a catch-all rule
  // even if a .gitignore already exists without one.
  ensureGitignoreCatchAll(path.join(dir, '.gitignore'))
  writeFilePrivate(file, `${JSON.stringify(credentials, null, 2)}\n`)
}

/** Ensures `.spree/.gitignore` ignores everything — creating it, or appending
 * a `*` rule if it exists without one — so credentials.json is never committed. */
function ensureGitignoreCatchAll(gitignorePath: string): void {
  let existing = ''
  try {
    existing = fs.readFileSync(gitignorePath, 'utf-8')
  } catch (error) {
    if (!isNotFound(error)) throw error
  }
  const hasCatchAll = existing.split('\n').some((line) => line.trim() === '*')
  if (hasCatchAll) return
  fs.writeFileSync(
    gitignorePath,
    existing && !existing.endsWith('\n') ? `${existing}\n*\n` : `${existing}*\n`,
  )
}

export function tokenPrefix(token: string): string {
  return token.slice(0, 12)
}

/**
 * Auto-mints a read-only secret key through the project's dev stack and
 * persists it in `.spree/credentials.json` (gitignored). Write scopes are
 * never minted implicitly — `spree api-key create --scopes write_...` is the
 * explicit path.
 */
async function mintProjectCredentials(
  projectDir: string,
  port: number,
): Promise<ProjectCredentials> {
  process.stderr.write(
    `${pc.dim('No credentials found — minting a read-only API key via the dev stack...')}\n`,
  )

  let stdout: string
  try {
    stdout = await rakeTask('spree:cli:create_api_key', projectDir, {
      NAME: '@spree/cli (auto)',
      KEY_TYPE: 'secret',
      SCOPES: 'read_all',
    })
  } catch (error) {
    const detail = error instanceof Error ? error.message.split('\n')[0] : String(error)
    throw new CredentialError(
      `Could not mint an API key via the dev stack. Is it running? Start it with \`spree dev\`.\n${pc.dim(detail)}`,
    )
  }

  const match = stdout.match(/sk_[A-Za-z0-9_-]+/)
  if (!match) {
    throw new CredentialError(
      'Could not mint an API key via the dev stack. Is it running? Start it with `spree dev`.',
    )
  }

  const credentials: ProjectCredentials = {
    baseUrl: `http://localhost:${port}`,
    token: match[0],
    scopes: ['read_all'],
    mintedAt: new Date().toISOString(),
  }
  writeProjectCredentials(projectDir, credentials)
  process.stderr.write(`${pc.dim(`Saved to .spree/credentials.json (scopes: read_all)`)}\n`)
  return credentials
}

export interface ResolveOptions {
  /** Mint a project key when inside a project with no credentials (default true). */
  allowMint?: boolean
  /** Working directory for project detection (tests). */
  cwd?: string
}

export async function resolveCredentials(
  flags: CredentialFlags,
  options: ResolveOptions = {},
): Promise<ResolvedCredentials> {
  const { allowMint = true, cwd = process.cwd() } = options
  const config = readConfig()

  // The KEY anchors a layer: each layer (other than flags) contributes its
  // token together with its own base URL, so a saved/minted secret key is
  // never paired with a host from a different trust domain. The only
  // sanctioned cross-layer mix is an explicit `--base-url`/`--api-key` flag,
  // which the user typed on purpose; those override whatever a layer resolved.
  const flagBaseUrl = flags.baseUrl
  const flagApiKey = flags.apiKey

  let resolved:
    | {
        baseUrl?: string
        apiKey: string
        source: CredentialSource
        profileName?: string
        scopes?: string[]
      }
    | undefined

  // Layer 1 — explicit --api-key flag.
  if (flagApiKey) {
    resolved = { apiKey: flagApiKey, source: 'flags' }
  }

  // --profile is an explicit selection of a saved profile; it outranks env.
  if (!resolved && flags.profile) {
    const profile = config.profiles[flags.profile]
    if (!profile) {
      throw new CredentialError(
        `Unknown profile "${flags.profile}". Run \`spree auth login --profile ${flags.profile}\` to create it.`,
      )
    }
    resolved = {
      baseUrl: profile.baseUrl,
      apiKey: profile.token,
      source: 'profile',
      profileName: flags.profile,
    }
  }

  // Layer 2 — environment. The pair is anchored on SPREE_API_KEY; SPREE_BASE_URL
  // alone never pairs with a lower-layer key (that was the exfiltration path).
  if (!resolved && process.env.SPREE_API_KEY) {
    resolved = {
      baseUrl: process.env.SPREE_BASE_URL,
      apiKey: process.env.SPREE_API_KEY,
      source: 'env',
    }
  }

  // Layer 3 — project credentials (auto-minted on first use). Skipped when an
  // explicit --base-url points somewhere other than this project, so a remote
  // command never silently mints a local key.
  if (!resolved) {
    let projectDir: string | undefined
    let port = 0
    try {
      const ctx = detectProject(cwd)
      projectDir = ctx.projectDir
      port = ctx.port
    } catch {
      // not a Spree project directory — fall through
    }

    if (projectDir) {
      const projectUrl = `http://localhost:${port}`
      const targetsThisProject = !flagBaseUrl || flagBaseUrl.replace(/\/$/, '') === projectUrl
      let credentials = readProjectCredentials(projectDir)
      if (!credentials && allowMint && targetsThisProject) {
        credentials = await mintProjectCredentials(projectDir, port)
      }
      if (credentials) {
        resolved = {
          baseUrl: credentials.baseUrl,
          apiKey: credentials.token,
          source: 'project',
          scopes: credentials.scopes,
        }
      }
    }
  }

  // Layer 4 — default profile.
  if (!resolved && config.defaultProfile) {
    const profile = config.profiles[config.defaultProfile]
    if (profile) {
      resolved = {
        baseUrl: profile.baseUrl,
        apiKey: profile.token,
        source: 'profile',
        profileName: config.defaultProfile,
      }
    }
  }

  // An explicit --base-url always wins (re-point a key at staging, etc.); a
  // flag pairing is the user's deliberate cross-layer mix.
  let baseUrl = flagBaseUrl ?? resolved?.baseUrl
  const apiKey = resolved?.apiKey

  // Local-dev convenience: a key supplied via flag or env with no host at all
  // defaults to the local dev server, so `SPREE_API_KEY=sk_… spree api get …`
  // just works. Profile/project sources always carry their own host, so this
  // never silently re-points a saved remote key.
  if (!baseUrl && (resolved?.source === 'flags' || resolved?.source === 'env')) {
    baseUrl = LOCAL_DEV_URL
  }

  if (!baseUrl || !apiKey) {
    throw new CredentialError(
      [
        'No Admin API credentials found. Provide them via one of (host and key resolve together per source):',
        '  - flags:      --api-key <sk_...> (host defaults to ' +
          LOCAL_DEV_URL +
          '; pass --base-url for a remote store)',
        '  - env:        SPREE_API_KEY (host defaults to ' +
          LOCAL_DEV_URL +
          '; set SPREE_BASE_URL for a remote store)',
        '  - project:    run inside a Spree project with the dev stack up (auto-mints a read-only key)',
        '  - profile:    spree auth login --profile <name>',
      ].join('\n'),
    )
  }

  return {
    baseUrl,
    apiKey,
    source: resolved?.source ?? 'flags',
    profileName: resolved?.profileName,
    tokenPrefix: tokenPrefix(apiKey),
    scopes: resolved?.scopes,
  }
}
