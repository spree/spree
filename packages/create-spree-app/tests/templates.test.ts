import { describe, expect, it } from 'vitest'
import { rootClaudeMdContent } from '../src/templates/claude-md'
import { dependabotContent } from '../src/templates/dependabot'
import { envContent, storefrontEnvContent } from '../src/templates/env'
import { gitignoreContent } from '../src/templates/gitignore'
import { rootPackageJsonContent } from '../src/templates/package-json'
import { readmeContent } from '../src/templates/readme'

const keys = {
  primaryKey: 'pk-value',
  deterministicKey: 'dk-value',
  keyDerivationSalt: 'salt-value',
}

describe('envContent', () => {
  it('includes the Active Record encryption keys', () => {
    const content = envContent('any', 3000, 1025, 8025, keys)
    expect(content).toContain('ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=pk-value\n')
    expect(content).toContain('ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=dk-value\n')
    expect(content).toContain('ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=salt-value\n')
  })

  it('includes the provided secret key', () => {
    const content = envContent('my-secret-123', 3000, 1025, 8025, keys)
    expect(content).toContain('SECRET_KEY_BASE=my-secret-123')
  })

  it('includes SPREE_PORT', () => {
    const content = envContent('any', 3000, 1025, 8025, keys)
    expect(content).toContain('SPREE_PORT=3000')
  })

  it('uses custom port value', () => {
    const content = envContent('any', 4567, 1025, 8025, keys)
    expect(content).toContain('SPREE_PORT=4567')
  })

  // Mailpit publishes both ports on the host, so a second Spree project or any
  // local mail catcher takes them. The scaffold probes them and writes the
  // result, so compose never falls back to a default nobody checked was free.
  it('pins the probed Mailpit ports', () => {
    const content = envContent('any', 3000, 1026, 8026, keys)

    expect(content).toContain('MAILPIT_SMTP_PORT=1026')
    expect(content).toContain('MAILPIT_UI_PORT=8026')
  })
})

describe('storefrontEnvContent', () => {
  it('includes the key placeholder first-run setup replaces', () => {
    const content = storefrontEnvContent(3000)
    expect(content).toContain('SPREE_PUBLISHABLE_KEY=pk_REPLACE_ME_AFTER_DOCKER_START')
  })

  it('includes API URL with given port', () => {
    const content = storefrontEnvContent(3000)
    expect(content).toContain('SPREE_API_URL=http://localhost:3000')
  })

  it('uses custom port in API URL', () => {
    const content = storefrontEnvContent(4567)
    expect(content).toContain('SPREE_API_URL=http://localhost:4567')
  })

  it('omits the wholesale portal by default', () => {
    const content = storefrontEnvContent(3000)
    expect(content).not.toContain('SPREE_WHOLESALE_CHANNEL')
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

  it('SPREE_CLI_VERSION overrides the @spree/cli spec (unreleased-CLI testing)', () => {
    process.env.SPREE_CLI_VERSION = 'file:/tmp/spree-cli-local.tgz'
    try {
      const pkg = JSON.parse(rootPackageJsonContent('my-store'))
      expect(pkg.dependencies['@spree/cli']).toBe('file:/tmp/spree-cli-local.tgz')
    } finally {
      delete process.env.SPREE_CLI_VERSION
    }
    const pkg = JSON.parse(rootPackageJsonContent('my-store'))
    // The floor must admit every CLI capability the scaffold calls — the
    // seller-dashboard component landed in 3.0.
    expect(pkg.dependencies['@spree/cli']).toBe('^3.0.0')
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

  it('pins pnpm via packageManager for pnpm scaffolds', () => {
    const pkg = JSON.parse(rootPackageJsonContent('my-store', 'pnpm'))
    expect(pkg.packageManager).toMatch(/^pnpm@\d+\.\d+\.\d+$/)
  })

  it('omits packageManager for npm and yarn scaffolds', () => {
    for (const pm of ['npm', 'yarn'] as const) {
      const pkg = JSON.parse(rootPackageJsonContent('my-store', pm))
      expect(pkg.packageManager).toBeUndefined()
    }
  })
})

describe('readmeContent', () => {
  it('includes the project name as heading', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('# my-store')
  })

  // No dummy credentials are seeded any more — the admin account is created
  // during first run, so the README points there instead of printing a
  // well-known email and password.
  it('points at first-run setup instead of printing credentials', () => {
    const content = readmeContent('my-store', true, 3000, true)
    expect(content).toContain('setup link where you create the admin account')
    expect(content).not.toContain('spree@example.com')
    expect(content).not.toContain('spree123')
  })

  it('includes storefront section', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('storefront')
    expect(content).toContain('pnpm run dev')
  })

  it('includes eject instructions', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('spree eject')
    expect(content).toContain('server/')
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
    expect(content).toContain('http://localhost:4567/api/v3/store')
  })

  it('documents the Admin API and how to run the CLI directly', () => {
    const content = readmeContent('my-store', true, 3000)
    expect(content).toContain('### Admin API')
    expect(content).toContain('pnpm spree api get products')
    expect(content).toContain('.spree/credentials.json')
    expect(content).toContain('pnpm add -g @spree/cli')
  })

  it('renders commands for the chosen package manager', () => {
    const content = readmeContent('my-store', true, 3000, true, 'pnpm')
    expect(content).toContain('pnpm spree dev')
    expect(content).toContain('pnpm run dev')
    expect(content).toContain('pnpm add -g @spree/cli')
    expect(content).not.toContain('npx')
    expect(content).not.toMatch(/\bnpm /)
  })

  it('renders storefront commands with pnpm on yarn scaffolds (pnpm-pinned template)', () => {
    const content = readmeContent('my-store', true, 3000, true, 'yarn')
    expect(content).toContain('cd apps/storefront\npnpm run dev')
    expect(content).toContain('cd apps/dashboard\nyarn run dev')
  })

  it('includes the React Dashboard section when included', () => {
    const content = readmeContent('my-store', true, 3000, true)
    expect(content).toContain('### The React Dashboard')
    // The dashboard's dev server IS the admin in Spree 6 — the Rails admin
    // engine is gone, so the README must not point at /admin.
    expect(content).toContain('http://localhost:5173')
    expect(content).not.toMatch(/classic admin/i)
    expect(content).not.toContain('localhost:3000/admin')
    expect(content).toContain('Seller Panel')
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
    // Each app carries its own instructions; the root file points at them.
    expect(content).toContain('apps/dashboard/AGENTS.md')
    expect(content).toContain('apps/seller-dashboard/AGENTS.md')
  })

  it('renders commands for the chosen package manager', () => {
    const content = rootClaudeMdContent(true, true, 'pnpm')
    expect(content).toContain('pnpm run dev')
    expect(content).toContain('pnpm spree api get products')
    expect(content).not.toContain('npx spree')
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
  it('covers the root wrapper, server gems, and CI', () => {
    const content = dependabotContent(false)
    expect(content).toContain('version: 2')
    expect(content).toContain('package-ecosystem: npm\n    directory: "/"')
    expect(content).toContain('package-ecosystem: bundler\n    directory: "/server"')
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
    expect(content).toContain('server-version:')
    expect(content).toContain('storefront-security:')
  })
})
