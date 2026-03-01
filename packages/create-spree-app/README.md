# create-spree-app

Scaffold a new [Spree](https://spreecommerce.org) project with a single command. Backend runs via Docker using pre-built images

## Quick Start

```bash
npx create-spree-app my-store
```

This will walk you through an interactive setup:

1. Choose **Full-stack** (Backend + Next.js Storefront) or **Backend only**
2. Optionally load sample data (products, categories, images)
3. Optionally start Docker services immediately

## CLI Flags

For non-interactive usage:

```bash
npx create-spree-app my-store --backend-only --no-sample-data --no-start
```

| Flag | Description |
|------|-------------|
| `--backend-only` | Skip storefront setup |
| `--no-sample-data` | Skip loading sample products |
| `--no-start` | Don't start Docker services |
| `--use-npm` | Use npm as package manager |
| `--use-yarn` | Use yarn as package manager |
| `--use-pnpm` | Use pnpm as package manager |

## What You Get

```
my-store/
├── docker-compose.yml    # Spree backend + Postgres
├── .env                  # SECRET_KEY_BASE, port, version tag
├── .gitignore
├── package.json          # @spree/cli + convenience scripts
├── README.md             # Getting started guide
└── apps/
    └── storefront/       # Next.js app (full-stack mode only)
```

## Prerequisites

- [Node.js](https://nodejs.org/) >= 20
- [Docker](https://docs.docker.com/get-docker/) (for running the backend)

## After Setup

### Admin Dashboard

Open http://localhost:3000/admin

- Email: `spree@example.com`
- Password: `spree123`

### Store API

http://localhost:3000/api/v3/store

### Storefront (full-stack mode)

```bash
cd my-store/apps/storefront
npm run dev
```

Open http://localhost:3001

## Useful Commands

Run these from your project directory (powered by [`@spree/cli`](https://www.npmjs.com/package/@spree/cli)):

| Command | Description |
|---------|-------------|
| `npm run dev` | Start backend services and stream logs |
| `npm run stop` | Stop backend services |
| `npm run down` | Stop and remove backend services |
| `npm run update` | Pull latest Spree image and restart (runs migrations automatically) |
| `npm run logs` | View backend logs |
| `npm run logs:worker` | View background jobs logs |
| `npm run console` | Rails console |
| `npm run seed` | Seed the database |
| `npm run load-sample-data` | Load sample products, categories |

You can also use the CLI directly for additional commands:

```bash
npx spree user create          # Create an admin user
npx spree api-key create       # Create an API key
npx spree api-key list          # List API keys
```

## Updating Spree

To update to the latest Spree version:

```bash
npm run update
```

This pulls the latest Docker image and recreates the containers. The entrypoint automatically runs `db:prepare`, which handles any pending database migrations.

To pin a specific version, edit `SPREE_VERSION_TAG` in `.env`:

```
SPREE_VERSION_TAG=5.4
```

## Learn More

- [Spree Documentation](https://docs.spreecommerce.org)

## License

MIT
