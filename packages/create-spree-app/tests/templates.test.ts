import { describe, it, expect } from 'vitest'
import { dockerComposeContent } from '../src/templates/docker-compose'
import { envContent, storefrontEnvContent } from '../src/templates/env'
import { rootPackageJsonContent } from '../src/templates/package-json'
import { readmeContent } from '../src/templates/readme'
import { gitignoreContent } from '../src/templates/gitignore'

describe('dockerComposeContent', () => {
  const content = dockerComposeContent(3000)

  it('includes the Spree image', () => {
    expect(content).toContain('ghcr.io/spree/spree')
  })

  it('includes postgres service', () => {
    expect(content).toContain('postgres:17-alpine')
  })

  it('includes healthcheck for web service', () => {
    expect(content).toContain('curl -f http://localhost:3000/up')
  })

  it('includes worker service with bin/jobs command', () => {
    expect(content).toContain('command: bin/jobs')
  })

  it('includes volume definition', () => {
    expect(content).toContain('postgres_data:')
  })

  it('uses DATABASE_URL pointing to postgres service', () => {
    expect(content).toContain('DATABASE_URL: postgres://postgres@postgres:5432/spree_production')
  })

  it('sets separate URLs for cache, queue, and cable databases', () => {
    expect(content).toContain('CACHE_DATABASE_URL: postgres://postgres@postgres:5432/spree_production_cache')
    expect(content).toContain('QUEUE_DATABASE_URL: postgres://postgres@postgres:5432/spree_production_queue')
    expect(content).toContain('CABLE_DATABASE_URL: postgres://postgres@postgres:5432/spree_production_cable')
  })

  it('uses production environment with SSL disabled', () => {
    expect(content).toContain('RAILS_ENV: production')
    expect(content).toContain('RAILS_FORCE_SSL: "false"')
    expect(content).toContain('RAILS_ASSUME_SSL: "false"')
  })

  it('loads env_file', () => {
    expect(content).toContain('env_file: .env')
  })

  it('maps the given port to container port 3000', () => {
    const custom = dockerComposeContent(4000)
    expect(custom).toContain('"4000:3000"')
  })

  it('keeps container-internal healthcheck on port 3000 regardless of host port', () => {
    const custom = dockerComposeContent(5000)
    expect(custom).toContain('curl -f http://localhost:3000/up')
    expect(custom).not.toContain('5000/up')
  })
})

describe('envContent', () => {
  it('includes the provided secret key', () => {
    const content = envContent('my-secret-123', 3000)
    expect(content).toContain('SECRET_KEY_BASE=my-secret-123')
  })

  it('includes SPREE_VERSION_TAG', () => {
    const content = envContent('any', 3000)
    expect(content).toContain('SPREE_VERSION_TAG=')
  })

  it('includes SPREE_PORT', () => {
    const content = envContent('any', 3000)
    expect(content).toContain('SPREE_PORT=3000')
  })

  it('uses custom port value', () => {
    const content = envContent('any', 4567)
    expect(content).toContain('SPREE_PORT=4567')
  })
})

describe('storefrontEnvContent', () => {
  it('includes placeholder when no key provided', () => {
    const content = storefrontEnvContent(3000)
    expect(content).toContain('pk_REPLACE_ME_AFTER_DOCKER_START')
  })

  it('includes real key when provided', () => {
    const content = storefrontEnvContent(3000, 'pk_test123')
    expect(content).toContain('SPREE_PUBLISHABLE_KEY=pk_test123')
  })

  it('includes API URL with given port', () => {
    const content = storefrontEnvContent(3000)
    expect(content).toContain('SPREE_API_URL=http://localhost:3000')
  })

  it('uses custom port in API URL', () => {
    const content = storefrontEnvContent(4567)
    expect(content).toContain('SPREE_API_URL=http://localhost:4567')
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
    const content = readmeContent('my-store', false, 3000)
    expect(content).toContain('# my-store')
  })

  it('includes admin credentials', () => {
    const content = readmeContent('my-store', false, 3000)
    expect(content).toContain('spree@example.com')
    expect(content).toContain('spree123')
  })

  it('includes storefront section when full-stack', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('storefront')
    expect(content).toContain('npm run dev')
  })

  it('omits storefront section when backend-only', () => {
    const content = readmeContent('my-store', false, 3000)
    expect(content).not.toContain('Start the storefront')
  })

  it('uses npm run commands instead of docker compose', () => {
    const content = readmeContent('my-store', false, 3000)
    expect(content).toContain('`npm run dev`')
    expect(content).toContain('`npm run down`')
    expect(content).toContain('`npm run logs`')
    expect(content).toContain('`npm run console`')
  })

  it('uses custom port in URLs', () => {
    const content = readmeContent('my-store', false, 4567)
    expect(content).toContain('http://localhost:4567/admin')
    expect(content).toContain('http://localhost:4567/api/v3/store')
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
