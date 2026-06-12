# @spree/cli

CLI for managing [Spree Commerce](https://spreecommerce.org) projects.

Automatically included in projects created with [`create-spree-app`](https://www.npmjs.com/package/create-spree-app). Can also be installed standalone.

## Installation

Already included when you scaffold a project with `create-spree-app`. To install separately:

```bash
npm install @spree/cli
```

Or run directly with npx:

```bash
npx @spree/cli <command>
```

Or install globally:

```bash
npm install -g @spree/cli
spree <command>
```

## Commands

Run these from your Spree project directory.

### `spree dev`

Run the app in the foreground — prints connection info, then streams web + worker logs (like `vite dev`).

```bash
spree dev
```

Press `Ctrl+C` to stop web + worker. The databases (postgres, redis, meilisearch) keep running for a fast next boot — `spree stop` shuts everything down.

### `spree stop`

Stop all running services.

```bash
spree stop
```

### `spree update`

Pull the latest Spree Docker image and recreate containers. Database migrations run automatically on startup via `db:prepare`.

```bash
spree update
```

To pin a specific version, edit `SPREE_VERSION_TAG` in your `.env` file:

```
SPREE_VERSION_TAG=5.4
```

### `spree eject`

Switch from the prebuilt Docker image to building from your local `backend/` directory. This lets you customize the Rails app — add gems, override models, add migrations, etc.

```bash
spree eject
```

After ejecting, edit files in `backend/` and run `spree dev` to rebuild and restart.

### `spree logs [service]`

Stream logs from a service. Defaults to `web`.

```bash
spree logs          # web server logs
spree logs worker   # background job logs
```

### `spree console`

Open an interactive Rails console inside the running container.

```bash
spree console
```

### `spree user create`

Create an admin user. Prompts interactively for email and password, or accepts flags for scripting.

```bash
# Interactive
spree user create

# Non-interactive
spree user create --email admin@example.com --password secret123
```

The user is automatically assigned the `admin` role on the default store.

### `spree api-key create`

Create a Store API (publishable) or Admin API (secret) key. Prompts interactively for name and type, or accepts flags.

```bash
# Interactive
spree api-key create

# Non-interactive
spree api-key create --name "My Storefront" --type publishable
spree api-key create --name "Admin Integration" --type secret --scopes read_orders,write_products
```

Secret keys require at least one scope (`read_all` for a read-only key, `write_all` for full access, or granular `read_*`/`write_*` pairs).

**Important:** Secret key tokens are displayed only once at creation time and cannot be retrieved later. Save them immediately.

### `spree api-key list`

List all API keys for the default store with their name, type, token/prefix, creation date, and status.

```bash
spree api-key list
```

### `spree api-key revoke`

Revoke an API key by its token (publishable) or token prefix (secret).

```bash
spree api-key revoke pk_abc123def456...
```

### `spree api`

Call the Admin API directly with `gh api`-style generic verbs. Works against any Spree 5.5+ instance — inside a project it self-provisions a **read-only** key via the dev stack on first use (saved to `.spree/credentials.json`, gitignored); remote stores use `SPREE_BASE_URL`/`SPREE_API_KEY` env vars or saved profiles.

```bash
spree api get /products -q status_eq=active --sort -created_at --limit 10
spree api get /orders/ord_x8k2J9aQ --expand items,payments
spree api post /products -d '{"name":"Classic Tee"}'
spree api patch /orders/ord_x8k2J9aQ/cancel
spree api delete /products/prod_86Rf07xd

spree api endpoints --resource orders     # endpoints + required scopes (offline)
spree api schema "POST /orders"           # request/response schema (offline)
spree api status                          # resolved credentials + server check
```

Output is JSON on stdout (pipes into `jq`); `--format table` renders collections for humans. API errors exit `1` with the error envelope on stderr — scope denials include the exact `--scopes` remediation.

### `spree auth`

Manage saved Admin API credentials for remote stores (profiles in `~/.config/spree/config.json`).

```bash
spree auth login --profile prod --base-url https://store.example.com   # key read from a prompt
spree api get /orders --profile prod
spree auth status
spree auth list
spree auth logout --profile prod
```

### `spree seed`

Run database seeds.

```bash
spree seed
```

### `spree sample-data`

Load sample products, categories, customers, and images.

```bash
spree sample-data
```

## How It Works

The CLI detects your project by looking for `docker-compose.yml` in the current directory. All commands execute via `docker compose` against the running Spree containers.

- **Port** is read from `SPREE_PORT` in your `.env` file (default: `3000`)
- **User and API key commands** run Ruby scripts via `docker compose exec web bin/rails runner`
- **Service commands** (`dev`, `stop`, `update`) are thin wrappers around `docker compose`

## Using with npm scripts

Projects created with `create-spree-app` include convenience scripts in `package.json`:

```bash
npm run dev             # spree dev
npm run stop            # spree stop
npm run update          # spree update
npm run eject           # spree eject
npm run logs            # spree logs
npm run logs:worker     # spree logs worker
npm run console         # spree console
npm run seed            # spree seed
npm run load-sample-data # spree sample-data
```

## Learn More

- [Spree Documentation](https://docs.spreecommerce.org)
- [Store API Reference](https://docs.spreecommerce.org/api-reference/store)
- [create-spree-app](https://www.npmjs.com/package/create-spree-app)
- [Spree GitHub](https://github.com/spree/spree)

## License

MIT
