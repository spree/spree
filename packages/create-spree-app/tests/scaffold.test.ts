import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { scaffold } from '../src/scaffold'

const FAKE_COMPOSE = `x-app: &app
  image: ghcr.io/spree/spree:\${SPREE_VERSION_TAG:-latest}
  depends_on:
    postgres:
      condition: service_healthy
  env_file: .env
  environment: &app-env
    DATABASE_URL: postgres://postgres@postgres:5432/spree_production
    REDIS_URL: redis://redis:6379/0
    SECRET_KEY_BASE: \${SECRET_KEY_BASE}

services:
  postgres:
    image: postgres:18-alpine
  web:
    <<: *app
    ports:
      - "\${SPREE_PORT:-3000}:3000"
  worker:
    <<: *app
    command: bundle exec sidekiq
volumes:
  postgres_data:
`

const FAKE_COMPOSE_DEV = `x-app: &app
  build:
    context: .
    dockerfile: Dockerfile
  depends_on:
    postgres:
      condition: service_healthy
  env_file: .env
  environment: &app-env
    DATABASE_URL: postgres://postgres@postgres:5432/spree_development
  volumes:
    - .:/rails
    - bundle_cache:/usr/local/bundle

services:
  postgres:
    image: postgres:18-alpine
  web:
    <<: *app
    ports:
      - "\${SPREE_PORT:-3000}:3000"
  worker:
    <<: *app
    command: bundle exec sidekiq
volumes:
  postgres_data:
`

vi.mock('../src/storefront', async (importOriginal) => {
  const mod = await importOriginal<typeof import('../src/storefront')>()
  return {
    ...mod,
    downloadStorefront: vi.fn(),
    installRootDeps: vi.fn(),
    installStorefrontDeps: vi.fn(),
    writeStorefrontEnv: vi.fn(),
  }
})

vi.mock('../src/dashboard', () => ({
  // The real implementation shells out to the project-local
  // `npx spree add dashboard` — its behavior is covered by @spree/cli's own
  // tests. Here we only assert the delegation happens (or doesn't).
  scaffoldDashboard: vi.fn(),
}))

vi.mock('../src/backend', () => ({
  downloadBackend: vi.fn(async (projectDir: string) => {
    // Simulate what downloadBackend does: create backend/ with compose files
    const backendDir = path.join(projectDir, 'backend')
    fs.mkdirSync(backendDir, { recursive: true })
    fs.writeFileSync(path.join(backendDir, 'docker-compose.yml'), FAKE_COMPOSE)
    fs.writeFileSync(path.join(backendDir, 'docker-compose.dev.yml'), FAKE_COMPOSE_DEV)
  }),
}))

function createTempDir(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'create-spree-app-test-'))
}

describe('scaffold (no-start)', () => {
  const tempDirs: string[] = []

  function getTempProjectDir(): string {
    const base = createTempDir()
    const projectDir = path.join(base, 'my-store')
    tempDirs.push(base)
    return projectDir
  }

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true })
    }
    tempDirs.length = 0
  })

  it('creates all expected files', async () => {
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      storefront: true,
      dashboard: false,
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
    })

    expect(fs.existsSync(path.join(projectDir, 'docker-compose.yml'))).toBe(true)
    expect(fs.existsSync(path.join(projectDir, 'docker-compose.dev.yml'))).toBe(true)
    expect(fs.existsSync(path.join(projectDir, '.env'))).toBe(true)
    expect(fs.existsSync(path.join(projectDir, 'package.json'))).toBe(true)
    expect(fs.existsSync(path.join(projectDir, 'README.md'))).toBe(true)
    expect(fs.existsSync(path.join(projectDir, '.gitignore'))).toBe(true)
  })

  it('copies docker-compose.yml from backend template', async () => {
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      storefront: true,
      dashboard: false,
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
    })

    const compose = fs.readFileSync(path.join(projectDir, 'docker-compose.yml'), 'utf-8')
    // The quick-start compose is copied verbatim — only the dev compose gets
    // path adjustments for the wrapper layout.
    expect(compose).toBe(FAKE_COMPOSE)
  })

  it('adjusts docker-compose.dev.yml build context to ./backend', async () => {
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      storefront: true,
      dashboard: false,
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
    })

    const compose = fs.readFileSync(path.join(projectDir, 'docker-compose.dev.yml'), 'utf-8')
    expect(compose).toContain('context: ./backend')
    expect(compose).not.toContain('ghcr.io/spree/spree')
  })

  it('adjusts docker-compose.dev.yml source bind-mount to ./backend', async () => {
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      storefront: true,
      dashboard: false,
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
    })

    const compose = fs.readFileSync(path.join(projectDir, 'docker-compose.dev.yml'), 'utf-8')
    expect(compose).toContain('- ./backend:/rails')
    expect(compose).not.toContain('- .:/rails')
    // Named volumes are left untouched
    expect(compose).toContain('- bundle_cache:/usr/local/bundle')
  })

  it('generates .env with SECRET_KEY_BASE and PORT', async () => {
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      storefront: true,
      dashboard: false,
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 4567,
    })

    const env = fs.readFileSync(path.join(projectDir, '.env'), 'utf-8')
    expect(env).toMatch(/SECRET_KEY_BASE=.{128}/)
    expect(env).toContain('SPREE_PORT=4567')
  })

  it('generates valid package.json with project name', async () => {
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      storefront: true,
      dashboard: false,
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
    })

    const content = fs.readFileSync(path.join(projectDir, 'package.json'), 'utf-8')
    const pkg = JSON.parse(content)
    expect(pkg.name).toBe('my-store')
    expect(pkg.scripts.eject).toBe('spree eject')
  })

  it('delegates dashboard scaffolding to the project-local CLI when included', async () => {
    const { scaffoldDashboard } = await import('../src/dashboard')
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      storefront: false,
      dashboard: true,
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 4567,
    })

    expect(scaffoldDashboard).toHaveBeenCalledWith(projectDir, {
      install: true,
      packageManager: 'npm',
    })
    expect(fs.readFileSync(path.join(projectDir, 'README.md'), 'utf-8')).toContain(
      'React Dashboard',
    )
  })

  it('skips the dashboard when not included', async () => {
    const { scaffoldDashboard } = await import('../src/dashboard')
    vi.mocked(scaffoldDashboard).mockClear()
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      storefront: false,
      dashboard: false,
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
    })

    expect(scaffoldDashboard).not.toHaveBeenCalled()
    expect(fs.readFileSync(path.join(projectDir, 'README.md'), 'utf-8')).not.toContain(
      'React Dashboard',
    )
  })

  it('rejects non-empty directory', async () => {
    const projectDir = getTempProjectDir()
    fs.mkdirSync(projectDir, { recursive: true })
    fs.writeFileSync(path.join(projectDir, 'existing-file'), 'content')

    // scaffold calls process.exit(1) for non-empty dirs, so we mock it
    const mockExit = vi.spyOn(process, 'exit').mockImplementation(() => {
      throw new Error('process.exit called')
    })

    await expect(
      scaffold({
        directory: projectDir,
        sampleData: false,
        start: false,
        packageManager: 'npm',
        port: 3000,
      }),
    ).rejects.toThrow('process.exit called')

    mockExit.mockRestore()
  })
})
