import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { registerEjectCommand } from '../src/commands/eject'
import { dockerCompose, dockerComposeExec } from '../src/docker'

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
}))

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
  })

  afterEach(() => {
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
})
