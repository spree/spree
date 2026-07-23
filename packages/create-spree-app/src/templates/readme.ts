import {
  DASHBOARD_PORT,
  DEFAULT_ADMIN_EMAIL,
  DEFAULT_ADMIN_PASSWORD,
  STOREFRONT_PORT,
} from '../constants.js'
import type { PackageManager } from '../types.js'
import { globalAddCommand, runCommand } from '../utils.js'

export function readmeContent(
  name: string,
  hasStorefront: boolean,
  port: number,
  hasDashboard = false,
  pm: PackageManager = 'pnpm',
): string {
  const run = runCommand(pm)
  let content = `# ${name}

A [Spree Commerce](https://spreecommerce.org) project.

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running

### Start the Spree API

\`\`\`bash
cd ${name}
${run} spree dev
\`\`\`

The first run completes setup automatically — it pulls the latest Spree image,
seeds the database, and configures API keys.

Wait for the services to be healthy, then open:

${
  hasDashboard
    ? `- **Admin Dashboard (React, Developer Preview):** http://localhost:${DASHBOARD_PORT} — started automatically by \`spree dev\`
  - Email: \`${DEFAULT_ADMIN_EMAIL}\`
  - Password: \`${DEFAULT_ADMIN_PASSWORD}\`
  - Classic admin: http://localhost:${port}/admin (same credentials)`
    : `- **Admin Dashboard:** http://localhost:${port}/admin
  - Email: \`${DEFAULT_ADMIN_EMAIL}\`
  - Password: \`${DEFAULT_ADMIN_PASSWORD}\``
}
- **Store API:** http://localhost:${port}/api/v3/store
`

  if (hasStorefront) {
    content += `
### Start the storefront

Dependencies are already installed during setup — just start it:

\`\`\`bash
cd apps/storefront
${pm} run dev
\`\`\`

Open http://localhost:${STOREFRONT_PORT}
`
  }

  if (hasDashboard) {
    content += `
### The React Dashboard (Developer Preview)

\`apps/dashboard/\` is your admin — a customizable React SPA (plugins, your
own pages, table tweaks) with live reload. \`spree dev\` starts it
automatically alongside the API; to run it on its own:

\`\`\`bash
cd apps/dashboard
${pm} run dev
\`\`\`

Open http://localhost:${DASHBOARD_PORT} and sign in with the admin email and
password above. The classic admin remains at http://localhost:${port}/admin.

When you deploy, the production image builds your dashboard and serves it at
\`/dashboard\` on the same origin as the API (\`${run} spree build --production\`).

To learn how to add pages, tweak tables, or build plugins, see the
[React Dashboard docs](https://spreecommerce.org/docs/developer/dashboard/overview).
`
  }

  content += `
## Customizing the Spree API

The \`backend/\` directory is the Spree API — a full Rails application serving the Store and Admin APIs (plus background jobs and transactional emails) that your storefront and dashboard talk to. By default, the project runs it from a prebuilt Docker image. To switch to building from your local copy:

\`\`\`bash
${run} spree eject
\`\`\`

This rebuilds the Docker image from \`backend/\` and restarts services. You can then:

- **Customize the API** by editing the files in \`backend/\`
- **Add gems** to \`backend/Gemfile\`
- **Add new resources** with \`spree generate model <name> <attributes>\`

## Spree CLI

This project uses [\`@spree/cli\`](https://spreecommerce.org/docs/developer/cli/quickstart) to manage the Spree API.

### Services

| Command | Description |
|---------|-------------|
| \`spree dev\` | Run the app in the foreground — streams logs, Ctrl+C stops it. First run completes setup automatically |
| \`spree stop\` | Stop the API services |
| \`spree update\` | Pull latest Spree image and restart (runs migrations automatically) |
| \`spree eject\` | Switch from prebuilt image to building from \`backend/\` |
| \`spree build --production\` | Build the production image — includes \`apps/dashboard\` when present |
| \`spree logs\` | View web server logs |
| \`spree logs worker\` | View background jobs logs |
| \`spree console\` | Open Rails console |

### Data

| Command | Description |
|---------|-------------|
| \`spree migrate\` | Install pending Spree migrations from gems, then run them or just run your own migrations |
| \`spree seed\` | Seed the database |
| \`spree sample-data\` | Load sample products, categories, images |

### Users & API Keys

| Command | Description |
|---------|-------------|
| \`spree user create\` | Create an admin user |
| \`spree api-key create\` | Create a publishable or secret API key |
| \`spree api-key list\` | List all API keys |
| \`spree api-key revoke <id>\` | Revoke an API key (ID from \`api-key list\`) |

### Generators

| Command | Description |
|---------|-------------|
| \`spree generate model Brand name:string slug:string:uniq\` | Generate a new database model |
| \`spree generate api_resource Brand name:string slug:string:uniq\` | Generate a new Spree API resource |
| \`spree generate subscriber OmsOrderSync order.completed\` | Generate a new event subscriber |
| \`spree generate migration AddPositionToSpreeBrands position:integer\` | Generate a new database migration |

### Admin API

Project setup mints a read-only secret key into \`.spree/credentials.json\` (gitignored), so the Admin API client works out of the box. If you skipped the setup step, \`spree api\` mints the key on first use instead:

\`\`\`bash
${run} spree api get products
${run} spree api get "orders?q[state_eq]=complete"
${run} spree api endpoints          # list endpoints + required scopes
${run} spree api status             # show resolved credentials + server reachability
\`\`\`

The pre-configured key is read-only. To write, create a scoped secret key and pass it via \`SPREE_API_KEY\`:

\`\`\`bash
${run} spree api-key create --scopes write_products
SPREE_API_KEY=sk_... ${run} spree api post products --data '{"name":"New product","prices":[{"currency":"USD","amount":"29.99"}]}'
\`\`\`

| Command | Description |
|---------|-------------|
| \`spree api get/post/patch/delete <path>\` | Call the Admin API directly |
| \`spree api endpoints\` | List Admin API endpoints with required scopes |
| \`spree auth login --profile <name>\` | Save named credentials for a remote store |

> **Running \`spree\` directly.** The commands above use \`${run}\` because \`@spree/cli\` is a local project dependency. You can also run any of the package scripts (e.g. \`${pm} run api -- get products\`), or install the CLI globally for a bare \`spree\` command:
>
> \`\`\`bash
> ${globalAddCommand(pm)} @spree/cli
> spree api get products
> \`\`\`

## Learn More

- [Spree Documentation](https://spreecommerce.org/docs)
- [Spree Discord](https://discord.spreecommerce.org)
- [Store API Reference](https://spreecommerce.org/docs/api-reference/store-api/introduction)
- [Admin API Reference](https://spreecommerce.org/docs/api-reference/admin-api/introduction)
- [CLI Reference](https://spreecommerce.org/docs/developer/cli/quickstart)
- [Spree GitHub](https://github.com/spree/spree)
`

  return content
}
