import { STOREFRONT_PORT, DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from '../constants.js'

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
## Spree CLI

This project uses [\`@spree/cli\`](https://www.npmjs.com/package/@spree/cli) to manage the backend.

### Services

| Command | Description |
|---------|-------------|
| \`spree dev\` | Start backend services and stream logs |
| \`spree stop\` | Stop backend services |
| \`spree update\` | Pull latest Spree image and restart (runs migrations automatically) |
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

### Other

| Command | Description |
|---------|-------------|
| \`docker compose down\` | Stop and remove all containers and volumes |

## Updating Spree

\`\`\`bash
spree update
\`\`\`

To pin a specific version, edit \`SPREE_VERSION_TAG\` in \`.env\`:

\`\`\`
SPREE_VERSION_TAG=5.4
\`\`\`

## Learn More

- [Spree Documentation](https://docs.spreecommerce.org)
- [Store API Reference](https://docs.spreecommerce.org/api-reference/store)
- [Spree GitHub](https://github.com/spree/spree)
`

  return content
}
