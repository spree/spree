import type { PackageManager } from '../types.js'
import { runCommand } from '../utils.js'

export function agentsMdContent(): string {
  return `# Agent Instructions

See [CLAUDE.md](./CLAUDE.md) for full project instructions and conventions.

## Spree-specific agent skills

For deeper Spree-specific guidance (API conventions, the data model, event system,
testing patterns, security, deployment, the 6.0 React dashboard, the Next.js
storefront, etc.), install the official skill set:

\`\`\`bash
npx skills add spree/agent-skills
\`\`\`

Works for Claude Code, Codex, Cursor, GitHub Copilot, Cline, Aider, Zed, Windsurf,
and 60+ other agentic CLIs. See https://github.com/spree/agent-skills for the
full skill list.
`
}

export function rootClaudeMdContent(
  hasStorefront: boolean,
  hasDashboard = false,
  pm: PackageManager = 'pnpm',
): string {
  const run = runCommand(pm)
  const lines = [
    '# Spree Commerce Application',
    '',
    '## Project Structure',
    '',
    '| Directory | Description |',
    '|-----------|-------------|',
    '| `backend/` | Rails API application (Spree Commerce) |',
  ]

  if (hasStorefront) {
    lines.push('| `apps/storefront/` | Next.js storefront |')
  }

  if (hasDashboard) {
    lines.push('| `apps/dashboard/` | React Dashboard — admin SPA (Developer Preview) |')
  }

  lines.push(
    '',
    '## Agent Instructions',
    '',
    '- **Backend work** (Ruby/Rails, Spree models, API, database): See `backend/CLAUDE.md`',
  )

  if (hasStorefront) {
    lines.push(
      '- **Storefront work** (Next.js, React, TypeScript): See `apps/storefront/CLAUDE.md`',
    )
  }

  if (hasDashboard) {
    lines.push(
      '- **React Dashboard work** (admin SPA, React, TypeScript): See `apps/dashboard/README.md`',
      '  and https://spreecommerce.org/docs/developer/dashboard/overview',
    )
  }

  lines.push(
    '',
    '## Spree Documentation',
    '',
    'Full developer docs are installed locally:',
    '',
    '```',
    'node_modules/@spree/docs/dist/',
    '├── developer/',
    '│   ├── core-concepts/     # Products, orders, payments, inventory, etc.',
    '│   ├── customization/     # Decorators, extensions, configuration, dependencies',
    '│   ├── admin/             # Admin panel customization',
    '│   ├── storefront/        # Storefront building guides',
    '│   ├── sdk/               # TypeScript SDK documentation',
    '│   └── tutorial/          # Step-by-step tutorials',
    '├── api-reference/',
    '│   ├── store-api/         # Store API v3 guides',
    '│   ├── admin-api/         # Admin API v3 guides',
    '│   └── store.yaml         # OpenAPI 3.0 spec (all endpoints, params, schemas)',
    '└── integrations/          # Stripe, Meilisearch, etc.',
    '```',
    '',
    'Read these files when you need Spree-specific guidance.',
    '',
    '## Querying the Admin API',
    '',
    'Project setup mints a read-only secret key into `.spree/credentials.json`',
    '(gitignored) — and `spree api` mints it on first use if setup was skipped —',
    'so the Admin API client works without further configuration. Use it to',
    'inspect live data instead of guessing at the schema:',
    '',
    '```bash',
    `${run} spree api get products                      # list products`,
    `${run} spree api get "orders?q[state_eq]=complete" # Ransack filters`,
    `${run} spree api endpoints                         # every endpoint + its required scope`,
    `${run} spree api schema "POST /products"           # request/response schema for an operation`,
    '```',
    '',
    'The default key is read-only. For writes, create a scoped key and pass it via',
    `\`SPREE_API_KEY\`: \`${run} spree api-key create --scopes write_products\`, then`,
    `\`SPREE_API_KEY=sk_... ${run} spree api post products --data '{"name":"New product","prices":[{"currency":"USD","amount":"29.99"}]}'\`.`,
    '',
    '## Common Commands',
    '',
    '```bash',
    `${pm} run dev              # Start the Spree API (Docker)`,
    `${pm} run stop             # Stop services`,
    `${pm} run console          # Rails console`,
    `${pm} run logs             # Backend logs`,
    `${run} spree api get products  # Query the Admin API (read-only key preconfigured)`,
    `${run} spree eject          # Build the API locally from backend/`,
    '```',
    '',
  )

  return lines.join('\n')
}
