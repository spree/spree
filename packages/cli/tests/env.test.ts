import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { readPortFromEnv, readSampleDataFromEnv } from '../src/context'

describe('readPortFromEnv', () => {
  const tempDirs: string[] = []

  function makeTempDir(): string {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-env-test-'))
    tempDirs.push(dir)
    return dir
  }

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true })
    }
    tempDirs.length = 0
  })

  it('returns default port when .env is missing', () => {
    const dir = makeTempDir()
    expect(readPortFromEnv(dir)).toBe(3000)
  })

  it('reads SPREE_PORT from .env', () => {
    const dir = makeTempDir()
    fs.writeFileSync(path.join(dir, '.env'), 'SPREE_PORT=8080\n')
    expect(readPortFromEnv(dir)).toBe(8080)
  })

  it('ignores commented lines', () => {
    const dir = makeTempDir()
    fs.writeFileSync(path.join(dir, '.env'), '# SPREE_PORT=9999\nSPREE_PORT=5555\n')
    expect(readPortFromEnv(dir)).toBe(5555)
  })

  it('returns default when SPREE_PORT is not set', () => {
    const dir = makeTempDir()
    fs.writeFileSync(path.join(dir, '.env'), 'SECRET_KEY_BASE=abc\n')
    expect(readPortFromEnv(dir)).toBe(3000)
  })
})

describe('readSampleDataFromEnv', () => {
  const tempDirs: string[] = []

  function makeTempDir(): string {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-env-test-'))
    tempDirs.push(dir)
    return dir
  }

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true })
    }
    tempDirs.length = 0
  })

  it('defaults to true when .env is missing', () => {
    expect(readSampleDataFromEnv(makeTempDir())).toBe(true)
  })

  it('defaults to true when the flag is absent', () => {
    const dir = makeTempDir()
    fs.writeFileSync(path.join(dir, '.env'), 'SPREE_PORT=3000\n')
    expect(readSampleDataFromEnv(dir)).toBe(true)
  })

  it('honors an opt-out persisted by create-spree-app', () => {
    const dir = makeTempDir()
    fs.writeFileSync(path.join(dir, '.env'), 'SPREE_PORT=3000\nSPREE_SAMPLE_DATA=false\n')
    expect(readSampleDataFromEnv(dir)).toBe(false)
  })

  it('treats an explicit true as true', () => {
    const dir = makeTempDir()
    fs.writeFileSync(path.join(dir, '.env'), 'SPREE_SAMPLE_DATA=true\n')
    expect(readSampleDataFromEnv(dir)).toBe(true)
  })
})
