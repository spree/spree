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
    MEILISEARCH_URL: http://meilisearch:7700

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
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
      dbPort: 5433,
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
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
      dbPort: 5433,
    })

    const compose = fs.readFileSync(path.join(projectDir, 'docker-compose.yml'), 'utf-8')
    expect(compose).toContain('ghcr.io/spree/spree')
    expect(compose).toContain('MEILISEARCH_URL')
  })

  it('adjusts docker-compose.dev.yml build context to ./backend', async () => {
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      storefront: true,
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
      dbPort: 5433,
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
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
      dbPort: 5433,
    })

    const compose = fs.readFileSync(path.join(projectDir, 'docker-compose.dev.yml'), 'utf-8')
    expect(compose).toContain('- ./backend:/rails')
    expect(compose).not.toContain('- .:/rails')
    // Named volumes are left untouched
    expect(compose).toContain('- bundle_cache:/usr/local/bundle')
  })

  it('generates .env with SECRET_KEY_BASE and the picked ports', async () => {
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      storefront: true,
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 4567,
      dbPort: 5434,
    })

    const env = fs.readFileSync(path.join(projectDir, '.env'), 'utf-8')
    expect(env).toMatch(/SECRET_KEY_BASE=.{128}/)
    expect(env).toContain('SPREE_PORT=4567')
    expect(env).toContain('SPREE_DB_PORT=5434')
  })

  it('generates valid package.json with project name', async () => {
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      storefront: true,
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
      dbPort: 5433,
    })

    const content = fs.readFileSync(path.join(projectDir, 'package.json'), 'utf-8')
    const pkg = JSON.parse(content)
    expect(pkg.name).toBe('my-store')
    expect(pkg.scripts.eject).toBe('spree eject')
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
        dbPort: 5433,
      }),
    ).rejects.toThrow('process.exit called')

    mockExit.mockRestore()
  })
})
