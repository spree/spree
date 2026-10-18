import { execFileSync } from 'node:child_process'
import { createHash, createHmac } from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  buildEvent,
  type CommandEvent,
  readTelemetrySettings,
  telemetryDisabledReason,
  trackCommand,
  writeTelemetrySettings,
} from '../src/index'

describe('telemetry', () => {
  let home: string
  let env: Record<string, string | undefined>
  let onExit: ((code: number) => void) | undefined
  let onInterrupt: (() => void) | undefined
  let stderr: ReturnType<typeof vi.spyOn>
  const sent: CommandEvent[] = []

  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-telemetry-'))
    env = { XDG_CONFIG_HOME: home, npm_config_user_agent: 'pnpm/11.1.1 npm/? node/v24.4.0' }
    onExit = undefined
    onInterrupt = undefined
    sent.length = 0
    vi.spyOn(process, 'once').mockImplementation(((
      event: string,
      handler: (code: number) => void,
    ) => {
      if (event === 'exit') onExit = handler
      return process
    }) as typeof process.once)
    vi.spyOn(process, 'on').mockImplementation(((event: string, handler: () => void) => {
      if (event === 'SIGINT') onInterrupt = handler
      return process
    }) as typeof process.on)
    vi.spyOn(process, 'removeListener').mockImplementation(
      (() => process) as typeof process.removeListener,
    )
    stderr = vi.spyOn(process.stderr, 'write').mockImplementation(() => true)
  })

  afterEach(() => {
    vi.restoreAllMocks()
    delete process.env.SPREE_TELEMETRY_NESTED
    fs.rmSync(home, { recursive: true, force: true })
  })

  const configFile = () => path.join(home, 'spree', 'config.json')

  function writeConfigFile(contents: string) {
    fs.mkdirSync(path.join(home, 'spree'), { recursive: true })
    fs.writeFileSync(configFile(), contents)
  }

  function track(
    command: string,
    overrides: { isTTY?: boolean; cli?: '@spree/cli' | 'create-spree-app' } = {},
  ) {
    return trackCommand({
      cli: overrides.cli ?? '@spree/cli',
      cliVersion: '1.2.3',
      command,
      cwd: home,
      isTTY: overrides.isTTY ?? true,
      env,
      send: (event) => sent.push(event),
    })
  }

  describe('what is never reported', () => {
    it('ignores commands scripts run, without touching the config file', () => {
      for (const command of ['api', 'exec', 'rails', 'completion', 'telemetry']) {
        expect(track(command)).toBeNull()
      }

      expect(fs.existsSync(configFile())).toBe(false)
      expect(onExit).toBeUndefined()
    })

    it('ignores a lifecycle command whose output is not a terminal', () => {
      expect(track('dev', { isTTY: false })).toBeNull()
      expect(fs.existsSync(configFile())).toBe(false)
    })

    it.each([
      ['SPREE_TELEMETRY_DISABLED', '1'],
      ['DO_NOT_TRACK', 'true'],
      ['CI', 'true'],
    ])('stays silent when %s is set', (name, value) => {
      env[name] = value

      expect(track('dev')).toBeNull()
      expect(fs.existsSync(configFile())).toBe(false)
    })

    it('treats 0 and false as not set', () => {
      env.DO_NOT_TRACK = '0'
      env.CI = 'false'

      expect(telemetryDisabledReason(env)).toBeNull()
    })

    it('stays silent in a command another tracked command started', () => {
      expect(track('create', { cli: 'create-spree-app' })).not.toBeNull()
      expect(process.env.SPREE_TELEMETRY_NESTED).toBe('1')

      env.SPREE_TELEMETRY_NESTED = process.env.SPREE_TELEMETRY_NESTED
      expect(track('init')).toBeNull()
    })

    it('stays silent when the settings file cannot be read, so a saved opt-out is never ignored', () => {
      writeConfigFile('{ not json')

      expect(track('dev')).toBeNull()
      expect(fs.readFileSync(configFile(), 'utf-8')).toBe('{ not json')
    })

    it('stays silent when the settings cannot be saved, rather than reporting a new machine every run', () => {
      vi.spyOn(fs, 'writeFileSync').mockImplementation(() => {
        throw Object.assign(new Error('EACCES'), { code: 'EACCES' })
      })

      expect(track('dev')).toBeNull()
      expect(stderr).not.toHaveBeenCalled()
    })

    it('stays off after `spree telemetry disable`', () => {
      writeTelemetrySettings({ enabled: false }, env)

      expect(track('dev')).toBeNull()
    })
  })

  describe('a lifecycle command from a terminal', () => {
    it('shows the notice once and keeps one machine id', () => {
      track('dev')
      track('init')

      const settings = readTelemetrySettings(env)
      expect(settings.machineId).toMatch(/^[0-9a-f-]{36}$/)
      expect(settings.noticeShown).toBe(true)
      expect(stderr).toHaveBeenCalledTimes(1)
      expect(String(stderr.mock.calls[0]?.[0])).toContain('npx spree telemetry disable')
    })

    it('keeps the saved API credentials in the shared settings file, readable only by the owner', () => {
      writeConfigFile(
        JSON.stringify({
          defaultProfile: 'prod',
          profiles: { prod: { baseUrl: 'x', token: 'sk_1' } },
        }),
      )

      track('dev')

      const config = JSON.parse(fs.readFileSync(configFile(), 'utf-8'))
      expect(config.profiles.prod.token).toBe('sk_1')
      expect(config.defaultProfile).toBe('prod')
      expect(fs.statSync(configFile()).mode & 0o777).toBe(0o600)
    })

    it('reports the outcome when the process exits', () => {
      const tracking = track('add')
      tracking?.setOptions({ app: 'dashboard' })

      onExit?.(1)
      onExit?.(1)

      expect(sent).toHaveLength(1)
      expect(sent[0]).toMatchObject({
        event: 'command',
        command: 'add',
        status: 'error',
        exit_code: 1,
        cli: '@spree/cli',
        cli_version: '1.2.3',
        package_manager: 'pnpm',
        machine_id: readTelemetrySettings(env).machineId,
        options: { app: 'dashboard' },
      })
      expect(sent[0]?.duration_ms).toBeGreaterThanOrEqual(0)
    })

    it('hashes the git remote with a key that is never sent, so it cannot be matched against public repositories', () => {
      const remote = 'https://github.com/acme/shop.git'
      execFileSync('git', ['init', '-q'], { cwd: home })
      execFileSync('git', ['remote', 'add', 'origin', remote], { cwd: home })

      track('dev')
      onExit?.(0)

      const projectId = sent[0]?.project_id
      expect(projectId).toMatch(/^[0-9a-f]{64}$/)
      expect(projectId).not.toBe(createHash('sha256').update(remote).digest('hex'))
      expect(projectId).not.toBe(
        createHmac('sha256', String(sent[0]?.machine_id)).update(remote).digest('hex'),
      )
      expect(JSON.stringify(sent[0])).not.toContain(readTelemetrySettings(env).projectKey)
      expect(JSON.stringify(sent[0])).not.toContain('acme')
    })

    it('reports Ctrl+C as cancelled, then ends the process as Ctrl+C would have', () => {
      const kill = vi.spyOn(process, 'kill').mockImplementation(() => true)
      vi.spyOn(process, 'listenerCount').mockReturnValue(1)
      track('upgrade')

      onInterrupt?.()

      expect(sent).toHaveLength(1)
      expect(sent[0]).toMatchObject({ status: 'cancelled', exit_code: 130 })
      expect(kill).toHaveBeenCalledWith(process.pid, 'SIGINT')
    })

    it('leaves Ctrl+C to a command that handles it itself', () => {
      const kill = vi.spyOn(process, 'kill').mockImplementation(() => true)
      vi.spyOn(process, 'listenerCount').mockReturnValue(2)
      track('dev')

      onInterrupt?.()

      expect(sent).toHaveLength(0)
      expect(kill).not.toHaveBeenCalled()
    })
  })

  describe('writeTelemetrySettings', () => {
    it('refuses to report a setting saved when the file cannot be read', () => {
      writeConfigFile('{ not json')

      expect(() => writeTelemetrySettings({ enabled: false }, env)).toThrow(/not valid JSON/)
      expect(fs.readFileSync(configFile(), 'utf-8')).toBe('{ not json')
    })
  })

  describe('buildEvent', () => {
    const base = {
      cli: 'create-spree-app' as const,
      cliVersion: '1.0.0',
      exitCode: 0,
      durationMs: 12.6,
      machineId: 'm',
      env: {},
    }

    it('names a scaffold a create event', () => {
      expect(buildEvent({ ...base, command: 'create' })).toMatchObject({
        event: 'create',
        status: 'ok',
        duration_ms: 13,
      })
    })

    it('reports a cancelled run as cancelled even when it exits with 0', () => {
      expect(buildEvent({ ...base, command: 'create', cancelled: true }).status).toBe('cancelled')
      expect(buildEvent({ ...base, command: 'init', exitCode: 130 }).status).toBe('cancelled')
    })

    it('omits empty options', () => {
      expect(buildEvent({ ...base, command: 'init', options: {} })).not.toHaveProperty(
        'options',
        {},
      )
    })
  })
})
