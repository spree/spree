import { DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD, STOREFRONT_PORT } from '../constants.js'

export function readmeContent(name: string, hasStorefront: boolean, port: number): string {
  let content = `# ${name}

A [Spree Commerce](https://spreecommerce.org) project.

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running

### Start the backend

\`\`\`bash
cd ${name}
npx spree dev
\`\`\`

Wait for the services to be healthy, then open:

- **Admin Dashboard:** http://localhost:${port}/admin
  - Email: \`${DEFAULT_ADMIN_EMAIL}\`
  - Password: \`${DEFAULT_ADMIN_PASSWORD}\`
- **Store API:** http://localhost:${port}/api/v3/store
`

  if (hasStorefront) {
    content += `
### Start the storefront

\`\`\`bash
cd apps/storefront
npm install
npm run dev
\`\`\`

Open http://localhost:${STOREFRONT_PORT}
`
  }

  content += `
## Customizing the Backend

The \`backend/\` directory contains a full Rails application with Spree installed. By default, the project uses a prebuilt Docker image. To switch to building from your local backend:

\`\`\`bash
npx spree eject
\`\`\`

This rebuilds the Docker image from \`backend/\` and restarts services. You can then:

- **Add gems** to \`backend/Gemfile\`
- **Override models** with decorators in \`backend/app/models/\`
- **Add controllers** in \`backend/app/controllers/\`
- **Configure Spree** in \`backend/config/initializers/spree.rb\`
- **Add migrations** with \`cd backend && bin/rails generate migration\`

## Spree CLI

This project uses [\`@spree/cli\`](https://www.npmjs.com/package/@spree/cli) to manage the backend.

### Services

| Command | Description |
|---------|-------------|
| \`spree dev\` | Run the backend in the foreground — streams logs, Ctrl+C stops it |
| \`spree stop\` | Stop backend services |
| \`spree update\` | Pull latest Spree image and restart (runs migrations automatically) |
| \`spree eject\` | Switch from prebuilt image to building from \`backend/\` |
| \`spree logs\` | View web server logs |
| \`spree logs worker\` | View background jobs logs |
| \`spree console\` | Open Rails console |

### Data

| Command | Description |
|---------|-------------|
| \`spree seed\` | Seed the database |
| \`spree sample-data\` | Load sample products, categories, images |

### Users & API Keys

| Command | Description |
|---------|-------------|
| \`spree user create\` | Create an admin user |
| \`spree api-key create\` | Create a publishable or secret API key |
| \`spree api-key list\` | List all API keys |
| \`spree api-key revoke <token>\` | Revoke an API key |

### Admin API

Project setup mints a read-only secret key into \`.spree/credentials.json\` (gitignored), so the Admin API client works out of the box. If you skipped the setup step, \`spree api\` mints the key on first use instead:

\`\`\`bash
npx spree api get products
npx spree api get "orders?q[state_eq]=complete"
npx spree api endpoints          # list endpoints + required scopes
npx spree api status             # show resolved credentials + server reachability
\`\`\`

The pre-configured key is read-only. To write, create a scoped secret key and pass it via \`SPREE_API_KEY\`:

\`\`\`bash
npx spree api-key create --scopes write_products
SPREE_API_KEY=sk_... npx spree api post products --data '{"name":"New product"}'
\`\`\`

| Command | Description |
|---------|-------------|
| \`spree api get/post/patch/delete <path>\` | Call the Admin API directly |
| \`spree api endpoints\` | List Admin API endpoints with required scopes |
| \`spree auth login --profile <name>\` | Save named credentials for a remote store |

> **Running \`spree\` directly.** The commands above use \`npx\` because \`@spree/cli\` is a local project dependency. You can also run any of the package scripts (e.g. \`npm run api -- get products\`), or install the CLI globally for a bare \`spree\` command:
>
> \`\`\`bash
> npm install -g @spree/cli
> spree api get products
> \`\`\`

## Learn More

- [Spree Documentation](https://docs.spreecommerce.org)
- [Store API Reference](https://docs.spreecommerce.org/api-reference/store)
- [Spree GitHub](https://github.com/spree/spree)
`

  return content
}
