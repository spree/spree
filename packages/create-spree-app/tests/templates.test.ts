import { describe, it, expect } from 'vitest'
import { dockerComposeContent } from '../src/templates/docker-compose'
import { envContent, storefrontEnvContent } from '../src/templates/env'
import { rootPackageJsonContent } from '../src/templates/package-json'
import { readmeContent } from '../src/templates/readme'
import { gitignoreContent } from '../src/templates/gitignore'

describe('dockerComposeContent', () => {
  const content = dockerComposeContent()

  it('includes the Spree image', () => {
    expect(content).toContain('ghcr.io/spree/spree')
  })

  it('includes postgres service', () => {
    expect(content).toContain('postgres:17-alpine')
  })

  it('includes healthcheck for spree', () => {
    expect(content).toContain('curl -f http://localhost:3000/up')
  })

  it('includes volume definition', () => {
    expect(content).toContain('postgres_data:')
  })

  it('uses env var for SECRET_KEY_BASE', () => {
    expect(content).toContain('${SECRET_KEY_BASE}')
  })
})

describe('envContent', () => {
  it('includes the provided secret key', () => {
    const content = envContent('my-secret-123')
    expect(content).toContain('SECRET_KEY_BASE=my-secret-123')
  })

  it('includes SPREE_VERSION_TAG', () => {
    const content = envContent('any')
    expect(content).toContain('SPREE_VERSION_TAG=')
  })
})

describe('storefrontEnvContent', () => {
  it('includes placeholder when no key provided', () => {
    const content = storefrontEnvContent()
    expect(content).toContain('pk_REPLACE_ME_AFTER_DOCKER_START')
  })

  it('includes real key when provided', () => {
    const content = storefrontEnvContent('pk_test123')
    expect(content).toContain('NEXT_PUBLIC_SPREE_PUBLISHABLE_KEY=pk_test123')
  })

  it('includes API URL', () => {
    const content = storefrontEnvContent()
    expect(content).toContain('NEXT_PUBLIC_SPREE_API_URL=http://localhost:3000')
  })
})

describe('rootPackageJsonContent', () => {
  it('returns valid JSON', () => {
    const content = rootPackageJsonContent('my-store')
    expect(() => JSON.parse(content)).not.toThrow()
  })

  it('sets the project name', () => {
    const pkg = JSON.parse(rootPackageJsonContent('my-store'))
    expect(pkg.name).toBe('my-store')
  })

  it('includes convenience scripts', () => {
    const pkg = JSON.parse(rootPackageJsonContent('my-store'))
    expect(pkg.scripts.dev).toContain('docker compose')
    expect(pkg.scripts.down).toContain('docker compose')
    expect(pkg.scripts.logs).toContain('docker compose')
  })

  it('is marked private', () => {
    const pkg = JSON.parse(rootPackageJsonContent('my-store'))
    expect(pkg.private).toBe(true)
  })
})

describe('readmeContent', () => {
  it('includes the project name as heading', () => {
    const content = readmeContent('my-store', false)
    expect(content).toContain('# my-store')
  })

  it('includes admin credentials', () => {
    const content = readmeContent('my-store', false)
    expect(content).toContain('spree@example.com')
    expect(content).toContain('spree123')
  })

  it('includes storefront section when full-stack', () => {
    const content = readmeContent('my-store', true)
    expect(content).toContain('storefront')
    expect(content).toContain('npm run dev')
  })

  it('omits storefront section when backend-only', () => {
    const content = readmeContent('my-store', false)
    expect(content).not.toContain('Start the storefront')
  })
})

describe('gitignoreContent', () => {
  const content = gitignoreContent()

  it('ignores node_modules', () => {
    expect(content).toContain('node_modules')
  })

  it('ignores .env', () => {
    expect(content).toContain('.env')
  })
})
