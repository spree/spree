import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { detectProject } from '../src/context'

describe('detectProject', () => {
  const tempDirs: string[] = []

  function makeTempDir(): string {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-test-'))
    tempDirs.push(dir)
    return dir
  }

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true })
    }
    tempDirs.length = 0
  })

  it('throws when docker-compose.yml is missing', () => {
    const dir = makeTempDir()
    expect(() => detectProject(dir)).toThrow('Not a Spree project directory')
  })

  it('returns docker mode when docker-compose.yml exists', () => {
    const dir = makeTempDir()
    fs.writeFileSync(path.join(dir, 'docker-compose.yml'), 'services:')
    const ctx = detectProject(dir)
    expect(ctx.mode).toBe('docker')
    expect(ctx.projectDir).toBe(dir)
  })

  it('reads port from .env file', () => {
    const dir = makeTempDir()
    fs.writeFileSync(path.join(dir, 'docker-compose.yml'), 'services:')
    fs.writeFileSync(path.join(dir, '.env'), 'SECRET_KEY_BASE=abc\nSPREE_PORT=4567\n')
    const ctx = detectProject(dir)
    expect(ctx.port).toBe(4567)
  })

  it('defaults to port 3000 when .env is missing', () => {
    const dir = makeTempDir()
    fs.writeFileSync(path.join(dir, 'docker-compose.yml'), 'services:')
    const ctx = detectProject(dir)
    expect(ctx.port).toBe(3000)
  })

  it('defaults to port 3000 when SPREE_PORT is not set', () => {
    const dir = makeTempDir()
    fs.writeFileSync(path.join(dir, 'docker-compose.yml'), 'services:')
    fs.writeFileSync(path.join(dir, '.env'), 'SECRET_KEY_BASE=abc\n')
    const ctx = detectProject(dir)
    expect(ctx.port).toBe(3000)
  })

  it('re-roots to the wrapper parent when run from backend/ of a create-spree-app wrapper', () => {
    const root = makeTempDir()
    const backend = path.join(root, 'backend')
    fs.mkdirSync(backend)
    // root: adjusted compose (marker in dev overlay), real .env
    fs.writeFileSync(path.join(root, 'docker-compose.yml'), 'services:\n  web:\n')
    fs.writeFileSync(
      path.join(root, 'docker-compose.dev.yml'),
      'services:\n  web:\n    volumes:\n      - ./backend:/rails\n',
    )
    fs.writeFileSync(path.join(root, '.env'), 'SECRET_KEY_BASE=abc\nSPREE_PORT=4001\n')
    // backend: stale leftover compose
    fs.writeFileSync(path.join(backend, 'docker-compose.yml'), 'services:\n  web:\n')

    const ctx = detectProject(backend)
    expect(ctx.projectDir).toBe(root)
    expect(ctx.port).toBe(4001) // port read from the ROOT .env, not backend/
  })

  it('does NOT re-root when the parent compose lacks the ./backend:/rails marker', () => {
    const root = makeTempDir()
    const backend = path.join(root, 'backend')
    fs.mkdirSync(backend)
    // parent has a compose but it's an unrelated project (no marker)
    fs.writeFileSync(
      path.join(root, 'docker-compose.yml'),
      'services:\n  web:\n    volumes:\n      - .:/rails\n',
    )
    fs.writeFileSync(path.join(backend, 'docker-compose.yml'), 'services:')

    const ctx = detectProject(backend)
    expect(ctx.projectDir).toBe(backend)
  })

  it('does NOT re-root a standalone dir named backend with no parent compose', () => {
    const root = makeTempDir()
    const backend = path.join(root, 'backend')
    fs.mkdirSync(backend)
    // no compose at parent; backend/ is a standalone starter checkout
    fs.writeFileSync(path.join(backend, 'docker-compose.yml'), 'services:')
    fs.writeFileSync(path.join(backend, 'docker-compose.dev.yml'), 'services:\n      - .:/rails\n')

    const ctx = detectProject(backend)
    expect(ctx.projectDir).toBe(backend)
  })
})
