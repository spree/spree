# create-spree-app

Scaffold a new [Spree Commerce](https://spreecommerce.org) project with a single command — a full Rails backend (the Spree API) running via Docker, an optional Next.js storefront, the Admin Dashboard and an optional marketplace seller panel, and the `spree` CLI for day-to-day work. Setup completes automatically: image pulled, database seeded, API keys configured.

## Quick Start

```bash
npx create-spree-app my-store
```

| Flag | Description |
|------|-------------|
| `--no-dashboard` | Skip the Admin Dashboard app — the API still serves the built-in one at `/dashboard` (add your own copy later via `spree add dashboard`) |
| `--no-seller-dashboard` | Skip the marketplace seller panel (also available later via `spree add seller-dashboard`) |
| `--no-storefront` | Skip Next.js storefront setup |
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
