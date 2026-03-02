import { describe, it, expect, afterEach } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
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
})
