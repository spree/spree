import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { discoverDashboardPlugins } from '../src/vite/discover'

/**
 * Each test builds a tiny fixture project on disk:
 *
 *   <tmp>/
 *     package.json
 *     node_modules/
 *       <dep>/package.json
 *
 * That lets us exercise the real `require.resolve` resolution path the
 * production code uses, without mocking Node's module system.
 */

interface Fixture {
  root: string
  cleanup: () => void
  writeHost: (deps: Record<string, string>, devDeps?: Record<string, string>) => void
  writeDep: (name: string, pkg: Record<string, unknown>) => void
}

function makeFixture(): Fixture {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-discover-'))
  fs.mkdirSync(path.join(root, 'node_modules'), { recursive: true })

  return {
    root,
    cleanup: () => fs.rmSync(root, { recursive: true, force: true }),
    writeHost(deps, devDeps = {}) {
      fs.writeFileSync(
        path.join(root, 'package.json'),
        JSON.stringify({ name: 'host', dependencies: deps, devDependencies: devDeps }),
      )
    },
    writeDep(name, pkg) {
      // Support scoped names by splitting on `/`.
      const dir = path.join(root, 'node_modules', ...name.split('/'))
      fs.mkdirSync(dir, { recursive: true })
      fs.writeFileSync(
        path.join(dir, 'package.json'),
        JSON.stringify({ name, version: '0.0.0', main: 'index.js', ...pkg }),
      )
      // require.resolve(pkg) needs `main` to point at an existing file.
      fs.writeFileSync(path.join(dir, 'index.js'), '')
    },
  }
}

describe('discoverDashboardPlugins', () => {
  let fixture: Fixture

  beforeEach(() => {
    fixture = makeFixture()
  })

  afterEach(() => {
    fixture.cleanup()
  })

  it('discovers deps that declare the marker', () => {
    fixture.writeHost({ '@acme/foo': '^1', '@acme/bar': '^1' })
    fixture.writeDep('@acme/foo', { spree: { dashboard: { plugin: true } } })
    fixture.writeDep('@acme/bar', {})

    const discovered = discoverDashboardPlugins({ root: fixture.root })
    expect(discovered).toEqual(['@acme/foo'])
  })

  it('walks both dependencies and devDependencies', () => {
    fixture.writeHost({ '@acme/prod-plugin': '^1' }, { '@acme/dev-plugin': '^1' })
    fixture.writeDep('@acme/prod-plugin', { spree: { dashboard: { plugin: true } } })
    fixture.writeDep('@acme/dev-plugin', { spree: { dashboard: { plugin: true } } })

    expect(discoverDashboardPlugins({ root: fixture.root })).toEqual([
      '@acme/prod-plugin',
      '@acme/dev-plugin',
    ])
  })

  it('ignores deps with the marker set to false or missing', () => {
    fixture.writeHost({ '@acme/foo': '^1', '@acme/bar': '^1', '@acme/baz': '^1' })
    fixture.writeDep('@acme/foo', { spree: { dashboard: { plugin: false } } })
    fixture.writeDep('@acme/bar', { spree: { dashboard: {} } })
    fixture.writeDep('@acme/baz', { spree: {} })

    expect(discoverDashboardPlugins({ root: fixture.root })).toEqual([])
  })

  it('returns deterministic order (deps before devDeps, manifest order within each)', () => {
    fixture.writeHost(
      { '@acme/a': '^1', '@acme/c': '^1' },
      { '@acme/b': '^1' },
    )
    fixture.writeDep('@acme/a', { spree: { dashboard: { plugin: true } } })
    fixture.writeDep('@acme/b', { spree: { dashboard: { plugin: true } } })
    fixture.writeDep('@acme/c', { spree: { dashboard: { plugin: true } } })

    expect(discoverDashboardPlugins({ root: fixture.root })).toEqual([
      '@acme/a',
      '@acme/c',
      '@acme/b',
    ])
  })

  it('returns an empty array when the host package.json is missing', () => {
    // Brand-new tmp dir, no package.json written.
    expect(discoverDashboardPlugins({ root: fixture.root })).toEqual([])
  })

  it('warns and skips malformed host package.json', () => {
    fs.writeFileSync(path.join(fixture.root, 'package.json'), '{ not json')
    const warnings: string[] = []

    const result = discoverDashboardPlugins({
      root: fixture.root,
      onWarn: (msg) => warnings.push(msg),
    })

    expect(result).toEqual([])
    expect(warnings).toHaveLength(1)
    expect(warnings[0]).toMatch(/Could not parse/)
  })

  it('skips deps with malformed package.json without crashing the whole walk', () => {
    // Node's `require.resolve` itself throws when it can't parse a dep's
    // package.json, so the dep is treated as unresolvable and silently
    // skipped — same behavior as a dep that's declared but uninstalled. The
    // important contract here is "the walk doesn't crash on a bad dep."
    fixture.writeHost({ '@acme/good': '^1', '@acme/bad': '^1' })
    fixture.writeDep('@acme/good', { spree: { dashboard: { plugin: true } } })
    const badDir = path.join(fixture.root, 'node_modules', '@acme/bad')
    fs.mkdirSync(badDir, { recursive: true })
    fs.writeFileSync(path.join(badDir, 'package.json'), '{ bogus')
    fs.writeFileSync(path.join(badDir, 'index.js'), '')

    const result = discoverDashboardPlugins({ root: fixture.root })
    expect(result).toEqual(['@acme/good'])
  })

  it('skips deps that cannot be resolved (e.g. declared but not installed)', () => {
    fixture.writeHost({ '@acme/foo': '^1', '@acme/ghost': '^1' })
    fixture.writeDep('@acme/foo', { spree: { dashboard: { plugin: true } } })
    // Note: no writeDep for @acme/ghost — declared but not installed.

    const result = discoverDashboardPlugins({ root: fixture.root })
    expect(result).toEqual(['@acme/foo'])
  })

  it('deduplicates a dep listed in both dependencies and devDependencies', () => {
    fixture.writeHost(
      { '@acme/foo': '^1' },
      { '@acme/foo': '^1' },
    )
    fixture.writeDep('@acme/foo', { spree: { dashboard: { plugin: true } } })

    expect(discoverDashboardPlugins({ root: fixture.root })).toEqual(['@acme/foo'])
  })
})
