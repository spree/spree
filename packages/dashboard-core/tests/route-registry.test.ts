import { afterEach, describe, expect, it } from 'vitest'
import {
  __resetPluginRoutes,
  getPluginRoutes,
  matchPluginRoute,
  pluginRoutes,
  type RouteEntry,
} from '../src/lib/route-registry'

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

  it('ignores routes mounted outside a store', () => {
    const routes: RouteEntry[] = [
      { key: 'sign-up', scope: 'public', path: '/sign-up', component: () => null },
      { key: 'account', scope: 'authenticated', path: '/account', component: () => null },
    ]
    expect(matchPluginRoute('sign-up', routes)).toBeNull()
    expect(matchPluginRoute('account', routes)).toBeNull()
  })

  it('returns null when nothing matches', () => {
    expect(matchPluginRoute('unknown', [entry('brands', '/brands')])).toBeNull()
    expect(matchPluginRoute('', [entry('brands', '/brands')])).toBeNull()
  })
})

describe('pluginRoutes.add', () => {
  afterEach(() => __resetPluginRoutes())

  it('registers routes of every scope', () => {
    pluginRoutes.add(entry('brands', '/brands'))
    pluginRoutes.add({ key: 'sign-up', scope: 'public', path: '/sign-up', component: () => null })
    expect(getPluginRoutes().map((route) => route.key)).toEqual(['brands', 'sign-up'])
  })

  it('rejects an unknown scope', () => {
    const route = { key: 'odd', scope: 'global', path: '/odd', component: () => null }
    expect(() => pluginRoutes.add(route as unknown as RouteEntry)).toThrow(/scope must be one of/)
  })
})
