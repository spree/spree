/**
 * Command usage reporting for the Spree command line tools, shared by
 * @spree/cli and create-spree-app and bundled into both.
 *
 * One event per run of a lifecycle command, sent when the run ends so it can
 * carry the outcome. A command outside the list, one whose output is not a
 * terminal (a script, a pipe, CI), or one started by another Spree command
 * returns before anything is sent.
 *
 * What is sent and how to turn it off:
 * https://spreecommerce.org/docs/developer/deployment/usage-data
 */
import { execFileSync, spawn } from 'node:child_process'
import { createHmac, randomBytes, randomUUID } from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

export const TELEMETRY_URL = 'https://spreecloud.io/cli-events'
export const USAGE_DATA_DOCS = 'https://spreecommerce.org/docs/developer/deployment/usage-data'

/**
 * The commands a person runs by hand. Everything else — `spree api`, `exec`,
 * `rails`, shell completion — runs in scripts and loops, and is never
 * reported. spreecloud.io records nothing else either.
 */
export const LIFECYCLE_COMMANDS = [
  'create',
  'init',
  'add',
  'dev',
  'upgrade',
  'eject',
  'build',
  'plugin',
  'generate',
] as const

// Set for every process a tracked command starts: create-spree-app runs
// `spree init` and `spree add` in the same terminal, and those runs are part
// of the scaffold, not something the person ran.
const NESTED_MARKER = 'SPREE_TELEMETRY_NESTED'

// The exit code a shell uses for a run stopped with Ctrl+C.
const INTERRUPTED = 130

export type CliName = '@spree/cli' | 'create-spree-app'
export type TelemetryOptions = Record<string, string | boolean>
type Env = Record<string, string | undefined>
type Config = Record<string, unknown>

export interface TelemetrySettings {
  enabled?: boolean
  machineId?: string
  /** Keys the project hash. Never sent, so the hash cannot be recomputed from a list of remotes. */
  projectKey?: string
  noticeShown?: boolean
}

/** The Spree tools' settings folder, also home to the CLI's saved credentials. */
export function configDir(env: Env = process.env): string {
  return env.XDG_CONFIG_HOME
    ? path.join(env.XDG_CONFIG_HOME, 'spree')
    : path.join(os.homedir(), '.config', 'spree')
}

function configFile(env: Env): string {
  return path.join(configDir(env), 'config.json')
}

// {} when there is no file yet, null when there is one that cannot be read.
function readConfig(env: Env): Config | null {
  try {
    const parsed = JSON.parse(fs.readFileSync(configFile(env), 'utf-8'))
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : null
  } catch (error) {
    return (error as NodeJS.ErrnoException).code === 'ENOENT' ? {} : null
  }
}

function settingsFrom(config: Config | null): TelemetrySettings {
  const settings = config?.telemetry
  return settings && typeof settings === 'object' ? (settings as TelemetrySettings) : {}
}

export function readTelemetrySettings(env: Env = process.env): TelemetrySettings {
  return settingsFrom(readConfig(env))
}

/**
 * Saves telemetry settings, keeping everything else in the file (the CLI's
 * credentials live there too).
 *
 * @throws Error when the file exists but cannot be read, so a caller never
 *   reports a setting as saved when it was not
 */
export function writeTelemetrySettings(
  changes: TelemetrySettings,
  env: Env = process.env,
  config: Config | null = readConfig(env),
): void {
  const file = configFile(env)
  if (!config) {
    throw new Error(
      `${file} is not valid JSON, so the setting was not saved. Fix or delete it and try again.`,
    )
  }

  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 })
  const next = { ...config, telemetry: { ...settingsFrom(config), ...changes } }
  fs.writeFileSync(file, `${JSON.stringify(next, null, 2)}\n`, { mode: 0o600 })
  fs.chmodSync(file, 0o600)
}

function flag(value: string | undefined): boolean {
  return value !== undefined && value !== '' && value !== '0' && value.toLowerCase() !== 'false'
}

/**
 * Why reporting is off, or null when it is on. Environment variables win over
 * the saved setting, so an operator can always turn it off, and a settings
 * file that cannot be read turns it off too: an opt-out saved there must
 * never be ignored.
 */
export function telemetryDisabledReason(
  env: Env = process.env,
  config: Config | null = readConfig(env),
): string | null {
  if (flag(env.SPREE_TELEMETRY_DISABLED)) return 'SPREE_TELEMETRY_DISABLED is set'
  if (flag(env.DO_NOT_TRACK)) return 'DO_NOT_TRACK is set'
  if (flag(env.CI)) return 'running in CI'
  if (flag(env[NESTED_MARKER])) return 'started by another Spree command'
  if (!config) return `${configFile(env)} cannot be read`
  if (settingsFrom(config).enabled === false) return 'turned off with `spree telemetry disable`'
  return null
}

let cancelled = false

/** Records that the person cancelled the run, for a command that then exits with 0. */
export function markCommandCancelled(): void {
  cancelled = true
}

function packageManager(env: Env): string | undefined {
  const agent = env.npm_config_user_agent ?? ''
  return ['pnpm', 'yarn', 'bun', 'npm'].find((name) => agent.startsWith(`${name}/`))
}

// The git remote, hashed with a random key that never leaves this machine:
// runs in one project on one machine match, and hashing a list of public
// repository addresses cannot find it.
function projectId(cwd: string, projectKey: string): string | undefined {
  try {
    const remote = execFileSync('git', ['config', '--get', 'remote.origin.url'], {
      cwd,
      stdio: ['ignore', 'pipe', 'ignore'],
      timeout: 500,
    })
      .toString()
      .trim()
    return remote ? createHmac('sha256', projectKey).update(remote).digest('hex') : undefined
  } catch {
    return undefined
  }
}

export interface CommandEvent {
  event: 'command' | 'create'
  command: string
  status: 'ok' | 'error' | 'cancelled'
  exit_code: number
  duration_ms: number
  cli: CliName
  cli_version: string
  node_version: string
  package_manager?: string
  os: string
  arch: string
  docker: boolean
  machine_id: string
  project_id?: string
  options?: TelemetryOptions
}

export function buildEvent(input: {
  cli: CliName
  cliVersion: string
  command: string
  exitCode: number
  cancelled?: boolean
  durationMs: number
  machineId: string
  projectId?: string
  options?: TelemetryOptions
  env?: Env
}): CommandEvent {
  const status =
    input.cancelled || input.exitCode === INTERRUPTED
      ? 'cancelled'
      : input.exitCode === 0
        ? 'ok'
        : 'error'

  return {
    event: input.command === 'create' ? 'create' : 'command',
    command: input.command,
    status,
    exit_code: input.exitCode,
    duration_ms: Math.round(input.durationMs),
    cli: input.cli,
    cli_version: input.cliVersion,
    node_version: process.versions.node,
    package_manager: packageManager(input.env ?? process.env),
    os: process.platform,
    arch: process.arch,
    docker: fs.existsSync('/.dockerenv'),
    machine_id: input.machineId,
    project_id: input.projectId,
    options: input.options && Object.keys(input.options).length > 0 ? input.options : undefined,
  }
}

// Sent by a detached child so the command exits at once and a slow or
// unreachable endpoint never holds it up. Its output goes nowhere and its
// failures are ignored.
const SEND_SCRIPT = `fetch(${JSON.stringify(TELEMETRY_URL)}, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: process.env.SPREE_TELEMETRY_EVENT,
  signal: AbortSignal.timeout(3000),
}).catch(() => {})`

export function sendEvent(event: CommandEvent): void {
  try {
    spawn(process.execPath, ['-e', SEND_SCRIPT], {
      detached: true,
      stdio: 'ignore',
      windowsHide: true,
      env: { ...process.env, SPREE_TELEMETRY_EVENT: JSON.stringify(event) },
    }).unref()
  } catch {
    // Reporting never fails a command.
  }
}

// Both tools point at the CLI: every project create-spree-app scaffolds
// installs it, and they share one settings file, so turning it off there
// covers both.
function printNotice(): void {
  process.stderr.write(
    [
      '',
      'Spree collects usage data about which commands run and whether they succeed,',
      'to see where setup goes wrong. It never includes your code, file names or',
      'personal data. Turn it off with `npx spree telemetry disable`.',
      `Details: ${USAGE_DATA_DOCS}`,
      '',
      '',
    ].join('\n'),
  )
}

export interface CommandTracking {
  /** Adds choices made during the command, such as create-spree-app's answers. */
  setOptions(options: TelemetryOptions): void
}

/**
 * Reports `command` when the run ends. Returns null, having sent nothing, when
 * the command is not a lifecycle command, the output is not a terminal,
 * reporting is turned off, or the settings cannot be saved (a run that cannot
 * keep its machine id would look like a new machine every time).
 */
export function trackCommand(input: {
  cli: CliName
  cliVersion: string
  command: string
  cwd?: string
  isTTY?: boolean
  env?: Env
  send?: (event: CommandEvent) => void
}): CommandTracking | null {
  const env = input.env ?? process.env
  if (!(LIFECYCLE_COMMANDS as readonly string[]).includes(input.command)) return null
  if (!(input.isTTY ?? process.stdout.isTTY)) return null

  const config = readConfig(env)
  if (telemetryDisabledReason(env, config) !== null) return null

  const settings = settingsFrom(config)
  const machineId = settings.machineId ?? randomUUID()
  const projectKey = settings.projectKey ?? randomBytes(32).toString('hex')
  if (!settings.machineId || !settings.projectKey || !settings.noticeShown) {
    try {
      writeTelemetrySettings({ machineId, projectKey, noticeShown: true }, env, config)
    } catch {
      return null
    }
    if (!settings.noticeShown) printNotice()
  }

  process.env[NESTED_MARKER] = '1'

  const startedAt = performance.now()
  let options: TelemetryOptions = {}
  let reported = false

  const report = (exitCode: number) => {
    if (reported) return
    reported = true
    ;(input.send ?? sendEvent)(
      buildEvent({
        cli: input.cli,
        cliVersion: input.cliVersion,
        command: input.command,
        exitCode,
        cancelled,
        durationMs: performance.now() - startedAt,
        machineId,
        projectId:
          input.command === 'create'
            ? undefined
            : projectId(input.cwd ?? process.cwd(), projectKey),
        options,
        env,
      }),
    )
  }

  // Node ends the process on Ctrl+C without an 'exit' event, so a run
  // abandoned that way would go unreported. A command with its own Ctrl+C
  // handling (`dev`, `init`) decides when to exit and the 'exit' event reports
  // it; otherwise this reports the run as cancelled, then lets Ctrl+C end the
  // process as it would have.
  const onInterrupt = () => {
    if (process.listenerCount('SIGINT') > 1) return
    process.removeListener('SIGINT', onInterrupt)
    report(INTERRUPTED)
    process.kill(process.pid, 'SIGINT')
  }

  process.once('exit', report)
  process.on('SIGINT', onInterrupt)

  return {
    setOptions(next) {
      options = { ...options, ...next }
    },
  }
}
