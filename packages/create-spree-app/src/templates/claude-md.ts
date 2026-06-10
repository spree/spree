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

export function rootClaudeMdContent(hasStorefront: boolean): string {
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
    '│   └── store.yaml         # OpenAPI 3.0 spec (all endpoints, params, schemas)',
    '└── integrations/          # Stripe, Meilisearch, etc.',
    '```',
    '',
    'Read these files when you need Spree-specific guidance.',
    '',
    '## Common Commands',
    '',
    '```bash',
    'npm run dev              # Start backend (Docker)',
    'npm run stop             # Stop services',
    'npm run console          # Rails console',
    'npm run logs             # Backend logs',
    'npx spree eject          # Switch to local backend builds',
    '```',
    '',
  )

  return lines.join('\n')
}
