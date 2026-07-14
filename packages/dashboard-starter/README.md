# Spree Dashboard Starter

The host app for the [Spree React Dashboard](https://spreecommerce.org/docs/developer/dashboard/overview) — the admin for your Spree store. `@spree/dashboard` is the actual app shell (routes, chrome, resource pages); this project is your customization point: plugins, your own pages, theming, and deployment config.

> **Monorepo note.** The canonical source of this template lives at `packages/dashboard-starter` in [spree/spree](https://github.com/spree/spree), where its Spree dependencies resolve via the pnpm workspace and `@spree/dashboard-plugin-example` is installed as a devDependency — booting it here doubles as the end-to-end test for the plugin pipeline. At build time, `@spree/cli` and `create-spree-app` embed a standalone rendering of it (workspace deps rewritten to the published versions — see `scripts/sync-dashboard-starter.mjs`), which is what `spree add dashboard` and the create-spree-app dashboard prompt scaffold from.

## Develop

```bash
pnpm install
cp .env.example .env.local   # point VITE_SPREE_API_URL at your Spree API
pnpm dev                     # http://localhost:5173
```

Sign in with an admin account — authentication is interactive (JWT + refresh cookie). No API keys belong in `.env.local`: every `VITE_`-prefixed value is compiled into the client bundle.

## Install a dashboard plugin

```bash
pnpm add @acme/reviews-plugin
# restart the dev server
```

That's the whole install. `spreeDashboardPlugin()` (see `vite.config.ts`) discovers any dependency carrying the `spree.dashboard.plugin` marker, activates it through the `virtual:spree-dashboard-plugins` module imported in `src/main.tsx`, and wires its Tailwind classes.

## Customize

`src/plugins.ts` is yours — register nav entries, routes, slot widgets, and table columns with `defineDashboardPlugin` from `@spree/dashboard-core`. Same API the distributed plugins use; see the [customization quickstart](https://spreecommerce.org/docs/developer/dashboard/customization/quickstart).

## Build & deploy

```bash
pnpm build    # static assets in dist/
```

Deploy `dist/` to any static host. Set `VITE_SPREE_API_URL` to your production API at build time, and configure the API's CORS/cookie settings for the dashboard origin.
