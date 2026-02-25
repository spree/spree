import { SPREE_PORT, STOREFRONT_PORT, DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from '../constants.js'

export function readmeContent(name: string, hasStorefront: boolean): string {
  let content = `# ${name}

A [Spree Commerce](https://spreecommerce.org) project.

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running

### Start the backend

\`\`\`bash
docker compose up -d
\`\`\`

Wait for the services to be healthy, then open:

- **Admin Dashboard:** http://localhost:${SPREE_PORT}/admin
  - Email: \`${DEFAULT_ADMIN_EMAIL}\`
  - Password: \`${DEFAULT_ADMIN_PASSWORD}\`
- **Store API:** http://localhost:${SPREE_PORT}/api/v3/store
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
## Useful Commands

| Command | Description |
|---------|-------------|
| \`docker compose up -d\` | Start backend services |
| \`docker compose down\` | Stop backend services |
| \`docker compose logs -f spree\` | View backend logs |
| \`docker compose exec spree bin/rails c\` | Rails console |
| \`docker compose exec spree bin/rails spree:load_sample_data\` | Load sample products |

## Learn More

- [Spree Documentation](https://docs.spreecommerce.org)
- [Store API Reference](https://docs.spreecommerce.org/api-reference/store)
- [Spree GitHub](https://github.com/spree/spree)
`

  return content
}
