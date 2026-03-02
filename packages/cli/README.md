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

Start Docker services, print connection info, and stream web server logs.

```bash
spree dev
```

```
╭ Spree Commerce ─────────────────────╮
│                                     │
│  Admin Dashboard                    │
│    http://localhost:3000/admin       │
│    Email:    spree@example.com      │
│    Password: spree123               │
│                                     │
│  Store API                          │
│    http://localhost:3000/api/v3/store│
│                                     │
╰─────────────────────────────────────╯
```

Press `Ctrl+C` to stop streaming logs (services keep running).

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
spree api-key create --name "Admin Integration" --type secret
```

**Important:** Secret key tokens are displayed only once at creation time and cannot be retrieved later. Save them immediately.

### `spree api-key list`

List all API keys for the default store with their name, type, token/prefix, creation date, and status.

```bash
spree api-key list
```

```
  Name                      Type           Token                          Created            Status
  ────────────────────────────────────────────────────────────────────────────────────────────────
  My Storefront             publishable    pk_abc123def456...             2025-01-15 10:30   active
  Admin Integration         secret         sk_xyz789qwe...               2025-01-15 10:35   active
```

### `spree api-key revoke`

Revoke an API key by its token (publishable) or token prefix (secret).

```bash
spree api-key revoke pk_abc123def456...
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
