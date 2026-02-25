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
├── .env                  # SECRET_KEY_BASE for Rails
├── .gitignore
├── package.json          # Convenience scripts (dev, down, logs, etc.)
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

Run these from your project directory:

| Command | Description |
|---------|-------------|
| `npm run dev` | Start backend services |
| `npm run down` | Stop backend services |
| `npm run logs` | View backend logs |
| `npm run console` | Rails console |
| `npm run load-sample-data` | Load sample products, categories |

## Learn More

- [Spree Documentation](https://docs.spreecommerce.org)

## License

MIT
