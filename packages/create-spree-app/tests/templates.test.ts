import { describe, expect, it } from 'vitest'
import { rootClaudeMdContent } from '../src/templates/claude-md'
import { dependabotContent } from '../src/templates/dependabot'
import { dashboardEnvContent, envContent, storefrontEnvContent } from '../src/templates/env'
import { gitignoreContent } from '../src/templates/gitignore'
import { rootPackageJsonContent } from '../src/templates/package-json'
import { readmeContent } from '../src/templates/readme'

describe('envContent', () => {
  it('includes the provided secret key', () => {
    const content = envContent('my-secret-123', 3000)
    expect(content).toContain('SECRET_KEY_BASE=my-secret-123')
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

describe('dashboardEnvContent', () => {
  it('points VITE_SPREE_API_URL at the given port', () => {
    expect(dashboardEnvContent(4567)).toContain('VITE_SPREE_API_URL=http://localhost:4567')
  })

  it('contains no credentials — VITE_ values ship to every browser', () => {
    const content = dashboardEnvContent(3000)
    expect(content).not.toMatch(/pk_|sk_|KEY=(?!http)/)
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

  it('includes the React Dashboard section when included', () => {
    const content = readmeContent('my-store', true, 3000, true)
    expect(content).toContain('### Start the React Dashboard (Developer Preview)')
    expect(content).toContain('http://localhost:5173')
    expect(content).toContain('docs/developer/dashboard')
  })

  it('omits the React Dashboard section by default', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).not.toContain('React Dashboard')
  })
})

describe('rootClaudeMdContent', () => {
  it('lists apps/dashboard when the dashboard is included', () => {
    const content = rootClaudeMdContent(true, true)
    expect(content).toContain('`apps/dashboard/`')
    expect(content).toContain('docs/developer/dashboard')
  })

  it('omits apps/dashboard by default', () => {
    expect(rootClaudeMdContent(true)).not.toContain('apps/dashboard')
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

  it('adds the dashboard npm ecosystem when the dashboard is included', () => {
    const content = dependabotContent(true, true)
    expect(content).toContain('package-ecosystem: npm\n    directory: "/apps/dashboard"')
    expect(content).toContain('dashboard-security:')
  })

  it('omits the dashboard ecosystem by default', () => {
    expect(dependabotContent(true)).not.toContain('/apps/dashboard')
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
