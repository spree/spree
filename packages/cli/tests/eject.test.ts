import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, type Mock, vi } from 'vitest'
import { registerEjectCommand } from '../src/commands/eject'
import {
  buildAdminStylesheets,
  dockerCompose,
  dockerComposeExec,
  primeBundleVolume,
} from '../src/docker'
import { cancelOnPortConflict } from '../src/ports'
import { mockProcessExit } from './helpers/process-exit'

const COMPOSE_DEV_STALE = `x-app: &app
  build:
    context: ./backend
    dockerfile: Dockerfile
  volumes:
    - .:/rails
    - bundle_cache:/usr/local/bundle

services:
  web:
    <<: *app
    command: ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
volumes:
  bundle_cache:
`

const COMPOSE_DEV_FIXED = COMPOSE_DEV_STALE.replace('- .:/rails', '- ./backend:/rails')

let projectDir: string

vi.mock('../src/context', () => ({
  detectProject: () => ({ mode: 'project', projectDir, port: 3000 }),
}))

vi.mock('../src/docker', () => ({
  dockerCompose: vi.fn().mockResolvedValue(undefined),
  dockerComposeExec: vi.fn().mockResolvedValue(undefined),
  primeBundleVolume: vi.fn().mockResolvedValue(undefined),
  buildAdminStylesheets: vi.fn().mockResolvedValue(undefined),
}))

vi.mock('../src/ports', () => ({ cancelOnPortConflict: vi.fn() }))

function makeProject(devComposeContent: string): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-eject-test-'))
  fs.mkdirSync(path.join(dir, 'backend'))
  fs.writeFileSync(path.join(dir, 'docker-compose.yml'), 'services: {} # prebuilt-image compose\n')
  fs.writeFileSync(path.join(dir, 'docker-compose.dev.yml'), devComposeContent)
  return dir
}

async function runEject(): Promise<void> {
  const program = new Command()
  registerEjectCommand(program)
  await program.parseAsync(['eject'], { from: 'user' })
}

describe('spree eject', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockProcessExit()
  })

  afterEach(() => {
    // Restore the process.exit spy regardless of assertion outcome so it never
    // leaks into a later test.
    vi.restoreAllMocks()
    if (projectDir) {
      fs.rmSync(projectDir, { recursive: true, force: true })
      projectDir = ''
    }
  })

  it('repairs a stale .:/rails bind-mount in both compose files', async () => {
    projectDir = makeProject(COMPOSE_DEV_STALE)

    await runEject()

    const active = fs.readFileSync(path.join(projectDir, 'docker-compose.yml'), 'utf-8')
    const dev = fs.readFileSync(path.join(projectDir, 'docker-compose.dev.yml'), 'utf-8')
    expect(active).toContain('- ./backend:/rails')
    expect(active).not.toContain('- .:/rails')
    expect(dev).toContain('- ./backend:/rails')
    expect(dev).not.toContain('- .:/rails')
    // Named volumes are left untouched
    expect(active).toContain('- bundle_cache:/usr/local/bundle')
  })

  it('copies an already-correct dev compose verbatim', async () => {
    projectDir = makeProject(COMPOSE_DEV_FIXED)

    await runEject()

    const active = fs.readFileSync(path.join(projectDir, 'docker-compose.yml'), 'utf-8')
    const dev = fs.readFileSync(path.join(projectDir, 'docker-compose.dev.yml'), 'utf-8')
    expect(active).toBe(COMPOSE_DEV_FIXED)
    expect(dev).toBe(COMPOSE_DEV_FIXED)
  })

  it('brings the stack up and prepares the development database', async () => {
    projectDir = makeProject(COMPOSE_DEV_STALE)

    await runEject()

    expect(dockerCompose).toHaveBeenCalledWith(['up', '-d'], projectDir, { stdio: 'inherit' })
    expect(dockerComposeExec).toHaveBeenCalledWith(['bin/rails', 'db:prepare'], projectDir, {
      tty: false,
    })
  })

  it('compiles the admin stylesheet the bind-mount masks', async () => {
    projectDir = makeProject(COMPOSE_DEV_STALE)

    await runEject()

    // The image baked spree/admin/application.css into app/assets/builds, but
    // eject's ./backend bind-mount masks it — without this compile every admin
    // page 500s on the missing asset.
    expect(buildAdminStylesheets).toHaveBeenCalledWith(projectDir)
  })

  it('primes the bundle volume with web before the parallel up', async () => {
    projectDir = makeProject(COMPOSE_DEV_STALE)

    await runEject()

    expect(primeBundleVolume).toHaveBeenCalledWith(projectDir)
    // The primer must run before the parallel `up -d` so web wins the
    // cold-volume copy-up uncontended (no web/worker "file exists" race).
    const primeOrder = (primeBundleVolume as Mock).mock.invocationCallOrder[0]
    const upCall = (dockerCompose as Mock).mock.calls.findIndex(
      ([args]) => Array.isArray(args) && args.join(' ') === 'up -d',
    )
    expect(upCall).toBeGreaterThanOrEqual(0)
    expect(primeOrder).toBeLessThan((dockerCompose as Mock).mock.invocationCallOrder[upCall])
  })

  it('reports a port conflict and exits when the dev stack fails to come up', async () => {
    projectDir = makeProject(COMPOSE_DEV_STALE)
    vi.mocked(dockerCompose).mockRejectedValueOnce(new Error('port is already allocated'))
    vi.mocked(cancelOnPortConflict).mockResolvedValue(true)

    // Eject is the first command to publish the postgres host port, so a
    // collision surfaces here as a diagnosed conflict, not a raw stack trace.
    await expect(runEject()).rejects.toMatchObject({ code: 1 })
    expect(cancelOnPortConflict).toHaveBeenCalledWith(projectDir)
    // Bailed at the conflict — never reached db:prepare.
    expect(dockerComposeExec).not.toHaveBeenCalled()
  })

  it('re-throws a compose failure that is not a port conflict', async () => {
    projectDir = makeProject(COMPOSE_DEV_STALE)
    vi.mocked(dockerCompose).mockRejectedValueOnce(new Error('docker daemon not running'))
    vi.mocked(cancelOnPortConflict).mockResolvedValue(false)

    await expect(runEject()).rejects.toThrow('docker daemon not running')
  })
})
