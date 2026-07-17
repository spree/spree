# create-spree-app

Scaffold a new [Spree Commerce](https://spreecommerce.org) project with a single command — a full Rails backend (the Spree API) running via Docker, an optional Next.js storefront, the React Dashboard behind `--react-dashboard`, and the `spree` CLI for day-to-day work. Setup completes automatically: image pulled, database seeded, API keys configured.

## Quick Start

```bash
npx create-spree-app my-store
```

| Flag | Description |
|------|-------------|
| `--react-dashboard` | Include the React Dashboard (Developer Preview — also available later via `spree add dashboard`) |
| `--no-storefront` | Skip Next.js storefront setup |
| `--no-sample-data` | Skip loading sample products |
| `--no-start` | Don't start Docker services (the first `pnpm dev` completes setup instead) |
| `--port <number>` | Port for the Spree backend (default: `3000`) |
| `--use-npm` / `--use-yarn` / `--use-pnpm` | Package manager (auto-detected from how you run the command) |

## Documentation

The full guide — generated project structure, customization, deployment — lives on the docs site:

- [create-spree-app quickstart](https://spreecommerce.org/docs/developer/create-spree-app/quickstart)
- [Spree CLI](https://spreecommerce.org/docs/developer/cli/quickstart)
- [Deployment](https://spreecommerce.org/docs/developer/deployment)

Just evaluating Spree? Skip self-hosting and use a [hosted sandbox](https://spreecommerce.org).

## License

MIT
