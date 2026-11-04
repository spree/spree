import { afterEach, describe, expect, it, vi } from 'vitest'
import { randomUUID } from '../src'

const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/

describe('randomUUID', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('returns a version 4 UUID', () => {
    expect(randomUUID()).toMatch(UUID_V4)
  })

  it('falls back to getRandomValues when randomUUID is missing, as on plain-HTTP pages', () => {
    vi.stubGlobal('crypto', { getRandomValues: crypto.getRandomValues.bind(crypto) })

    const ids = new Set(Array.from({ length: 100 }, () => randomUUID()))

    expect(ids.size).toBe(100)
    for (const id of ids) expect(id).toMatch(UUID_V4)
  })
})
