import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { assertNoRouteCollisions, type RouteSource } from './route-collisions'

describe('assertNoRouteCollisions', () => {
  let root: string

  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'route-collision-'))
  })
  afterEach(() => {
    fs.rmSync(root, { recursive: true, force: true })
  })

  function makeSource(label: string, routes: Record<string, string>): RouteSource {
    const dir = path.join(root, label.replace(/[^a-z0-9]/gi, '_'))
    fs.mkdirSync(dir, { recursive: true })
    for (const [file, routePath] of Object.entries(routes)) {
      fs.writeFileSync(
        path.join(dir, file),
        `import { createFileRoute } from '@tanstack/react-router'\n` +
          `export const Route = createFileRoute('${routePath}')({ component: () => null })\n`,
      )
    }
    return { label, routesDir: dir }
  }

  it('passes when every route path is unique across sources', () => {
    const sources = [
      makeSource('@spree/dashboard', { 'products.tsx': '/_authenticated/$storeId/products/' }),
      makeSource('@acme/brands', { 'brands.index.tsx': '/_authenticated/$storeId/brands/' }),
    ]
    expect(() => assertNoRouteCollisions(sources)).not.toThrow()
  })

  it('throws naming both packages and the path on a cross-plugin collision', () => {
    const sources = [
      makeSource('@acme/brands', { 'brands.index.tsx': '/_authenticated/$storeId/brands/' }),
      makeSource('@other/brands', { 'b.tsx': '/_authenticated/$storeId/brands/' }),
    ]
    expect(() => assertNoRouteCollisions(sources)).toThrow(/@acme\/brands/)
    expect(() => assertNoRouteCollisions(sources)).toThrow(/@other\/brands/)
    expect(() => assertNoRouteCollisions(sources)).toThrow(/\/_authenticated\/\$storeId\/brands\//)
  })

  it('catches a plugin colliding with a built-in shell route', () => {
    const sources = [
      makeSource('@spree/dashboard', { 'products.tsx': '/_authenticated/$storeId/products/' }),
      makeSource('@acme/rogue', { 'p.tsx': '/_authenticated/$storeId/products/' }),
    ]
    expect(() => assertNoRouteCollisions(sources)).toThrow(/@spree\/dashboard/)
    expect(() => assertNoRouteCollisions(sources)).toThrow(/@acme\/rogue/)
  })

  it('ignores duplicate paths within a single source (generator reports those)', () => {
    const sources = [
      makeSource('@acme/brands', {
        'brands.index.tsx': '/_authenticated/$storeId/brands/',
        'brands.copy.tsx': '/_authenticated/$storeId/brands/',
      }),
    ]
    expect(() => assertNoRouteCollisions(sources)).not.toThrow()
  })

  it('ignores non-route files and missing directories', () => {
    const dir = path.join(root, 'plugin')
    fs.mkdirSync(dir)
    fs.writeFileSync(path.join(dir, 'helper.ts'), 'export const x = 1\n')
    const sources: RouteSource[] = [
      { label: '@acme/brands', routesDir: dir },
      { label: '@acme/gone', routesDir: path.join(root, 'does-not-exist') },
    ]
    expect(() => assertNoRouteCollisions(sources)).not.toThrow()
  })

  it('scans nested route directories', () => {
    const dir = path.join(root, 'nested')
    fs.mkdirSync(path.join(dir, 'sub'), { recursive: true })
    fs.writeFileSync(
      path.join(dir, 'sub', 'deep.tsx'),
      `import { createFileRoute } from '@tanstack/react-router'\n` +
        `export const Route = createFileRoute('/_authenticated/$storeId/deep/')({})\n`,
    )
    const other = makeSource('@other/deep', { 'd.tsx': '/_authenticated/$storeId/deep/' })
    expect(() =>
      assertNoRouteCollisions([{ label: '@acme/nested', routesDir: dir }, other]),
    ).toThrow(/@acme\/nested/)
  })

  it('catches a root page claiming a built-in shell page', () => {
    const sources = [
      makeSource('@spree/dashboard', { 'login.tsx': '/login' }),
      makeSource('@acme/onboarding', { 'login.tsx': '/login' }),
    ]
    expect(() => assertNoRouteCollisions(sources)).toThrow(/Route "\/login"/)
  })

  it('compares the URL a route serves, ignoring pathless layouts', () => {
    const sources = [
      makeSource('@acme/account', { 'account.tsx': '/_authenticated/account' }),
      makeSource('@other/account', { 'account.tsx': '/account' }),
    ]
    expect(() => assertNoRouteCollisions(sources)).toThrow(/Route "\/account"/)
    expect(() => assertNoRouteCollisions(sources)).toThrow(/"\/_authenticated\/account"/)
  })

  it('treats an index route and a leaf route on the same path as one URL', () => {
    const sources = [
      makeSource('@acme/account', { 'account.index.tsx': '/account/' }),
      makeSource('@other/account', { 'account.tsx': '/_authenticated/account' }),
    ]
    expect(() => assertNoRouteCollisions(sources)).toThrow(/Route "\/account"/)
  })

  it('catches a signed-in root index claiming the store selection page', () => {
    const sources = [
      makeSource('@spree/dashboard', {
        '_authenticated.tsx': '/_authenticated',
        'index.tsx': '/_authenticated/',
      }),
      makeSource('@acme/home', { 'index.tsx': '/_authenticated/' }),
    ]
    expect(() => assertNoRouteCollisions(sources)).toThrow(/@acme\/home/)
  })

  it('does not treat a pathless layout as a page', () => {
    const sources = [
      makeSource('@spree/dashboard', { 'index.tsx': '/_authenticated/' }),
      makeSource('@acme/wizard', {
        'wizard.tsx': '/_authenticated/_wizard',
        'step.tsx': '/_authenticated/_wizard/step',
      }),
    ]
    expect(() => assertNoRouteCollisions(sources)).not.toThrow()
  })
})
