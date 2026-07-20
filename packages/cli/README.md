# @spree/cli

CLI for managing [Spree Commerce](https://spreecommerce.org) projects — Docker-based dev stack, generators, API keys, and a gh-style Admin API client.

Automatically included in projects created with [`create-spree-app`](https://spreecommerce.org/docs/developer/create-spree-app/quickstart). Can also be installed standalone:

```bash
npm install -g @spree/cli
spree <command>
```

## Commands

Run from your Spree project directory:

| Command | Description |
|---------|-------------|
| `spree dev` | Run the app in the foreground — streams logs, Ctrl+C stops it. First run completes setup automatically; co-runs the React Dashboard dev server when `apps/dashboard` exists |
| `spree stop` | Stop backend services |
| `spree update` | Pull the latest Spree image and restart (runs migrations automatically) |
| `spree eject` | Switch from the prebuilt image to building from `backend/` |
| `spree add dashboard` | Add the React Dashboard (Developer Preview) to an existing project |
| `spree build --production` | Build the production image — the Spree API plus your dashboard, in one |
| `spree console` / `spree shell` / `spree logs` | Rails console, container shell, log tailing |
| `spree migrate` / `spree seed` / `spree sample-data` | Database tasks |
| `spree generate …` | Spree generators (models, API resources, subscribers, migrations) |
| `spree user create` / `spree api-key …` | Admin users and scoped API keys |
| `spree api get/post/patch/delete <path>` | Call the Admin API directly (`spree api endpoints` lists routes + scopes) |
| `spree rspec` | Run the backend test suite inside the container |

## Documentation

The full command reference lives on the docs site — this README intentionally stays short:

- [CLI quickstart](https://spreecommerce.org/docs/developer/cli/quickstart)
- [Admin API from the CLI](https://spreecommerce.org/docs/developer/cli/admin-api) — credentials, scopes, profiles
- [create-spree-app](https://spreecommerce.org/docs/developer/create-spree-app/quickstart)
- [Deployment](https://spreecommerce.org/docs/developer/deployment/docker)

## License

MIT
