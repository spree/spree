import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { resolveRouteMounts } from '../src/vite/route-mounts'

describe('resolveRouteMounts', () => {
  let root: string
  let shellRoutesDir: string

  function writeRoute(dir: string, file: string, routePath: string) {
    fs.mkdirSync(dir, { recursive: true })
    fs.writeFileSync(
      path.join(dir, file),
      `import { createFileRoute } from '@tanstack/react-router'\n` +
        `export const Route = createFileRoute('${routePath}')({ component: () => null })\n`,
    )
  }

  function writePlugin(name: string, marker: Record<string, string>) {
    const dir = path.join(root, 'node_modules', ...name.split('/'))
    fs.mkdirSync(dir, { recursive: true })
    fs.writeFileSync(
      path.join(dir, 'package.json'),
      JSON.stringify({ name, main: 'index.js', spree: { dashboard: { plugin: true, ...marker } } }),
    )
    fs.writeFileSync(path.join(dir, 'index.js'), '')
    return dir
  }

  function resolve(options: Partial<Parameters<typeof resolveRouteMounts>[0]> = {}) {
    return resolveRouteMounts({
      hostRoot: root,
      shell: { label: '@spree/seller-dashboard', routesDir: shellRoutesDir },
      panel: 'seller',
      ...options,
    })
  }

  beforeEach(() => {
    root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'route-mounts-')))
    shellRoutesDir = path.join(root, 'shell/routes')
    writeRoute(shellRoutesDir, 'orders.tsx', '/_authenticated/$sellerId/orders')
    fs.writeFileSync(
      path.join(root, 'package.json'),
      JSON.stringify({ name: 'my-panel', dependencies: { '@acme/reviews': '1.0.0' } }),
    )
  })

  afterEach(() => {
    fs.rmSync(root, { recursive: true, force: true })
  })

  it("mounts each plugin's routes for the panel being built, and only those", () => {
    const pluginDir = writePlugin('@acme/reviews', {
      routes: './admin-routes',
      sellerRoutes: './seller-routes',
    })
    writeRoute(
      path.join(pluginDir, 'admin-routes'),
      'reviews.tsx',
      '/_authenticated/$storeId/reviews',
    )
    writeRoute(
      path.join(pluginDir, 'seller-routes'),
      'reviews.tsx',
      '/_authenticated/$sellerId/reviews',
    )

    expect(resolve()).toEqual(['../../node_modules/@acme/reviews/seller-routes'])
    expect(resolve({ panel: 'dashboard' })).toEqual([
      '../../node_modules/@acme/reviews/admin-routes',
    ])
  })

  it("mounts the host app's own routes directory when it exists", () => {
    expect(resolve()).toEqual([])

    writeRoute(path.join(root, 'src/routes'), 'reviews.tsx', '/_authenticated/$sellerId/reviews')

    expect(resolve()).toEqual(['../../src/routes'])
    expect(resolve({ hostRoutes: false })).toEqual([])
  })

  it('does not mount the shell twice when the shell builds itself', () => {
    const ownRoutesDir = path.join(root, 'src/routes')
    writeRoute(ownRoutesDir, 'orders.tsx', '/_authenticated/$sellerId/orders')

    expect(
      resolve({ shell: { label: '@spree/seller-dashboard', routesDir: ownRoutesDir } }),
    ).toEqual([])
  })

  it('names the host app when its route collides with a built-in page', () => {
    writeRoute(path.join(root, 'src/routes'), 'orders.tsx', '/_authenticated/$sellerId/orders')

    expect(() => resolve()).toThrow(/my-panel \(your app\)/)
  })
})
