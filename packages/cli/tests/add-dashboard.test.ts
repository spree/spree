import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import {
  addDashboard,
  ensureDashboardDevEnv,
  ensureRenderBlueprintService,
} from '../src/commands/add.js'
import type { ProjectContext } from '../src/types.js'

/**
 * Exercises the local-directory template path (the same code `--template
 * <path>` and SPREE_DASHBOARD_TEMPLATE hit). The git-clone path is the same
 * function with a URL — covered by the smoke flow, not unit-testable offline.
 */
describe('addDashboard', () => {
  let projectDir: string
  let templateDir: string

  function ctx(): ProjectContext {
    return { mode: 'docker', projectDir, port: 3999 }
  }

  beforeEach(() => {
    projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-add-project-'))
    templateDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-add-template-'))
    fs.writeFileSync(path.join(projectDir, 'docker-compose.yml'), 'services: {}\n')

    fs.writeFileSync(path.join(templateDir, 'package.json'), '{"name":"starter"}\n')
    fs.mkdirSync(path.join(templateDir, 'src'))
    fs.writeFileSync(path.join(templateDir, 'src', 'main.tsx'), '// entry\n')
    // The bundled template ships its .gitignore under this name (npm never
    // packs .gitignore files) — the scaffolder must restore the real name.
    fs.writeFileSync(path.join(templateDir, 'gitignore.template'), 'node_modules/\n')
    // Junk that must not be copied into the project
    fs.mkdirSync(path.join(templateDir, 'node_modules', 'leftover'), { recursive: true })
    fs.mkdirSync(path.join(templateDir, 'dist'))
    fs.writeFileSync(path.join(templateDir, 'dist', 'bundle.js'), '')
  })

  afterEach(() => {
    fs.rmSync(projectDir, { recursive: true, force: true })
    fs.rmSync(templateDir, { recursive: true, force: true })
  })

  it('copies the template into apps/dashboard and writes .env.local with the project port', async () => {
    await addDashboard(ctx(), { template: templateDir, install: false })

    const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
    expect(fs.existsSync(path.join(dashboardDir, 'package.json'))).toBe(true)
    expect(fs.existsSync(path.join(dashboardDir, 'src', 'main.tsx'))).toBe(true)
    expect(fs.existsSync(path.join(dashboardDir, 'node_modules'))).toBe(false)
    expect(fs.existsSync(path.join(dashboardDir, 'dist'))).toBe(false)

    const env = fs.readFileSync(path.join(dashboardDir, '.env.local'), 'utf-8')
    expect(env).toContain('VITE_API_PROXY_TARGET=http://localhost:3999')
    expect(env).not.toMatch(/^VITE_SPREE_API_URL=/m)
    expect(env).not.toMatch(/sk_/)

    // gitignore.template restored to its real name
    expect(fs.existsSync(path.join(dashboardDir, '.gitignore'))).toBe(true)
    expect(fs.existsSync(path.join(dashboardDir, 'gitignore.template'))).toBe(false)
  })

  it('is a no-op when apps/dashboard already exists', async () => {
    await addDashboard(ctx(), { template: templateDir, install: false })
    const marker = path.join(projectDir, 'apps', 'dashboard', 'src', 'custom.ts')
    fs.writeFileSync(marker, '// user file\n')

    await addDashboard(ctx(), { template: templateDir, install: false })
    expect(fs.existsSync(marker)).toBe(true)
  })

  it('recovers a missing .env.local without touching anything else', async () => {
    await addDashboard(ctx(), { template: templateDir, install: false })
    const envPath = path.join(projectDir, 'apps', 'dashboard', '.env.local')
    fs.rmSync(envPath)

    await addDashboard(ctx(), { template: templateDir, install: false })
    expect(fs.readFileSync(envPath, 'utf-8')).toContain('http://localhost:3999')
  })

  describe('Render Blueprint single-node amendment', () => {
    // The starter Blueprint shape after create-spree-app relocates it.
    const BLUEPRINT = `services:
  - type: web
    name: spree
    runtime: ruby
    rootDir: backend
    plan: free
    buildCommand: bundle install && bundle exec rails assets:precompile && bundle exec rails db:prepare
    startCommand: bundle exec puma -C config/puma.rb
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: spree-db
          property: connectionString

  - type: redis
    name: spree-redis

databases:
  - name: spree-db
`

    it('extends the backend service to build and serve the dashboard', async () => {
      fs.writeFileSync(path.join(projectDir, 'render.yaml'), BLUEPRINT)

      await addDashboard(ctx(), { template: templateDir, install: false })

      const content = fs.readFileSync(path.join(projectDir, 'render.yaml'), 'utf-8')
      // Build step appended to the Rails buildCommand, dashboard built with
      // the sub-path base and no absolute API URL (origin-relative).
      expect(content).toContain(
        'bundle exec rails db:prepare && (cd ../apps/dashboard && corepack enable pnpm && pnpm install && VITE_BASE_PATH=/dashboard/ pnpm build)',
      )
      // Served by the same service — env var inside the backend's envVars.
      expect(content).toContain('- key: SPREE_DASHBOARD_DIST_PATH')
      expect(content).toContain('value: ../apps/dashboard/dist')
      expect(content.indexOf('SPREE_DASHBOARD_DIST_PATH')).toBeLessThan(
        content.indexOf('DATABASE_URL'),
      )
      // No cross-origin machinery: no static site, no VITE_SPREE_API_URL.
      expect(content).not.toContain('VITE_SPREE_API_URL')
      expect(content).not.toContain('runtime: static')
    })

    it('is idempotent and picks the build command from the project lockfile', async () => {
      fs.writeFileSync(path.join(projectDir, 'render.yaml'), BLUEPRINT)
      fs.writeFileSync(path.join(projectDir, 'package-lock.json'), '{}')

      expect(ensureRenderBlueprintService(projectDir, 'npm')).toBe('amended')
      const once = fs.readFileSync(path.join(projectDir, 'render.yaml'), 'utf-8')
      expect(once).toContain('npm install && VITE_BASE_PATH=/dashboard/ npm run build')

      expect(ensureRenderBlueprintService(projectDir, 'npm')).toBe('present')
      expect(fs.readFileSync(path.join(projectDir, 'render.yaml'), 'utf-8')).toBe(once)
    })

    it('does nothing when the project has no Blueprint', async () => {
      expect(ensureRenderBlueprintService(projectDir, 'pnpm')).toBe('no-blueprint')
      expect(fs.existsSync(path.join(projectDir, 'render.yaml'))).toBe(false)
    })

    it('leaves an unrecognized Blueprint untouched', () => {
      const custom = 'services:\n  - type: web\n    name: my-thing\n    runtime: docker\n'
      fs.writeFileSync(path.join(projectDir, 'render.yaml'), custom)

      expect(ensureRenderBlueprintService(projectDir, 'pnpm')).toBe('unrecognized')
      expect(fs.readFileSync(path.join(projectDir, 'render.yaml'), 'utf-8')).toBe(custom)
    })
  })
})

describe('ensureDashboardDevEnv', () => {
  let projectDir: string

  beforeEach(() => {
    projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-env-repair-'))
    fs.mkdirSync(path.join(projectDir, 'apps', 'dashboard'), { recursive: true })
    fs.writeFileSync(
      path.join(projectDir, 'apps', 'dashboard', 'package.json'),
      '{"name":"dashboard"}\n',
    )
  })

  afterEach(() => {
    fs.rmSync(projectDir, { recursive: true, force: true })
  })

  const envPath = () => path.join(projectDir, 'apps', 'dashboard', '.env.local')

  it('writes .env.local when missing (fresh clone)', () => {
    expect(ensureDashboardDevEnv(projectDir, 3999)).toBe('written')
    expect(fs.readFileSync(envPath(), 'utf-8')).toContain(
      'VITE_API_PROXY_TARGET=http://localhost:3999',
    )
  })

  it('repairs only the broken line, preserving user additions', () => {
    fs.writeFileSync(
      envPath(),
      '# my notes\nVITE_SPREE_API_URL=http://localhost:3000\nVITE_MY_FLAG=1\n',
    )
    expect(ensureDashboardDevEnv(projectDir, 3999)).toBe('repaired')
    const env = fs.readFileSync(envPath(), 'utf-8')
    expect(env).toContain('# my notes')
    expect(env).toContain('VITE_API_PROXY_TARGET=http://localhost:3999')
    expect(env).toContain('VITE_MY_FLAG=1')
    expect(env).not.toMatch(/^VITE_SPREE_API_URL=/m)
  })

  it('leaves a non-localhost VITE_SPREE_API_URL (real deploy config) untouched', () => {
    const custom = 'VITE_SPREE_API_URL=https://api.mystore.com\nVITE_MY_FLAG=1\n'
    fs.writeFileSync(envPath(), custom)
    expect(ensureDashboardDevEnv(projectDir, 3999)).toBe('untouched')
    expect(fs.readFileSync(envPath(), 'utf-8')).toBe(custom)
  })

  it('does nothing without an apps/dashboard app', () => {
    fs.rmSync(path.join(projectDir, 'apps', 'dashboard'), { recursive: true })
    expect(ensureDashboardDevEnv(projectDir, 3999)).toBe('untouched')
    expect(fs.existsSync(envPath())).toBe(false)
  })
})
