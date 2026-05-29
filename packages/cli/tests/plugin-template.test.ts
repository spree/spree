/**
 * Integration test for the bundled plugin template. Renders the real
 * `templates/plugin/` tree into a temp dir and verifies the output looks
 * right end-to-end. Catches missing variables, broken paths, and bad
 * substitution in a way the renderer's unit tests can't.
 */
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { render, type TemplateVars } from '../src/lib/template'

const TEMPLATE_SRC = path.resolve(__dirname, '../templates/plugin')

const SAMPLE_VARS: TemplateVars = {
  name: 'brands',
  plugin_name: 'brands',
  ruby_name: 'spree_brands',
  module_name: 'SpreeBrands',
  npm_scope: '@acme',
  npm_package_name: '@acme/brands',
  npm_dashboard_package: '@acme/brands-dashboard',
  author_name: 'Jane Developer',
  author_email: 'jane@acme.dev',
  license: 'MIT',
  year: '2026',
}

describe('bundled plugin template', () => {
  const tempDirs: string[] = []

  function tempDir(): string {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-cli-plugin-test-'))
    tempDirs.push(dir)
    return dir
  }

  afterEach(() => {
    for (const dir of tempDirs) fs.rmSync(dir, { recursive: true, force: true })
    tempDirs.length = 0
  })

  it('renders into a working structure with all halves', () => {
    const dst = path.join(tempDir(), 'out')
    render({ src: TEMPLATE_SRC, dst, vars: SAMPLE_VARS })

    expect(fs.existsSync(path.join(dst, 'package.json'))).toBe(true)
    expect(fs.existsSync(path.join(dst, 'pnpm-workspace.yaml'))).toBe(true)
    expect(fs.existsSync(path.join(dst, 'README.md'))).toBe(true)
    expect(fs.existsSync(path.join(dst, 'LICENSE'))).toBe(true)
    expect(fs.existsSync(path.join(dst, '.gitignore'))).toBe(true)

    expect(fs.existsSync(path.join(dst, 'packages/dashboard/package.json'))).toBe(true)
    expect(fs.existsSync(path.join(dst, 'packages/dashboard/src/index.tsx'))).toBe(true)
    expect(fs.existsSync(path.join(dst, 'packages/dashboard/src/client.ts'))).toBe(true)
    expect(fs.existsSync(path.join(dst, 'packages/dashboard/src/types.ts'))).toBe(true)

    expect(fs.existsSync(path.join(dst, 'packages/dashboard/src/routes/brands-list.tsx'))).toBe(
      true,
    )
    expect(
      fs.existsSync(path.join(dst, 'packages/dashboard/src/slots/product-brands-card.tsx')),
    ).toBe(true)
    expect(fs.existsSync(path.join(dst, 'packages/dashboard/src/locales/en.json'))).toBe(true)
  })

  it('renders the root package.json with substituted name', () => {
    const dst = path.join(tempDir(), 'out')
    render({ src: TEMPLATE_SRC, dst, vars: SAMPLE_VARS })

    const pkg = JSON.parse(fs.readFileSync(path.join(dst, 'package.json'), 'utf8'))
    expect(pkg.name).toBe('@acme/brands')
    expect(pkg.author).toBe('Jane Developer <jane@acme.dev>')
    expect(pkg.license).toBe('MIT')
  })

  it('renders the dashboard package.json with the dashboard sub-name', () => {
    const dst = path.join(tempDir(), 'out')
    render({ src: TEMPLATE_SRC, dst, vars: SAMPLE_VARS })

    const pkg = JSON.parse(
      fs.readFileSync(path.join(dst, 'packages/dashboard/package.json'), 'utf8'),
    )
    expect(pkg.name).toBe('@acme/brands-dashboard')
    expect(pkg.peerDependencies['@spree/dashboard-core']).toBeDefined()
  })

  it('substitutes module names + paths consistently in the dashboard entry', () => {
    const dst = path.join(tempDir(), 'out')
    render({ src: TEMPLATE_SRC, dst, vars: SAMPLE_VARS })

    const index = fs.readFileSync(path.join(dst, 'packages/dashboard/src/index.tsx'), 'utf8')
    expect(index).toContain("from './client'")
    expect(index).toContain("from './routes/brands-list'")
    expect(index).toContain("from './slots/product-brands-card'")
    expect(index).toContain('SpreeBrandsClient')
    expect(index).toContain('SpreeBrandsListPage')
    expect(index).toContain('SpreeBrandsCard')
    expect(index).toContain("path: '/brands'")
    expect(index).toContain('admin.brands_plugin')
  })

  it('substitutes the README', () => {
    const dst = path.join(tempDir(), 'out')
    render({ src: TEMPLATE_SRC, dst, vars: SAMPLE_VARS })

    const readme = fs.readFileSync(path.join(dst, 'README.md'), 'utf8')
    expect(readme).toContain('# brands')
    expect(readme).toContain('@acme/brands-dashboard')
    expect(readme).toContain("gem 'spree_brands'")
    expect(readme).toContain('Jane Developer')
    expect(readme).not.toContain('{{')
  })

  it('skips the dashboard subtree when asked', () => {
    const dst = path.join(tempDir(), 'out')
    render({
      src: TEMPLATE_SRC,
      dst,
      vars: SAMPLE_VARS,
      skip: (rel) => rel === 'packages/dashboard' || rel.startsWith('packages/dashboard/'),
    })

    expect(fs.existsSync(path.join(dst, 'package.json'))).toBe(true)
    expect(fs.existsSync(path.join(dst, 'packages/dashboard'))).toBe(false)
  })

  it('leaves no `{{...}}` tokens in any rendered file', () => {
    const dst = path.join(tempDir(), 'out')
    render({ src: TEMPLATE_SRC, dst, vars: SAMPLE_VARS })

    const stragglers: string[] = []
    function walk(dir: string) {
      for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name)
        if (e.isDirectory()) walk(p)
        else {
          const content = fs.readFileSync(p, 'utf8')
          if (/\{\{[a-zA-Z_]/.test(content)) {
            stragglers.push(
              `${path.relative(dst, p)}: ${content.match(/\{\{[a-zA-Z_][a-zA-Z0-9_]*\}\}/)?.[0]}`,
            )
          }
        }
      }
    }
    walk(dst)

    expect(stragglers).toEqual([])
  })
})
