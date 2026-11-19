# create-spree-app

Create a [Spree Commerce](https://spreecommerce.org) project with one command. Spree is an open-source headless commerce platform: REST Store and Admin APIs with OpenAPI specs, TypeScript SDKs, webhooks, an MCP server and a built-in marketplace, with the backend running as a Docker image ([`ghcr.io/spree/spree`](https://github.com/orgs/spree/packages/container/package/spree)). You need only Node.js, Git and Docker.

The project includes the Spree API (Store and Admin APIs, and the MCP server at `/api/v3/admin/mcp`), the Admin Dashboard, an optional Next.js storefront, an optional marketplace seller panel, and the `spree` CLI for day-to-day work. Setup completes automatically: image pulled, database seeded, API keys configured.

## Requirements

- [Node.js](https://nodejs.org/) 20 or later, with npm 9 or later
- [Docker](https://docs.docker.com/get-docker/) running

`npm ERR! cb.apply is not a function` means your npm is too old for your Node.js version. Reinstall a current Node.js (it ships with a matching npm) and run the command again. See [Troubleshooting](https://spreecommerce.org/docs/developer/create-spree-app/quickstart#troubleshooting).

## Quick Start

```bash
npx create-spree-app my-store
```

| Flag | Description |
|------|-------------|
| `--no-dashboard` | Skip the Admin Dashboard app — the API still serves the built-in one at `/dashboard` (add your own copy later via `spree add dashboard`) |
| `--seller-dashboard` | Include the marketplace seller panel without asking |
| `--no-seller-dashboard` | Skip the marketplace seller panel (also available later via `spree add seller-dashboard`) |
| `--no-storefront` | Skip Next.js storefront setup |
| `--agent-skills` | Install the Spree agent skills without asking |
| `--no-agent-skills` | Skip installing the Spree agent skills (also available later via `spree add ai`) |
| `--docs-mcp` | Connect coding agents to the Spree docs MCP server without asking |
| `--no-docs-mcp` | Skip connecting coding agents to the Spree docs MCP server (also available later via `spree add ai`) |
| `--no-start` | Don't start Docker services (the first `dev` run completes setup instead) |
| `--port <number>` | Port for the Spree backend (default: `3000`) |
| `--use-npm` / `--use-yarn` / `--use-pnpm` | Package manager (auto-detected from how you run the command) |

## Documentation

The full guide — generated project structure, customization, deployment — lives on the docs site:

- [create-spree-app quickstart](https://spreecommerce.org/docs/developer/create-spree-app/quickstart)
- [Spree CLI](https://spreecommerce.org/docs/developer/cli/quickstart)
- [Deployment](https://spreecommerce.org/docs/developer/deployment/docker)

Just evaluating Spree? Skip self-hosting and use a [hosted sandbox](https://spreecommerce.org).

## License

MIT
