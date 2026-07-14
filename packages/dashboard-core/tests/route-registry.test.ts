import { describe, expect, it } from 'vitest'
import { matchPluginRoute, type RouteEntry } from '../src/lib/route-registry'

function entry(key: string, path: string): RouteEntry {
  return { key, path, component: () => null }
}

describe('matchPluginRoute', () => {
  it('matches static segments exactly', () => {
    const routes = [entry('brands', '/brands')]
    expect(matchPluginRoute('brands', routes)?.entry.key).toBe('brands')
    expect(matchPluginRoute('/brands', routes)?.entry.key).toBe('brands')
    expect(matchPluginRoute('brand', routes)).toBeNull()
    expect(matchPluginRoute('brands/extra', routes)).toBeNull()
  })

  it('extracts $param segments', () => {
    const routes = [entry('brand-detail', '/brands/$brandId')]
    const match = matchPluginRoute('brands/br_123', routes)
    expect(match?.entry.key).toBe('brand-detail')
    expect(match?.params).toEqual({ brandId: 'br_123' })
  })

  it('prefers static patterns over $param patterns regardless of registration order', () => {
    const routes = [entry('brand-detail', '/brands/$brandId'), entry('brands-new', '/brands/new')]
    expect(matchPluginRoute('brands/new', routes)?.entry.key).toBe('brands-new')
    expect(matchPluginRoute('brands/br_123', routes)?.entry.key).toBe('brand-detail')
  })

  it('returns null when nothing matches', () => {
    expect(matchPluginRoute('unknown', [entry('brands', '/brands')])).toBeNull()
    expect(matchPluginRoute('', [entry('brands', '/brands')])).toBeNull()
  })
})
