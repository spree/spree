import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import {
  DEFAULT_SEEDS_FILE,
  parsePrune,
  parseSections,
  resolveSeedsFile,
} from '../src/commands/seed'

describe('spree seed', () => {
  const dirs: string[] = []
  afterEach(() => {
    for (const dir of dirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true })
  })

  it('reads spree.seeds.yml from the working directory outside a project', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-seed-'))
    dirs.push(dir)
    expect(resolveSeedsFile(undefined, dir)).toBe(path.join(dir, DEFAULT_SEEDS_FILE))
    expect(resolveSeedsFile('store.yml', dir)).toBe(path.join(dir, 'store.yml'))
  })

  it('refuses a section name the file does not have', () => {
    expect(parseSections('channels, products', '--include')).toEqual(['channels', 'products'])
    expect(() => parseSections('chanels', '--include')).toThrow('Unknown section in --include')
  })

  it('refuses to prune a section that may never be pruned', () => {
    expect(parsePrune('products')).toEqual(['products'])
    expect(() => parsePrune('store')).toThrow('cannot be pruned')
  })
})
