import { describe, it, expect, afterEach, vi } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import { scaffold } from '../src/scaffold'

vi.mock('../src/storefront', async (importOriginal) => {
  const mod = await importOriginal<typeof import('../src/storefront')>()
  return {
    ...mod,
    installRootDeps: vi.fn(),
  }
})

function createTempDir(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'create-spree-app-test-'))
}

describe('scaffold (backend-only, no-start)', () => {
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
      mode: 'backend-only',
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
    })

    expect(fs.existsSync(path.join(projectDir, 'docker-compose.yml'))).toBe(true)
    expect(fs.existsSync(path.join(projectDir, '.env'))).toBe(true)
    expect(fs.existsSync(path.join(projectDir, 'package.json'))).toBe(true)
    expect(fs.existsSync(path.join(projectDir, 'README.md'))).toBe(true)
    expect(fs.existsSync(path.join(projectDir, '.gitignore'))).toBe(true)
  })

  it('generates docker-compose with Spree image', async () => {
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      mode: 'backend-only',
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
    })

    const compose = fs.readFileSync(path.join(projectDir, 'docker-compose.yml'), 'utf-8')
    expect(compose).toContain('ghcr.io/spree/spree')
  })

  it('generates .env with SECRET_KEY_BASE and SPREE_PORT', async () => {
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      mode: 'backend-only',
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
      mode: 'backend-only',
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
    })

    const content = fs.readFileSync(path.join(projectDir, 'package.json'), 'utf-8')
    const pkg = JSON.parse(content)
    expect(pkg.name).toBe('my-store')
  })

  it('does not create storefront directory in backend-only mode', async () => {
    const projectDir = getTempProjectDir()

    await scaffold({
      directory: projectDir,
      mode: 'backend-only',
      sampleData: false,
      start: false,
      packageManager: 'npm',
      port: 3000,
    })

    expect(fs.existsSync(path.join(projectDir, 'apps'))).toBe(false)
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
        mode: 'backend-only',
        sampleData: false,
        start: false,
        packageManager: 'npm',
        port: 3000,
      })
    ).rejects.toThrow('process.exit called')

    mockExit.mockRestore()
  })
})
