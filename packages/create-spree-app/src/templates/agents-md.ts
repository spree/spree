import type { PackageManager } from '../types.js'
import { runCommand } from '../utils.js'

/**
 * Root CLAUDE.md for a generated project. Claude Code reads CLAUDE.md, not
 * AGENTS.md, so it imports AGENTS.md — the one file every agent shares.
 */
export function claudeMdContent(): string {
  return '@AGENTS.md\n'
}

/**
 * Root AGENTS.md for a generated project. Command examples are rendered for
 * the scaffold's package manager `pm` (default pnpm, matching detection).
 */
export function agentsMdContent(
  hasStorefront: boolean,
  hasDashboard = false,
  pm: PackageManager = 'pnpm',
  hasSellerDashboard = hasDashboard,
): string {
  const spree = `${runCommand(pm)} spree`
  const lines = [
    '# Spree Commerce Project',
    '',
    'Instructions for coding agents. `CLAUDE.md` only imports this file — edit this one.',
    '',
    '## Project Structure',
    '',
    '| Directory | Description | Agent instructions |',
    '|-----------|-------------|--------------------|',
    '| `server/` | The Spree API — a Rails application | `server/AGENTS.md` |',
  ]

  if (hasDashboard) {
    lines.push('| `apps/dashboard/` | Admin Dashboard — React SPA | `apps/dashboard/AGENTS.md` |')
  }

  if (hasSellerDashboard) {
    lines.push(
      '| `apps/seller-dashboard/` | Seller Panel — marketplace seller SPA | `apps/seller-dashboard/AGENTS.md` |',
    )
  }

  if (hasStorefront) {
    lines.push('| `apps/storefront/` | Next.js storefront | `apps/storefront/CLAUDE.md` |')
  }

  lines.push(
    '',
    'Read the instructions for the directory you are working in before changing anything there.',
    '',
    '## Run everything through the Spree CLI',
    '',
    'The Spree API, its database and its background jobs run in Docker containers managed by',
    'the Spree CLI (`@spree/cli`, installed in this directory). The CLI is the only supported',
    'way to run commands against the API.',
    '',
    `- Run it from this directory as \`${spree} <command>\`.`,
    '- **Never run `bin/rails`, `bin/rake`, `rake`, `bundle`, `rspec`, `bin/setup`, `bin/dev`, `ruby` or `rails` directly** —',
    '  not on the host and not through `docker compose exec`. They run against the wrong Ruby, the',
    '  wrong database, or no database at all.',
    '- **Never call `docker compose` directly.** The CLI picks the right compose files and environment.',
    `- **Don't use the \`package.json\` scripts in this directory** (\`${pm} run dev\`, \`${pm} run console\`, …).`,
    '  They are shortcuts for humans that wrap the CLI — call the CLI command itself.',
    `- When no dedicated command exists, fall back to \`${spree} rails <args>\`, \`${spree} rake <task>\` or`,
    `  \`${spree} exec <command>\`, which run inside the container.`,
    '',
    'The apps under `apps/` are ordinary JavaScript projects with their own tooling — inside them,',
    'follow their own instructions.',
    '',
    '```bash',
    `${spree} dev --no-open          # start the stack in the foreground (the developer usually has it running)`,
    `${spree} stop                   # stop it`,
    `${spree} restart                # reload after initializer changes`,
    `${spree} logs                   # API logs`,
    `${spree} console                # Rails console`,
    `${spree} migrate                # run pending migrations`,
    `${spree} generate <generator>   # Rails and Spree generators`,
    `${spree} add <extension>        # install an extension end to end (stripe, paypal, avatax, …)`,
    `${spree} bundle add <gem>       # add any other gem`,
    `${spree} rspec [path]           # run tests against the test database`,
    `${spree} routes                 # list routes`,
    `${spree} --help                 # every command`,
    '```',
    '',
    '`server/AGENTS.md` maps every Rails command to its CLI equivalent.',
    '',
    `Never run \`${spree} db:reset\` or \`${spree} eject\` without asking the developer first. The same goes for`,
    `\`${spree} add <extension>\` on a project that is not ejected, because it ejects the project.`,
    '',
    '### Changes to `server/` need an ejected project',
    '',
    'A new project runs the prebuilt Spree Docker image, so edits in `server/` — including files',
    `written by \`${spree} generate\` and gems added with \`${spree} bundle\` — have no effect until the`,
    `developer runs \`${spree} eject\`, which builds the API from \`server/\` with live reloading. The`,
    'project is ejected when `docker-compose.yml` mounts `./server:/rails`.',
    '',
    '## Querying the Admin API',
    '',
    'Project setup mints a read-only secret key into `.spree/credentials.json`',
    '(gitignored) — and `spree api` mints it on first use if setup was skipped —',
    'so the Admin API client works without further configuration. Use it to',
    'inspect live data instead of guessing at the schema:',
    '',
    '```bash',
    `${spree} api get products                      # list products`,
    `${spree} api get orders -q status_eq=placed    # Ransack filters`,
    `${spree} api endpoints                         # every endpoint + its required scope`,
    `${spree} api schema "POST /products"           # request/response schema for an operation`,
    '```',
    '',
    'The default key is read-only. For writes, create a scoped key and pass it via',
    `\`SPREE_API_KEY\`: \`${spree} api-key create --name "Agent writes" --type secret --scopes write_products\`, then`,
    `\`SPREE_API_KEY=sk_... ${spree} api post products --data '{"name":"New product","prices":[{"currency":"USD","amount":"29.99"}]}'\`.`,
    '',
    '## Spree Documentation',
    '',
    'The full developer documentation is installed locally as Markdown:',
    '',
    '```',
    'node_modules/@spree/docs/dist/',
    '├── developer/',
    '│   ├── core-concepts/     # Products, orders, payments, inventory, etc.',
    '│   ├── customization/     # Events, workflow hooks, dependencies, extensions',
    '│   ├── cli/               # Every Spree CLI command',
    '│   ├── dashboard/         # Admin Dashboard: customization, recipes, plugins',
    '│   ├── storefront/        # Storefront building guides',
    '│   ├── sdk/               # TypeScript SDK documentation',
    '│   └── tutorial/          # Step-by-step tutorials',
    '├── api-reference/',
    '│   ├── store-api/         # Store API v3 guides',
    '│   ├── admin-api/         # Admin API v3 guides',
    '│   ├── store.yaml         # Store API OpenAPI spec (endpoints, params, schemas)',
    '│   └── admin.yaml         # Admin API OpenAPI spec',
    '└── integrations/          # Stripe, Meilisearch, etc.',
    '```',
    '',
    'Read these files when you need Spree-specific guidance.',
    '',
    '## Spree agent skills',
    '',
    'The official Spree skills cover API conventions, the data model, events, testing,',
    'security, deployment, the Admin Dashboard and the storefront. If `.agents/skills/`',
    `is missing, install them with \`${spree} add ai --no-mcp\`.`,
    '',
  )

  return lines.join('\n')
}
