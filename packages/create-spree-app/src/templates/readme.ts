import { STOREFRONT_PORT, DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from '../constants.js'

export function readmeContent(name: string, hasStorefront: boolean, port: number): string {
  let content = `# ${name}

A [Spree Commerce](https://spreecommerce.org) project.

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running

### Start the backend

\`\`\`bash
npm run dev
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
## Useful Commands

| Command | Description |
|---------|-------------|
| \`npm run dev\` | Start backend services |
| \`npm run stop\` | Stop backend services |
| \`npm run down\` | Stop and remove backend services |
| \`npm run logs\` | View web server logs |
| \`npm run logs:worker\` | View background jobs logs |
| \`npm run console\` | Rails console |
| \`npm run seed\` | Seed the database |
| \`npm run load-sample-data\` | Load sample products |

## Learn More

- [Spree Documentation](https://docs.spreecommerce.org)
- [Store API Reference](https://docs.spreecommerce.org/api-reference/store)
- [Spree GitHub](https://github.com/spree/spree)
`

  return content
}
