import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { addDashboard, ensureRenderBlueprintService } from '../src/commands/add.js'
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
    expect(env).toContain('VITE_SPREE_API_URL=http://localhost:3999')
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

  describe('Render Blueprint registration', () => {
    const BLUEPRINT = `services:
  - type: web
    name: spree
    runtime: ruby
    rootDir: backend

  - type: redis
    name: spree-redis

databases:
  - name: spree-db
`

    it('adds a static-site service inside the services array', async () => {
      fs.writeFileSync(path.join(projectDir, 'render.yaml'), BLUEPRINT)

      await addDashboard(ctx(), { template: templateDir, install: false })

      const content = fs.readFileSync(path.join(projectDir, 'render.yaml'), 'utf-8')
      expect(content).toContain('name: spree-dashboard')
      expect(content).toContain('runtime: static')
      expect(content).toContain('rootDir: apps/dashboard')
      expect(content).toContain('staticPublishPath: dist')
      expect(content).toContain('destination: /index.html')
      expect(content).toContain('sync: false')
      // Stays inside the services array — before the top-level databases key.
      expect(content.indexOf('spree-dashboard')).toBeLessThan(content.indexOf('databases:'))
    })

    it('is idempotent and picks the build command from the project lockfile', async () => {
      fs.writeFileSync(path.join(projectDir, 'render.yaml'), BLUEPRINT)
      fs.writeFileSync(path.join(projectDir, 'package-lock.json'), '{}')

      expect(ensureRenderBlueprintService(projectDir, 'npm')).toBe('added')
      const once = fs.readFileSync(path.join(projectDir, 'render.yaml'), 'utf-8')
      expect(once).toContain('buildCommand: npm install && npm run build')

      expect(ensureRenderBlueprintService(projectDir, 'npm')).toBe('present')
      expect(fs.readFileSync(path.join(projectDir, 'render.yaml'), 'utf-8')).toBe(once)
    })

    it('does nothing when the project has no Blueprint', async () => {
      expect(ensureRenderBlueprintService(projectDir, 'pnpm')).toBe('no-blueprint')
      expect(fs.existsSync(path.join(projectDir, 'render.yaml'))).toBe(false)
    })

    it('appends at the end when there is no databases key', () => {
      fs.writeFileSync(
        path.join(projectDir, 'render.yaml'),
        'services:\n  - type: web\n    name: spree\n',
      )
      expect(ensureRenderBlueprintService(projectDir, 'pnpm')).toBe('added')
      const content = fs.readFileSync(path.join(projectDir, 'render.yaml'), 'utf-8')
      expect(content).toContain('name: spree-dashboard')
      expect(content).toContain('corepack enable pnpm && pnpm install && pnpm build')
    })
  })
})
