import { describe, expect, it } from 'vitest'
import { dependabotContent } from '../src/templates/dependabot'
import { envContent, storefrontEnvContent } from '../src/templates/env'
import { gitignoreContent } from '../src/templates/gitignore'
import { rootPackageJsonContent } from '../src/templates/package-json'
import { readmeContent } from '../src/templates/readme'

describe('envContent', () => {
  const ports = { web: 3000, db: 5433, meilisearch: 7700 }

  it('includes the provided secret key', () => {
    const content = envContent('my-secret-123', ports)
    expect(content).toContain('SECRET_KEY_BASE=my-secret-123')
  })

  it('includes all host ports', () => {
    const content = envContent('any', ports)
    expect(content).toContain('SPREE_PORT=3000')
    expect(content).toContain('SPREE_DB_PORT=5433')
    expect(content).toContain('SPREE_MEILISEARCH_PORT=7700')
  })

  it('includes the image version tag', () => {
    expect(envContent('any', ports)).toContain('SPREE_VERSION_TAG=latest')
  })

  it('uses custom port values', () => {
    const content = envContent('any', { web: 4567, db: 5434, meilisearch: 7701 })
    expect(content).toContain('SPREE_PORT=4567')
    expect(content).toContain('SPREE_DB_PORT=5434')
    expect(content).toContain('SPREE_MEILISEARCH_PORT=7701')
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

  it('includes convenience scripts using spree cli', () => {
    const pkg = JSON.parse(rootPackageJsonContent('my-store'))
    expect(pkg.scripts.dev).toBe('spree dev')
    expect(pkg.scripts.update).toBe('spree update')
    expect(pkg.scripts.eject).toBe('spree eject')
    expect(pkg.scripts.logs).toBe('spree logs')
    expect(pkg.scripts.console).toBe('spree console')
    expect(pkg.scripts.down).toContain('docker compose')
  })

  it('exposes the Admin API command groups as scripts', () => {
    const pkg = JSON.parse(rootPackageJsonContent('my-store'))
    expect(pkg.scripts.api).toBe('spree api')
    expect(pkg.scripts.auth).toBe('spree auth')
    expect(pkg.scripts['api-key']).toBe('spree api-key')
  })

  it('includes @spree/cli as a dependency', () => {
    const pkg = JSON.parse(rootPackageJsonContent('my-store'))
    expect(pkg.dependencies['@spree/cli']).toBeDefined()
  })

  it('is marked private', () => {
    const pkg = JSON.parse(rootPackageJsonContent('my-store'))
    expect(pkg.private).toBe(true)
  })
})

describe('readmeContent', () => {
  it('includes the project name as heading', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('# my-store')
  })

  it('includes admin credentials', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('spree@example.com')
    expect(content).toContain('spree123')
  })

  it('includes storefront section', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('storefront')
    expect(content).toContain('npm run dev')
  })

  it('includes eject instructions', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('spree eject')
    expect(content).toContain('backend/')
  })

  it('uses spree cli commands', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('`spree dev`')
    expect(content).toContain('`spree stop`')
    expect(content).toContain('`spree eject`')
    expect(content).toContain('`spree logs`')
    expect(content).toContain('`spree console`')
    expect(content).toContain('`spree update`')
    expect(content).toContain('`spree user create`')
    expect(content).toContain('`spree api-key create`')
  })

  it('uses custom port in URLs', () => {
    const content = readmeContent('my-store', true, 4567)
    expect(content).toContain('http://localhost:4567/admin')
    expect(content).toContain('http://localhost:4567/api/v3/store')
  })

  it('documents the Admin API and how to run the CLI directly', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('### Admin API')
    expect(content).toContain('npx spree api get products')
    expect(content).toContain('.spree/credentials.json')
    expect(content).toContain('npm install -g @spree/cli')
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

describe('dependabotContent', () => {
  it('covers the root wrapper, backend gems, and CI', () => {
    const content = dependabotContent(false)
    expect(content).toContain('version: 2')
    expect(content).toContain('package-ecosystem: npm\n    directory: "/"')
    expect(content).toContain('package-ecosystem: bundler\n    directory: "/backend"')
    expect(content).toContain('package-ecosystem: github-actions')
  })

  it('does not add docker ecosystems', () => {
    expect(dependabotContent(false)).not.toContain('package-ecosystem: docker')
    expect(dependabotContent(true)).not.toContain('package-ecosystem: docker')
  })

  it('omits the storefront ecosystem when there is no storefront', () => {
    const content = dependabotContent(false)
    expect(content).not.toContain('/apps/storefront')
  })

  it('adds the storefront npm ecosystem when the storefront is included', () => {
    const content = dependabotContent(true)
    expect(content).toContain('package-ecosystem: npm\n    directory: "/apps/storefront"')
  })

  it('groups security and version updates separately for each ecosystem', () => {
    const content = dependabotContent(true)
    // Each ecosystem gets a security group and a version group.
    expect(content).toContain('applies-to: security-updates')
    expect(content).toContain('applies-to: version-updates')
    // One security + one version group per ecosystem (4 ecosystems → 4 each).
    expect(content.match(/applies-to: security-updates/g)).toHaveLength(4)
    expect(content.match(/applies-to: version-updates/g)).toHaveLength(4)
    // Group names are unique per ecosystem.
    expect(content).toContain('root-security:')
    expect(content).toContain('backend-version:')
    expect(content).toContain('storefront-security:')
  })
})
