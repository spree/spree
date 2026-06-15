import { describe, expect, it } from 'vitest'
import { completionCandidates } from '../src/commands/completion'

describe('completionCandidates', () => {
  it('suggests api verbs after `api`', () => {
    const out = completionCandidates(['api', ''])
    expect(out).toContain('get')
    expect(out).toContain('endpoints')
    expect(out).toContain('schema')
  })

  it('suggests resource paths from the bundled spec after a path-taking verb', () => {
    const out = completionCandidates(['api', 'get', ''])
    expect(out).toContain('/products')
    expect(out).toContain('/orders')
    // Nested/placeholder paths are excluded.
    expect(out.every((p) => !p.includes('{'))).toBe(true)
  })

  it('filters resource paths by the typed prefix', () => {
    const out = completionCandidates(['api', 'get', '/prod'])
    expect(out).toContain('/products')
    expect(out.every((p) => p.startsWith('/prod'))).toBe(true)
  })

  it('appends Ransack predicates to a -q attribute stem', () => {
    const out = completionCandidates(['api', 'get', '/products', '-q', 'name_'])
    expect(out).toContain('name_eq=')
    expect(out).toContain('name_cont=')
    expect(out.every((c) => c.startsWith('name_') && c.endsWith('='))).toBe(true)
  })

  it('suggests scope names by prefix', () => {
    const out = completionCandidates(['api-key', 'create', '--scopes', 'write_pr'])
    expect(out).toContain('write_products')
    expect(out).toContain('write_promotions')
  })

  it('returns nothing for an unknown context', () => {
    expect(completionCandidates(['api', 'status', 'xyz'])).toEqual([])
  })

  it('does NOT suggest predicates for an _-token outside a -q value position', () => {
    // A path segment like `/custom_fields` must not trigger predicate completion.
    expect(completionCandidates(['api', 'get', '/custom_fields'])).not.toContain(
      'custom_fields_eq=',
    )
  })

  it('does NOT suggest scopes outside a --scopes value position', () => {
    // `read_` typed as a bare arg shouldn't surface scope names.
    expect(completionCandidates(['api', 'get', 'read_orders'])).toEqual([])
  })

  it('completes the last value in a comma-joined --scopes list', () => {
    const out = completionCandidates(['api-key', 'create', '--scopes', 'read_all,write_pr'])
    expect(out).toContain('read_all,write_products')
    expect(out).toContain('read_all,write_promotions')
  })
})
