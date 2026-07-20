# @spree/dashboard

The Spree Commerce admin dashboard (the "React Dashboard") — a React single-page application that replaces the Classic Admin (the server-rendered Rails engine). Built on the [Admin API](https://spreecommerce.org/docs/api-reference/admin-api/introduction) via `@spree/admin-sdk`, with an extension model (nav, slots, tables, typed plugin routes) for plugin authors.

Part of the three-package dashboard stack with [`@spree/dashboard-core`](https://github.com/spree/spree/tree/main/packages/dashboard-core) (the framework and extension API) and [`@spree/dashboard-ui`](https://github.com/spree/spree/tree/main/packages/dashboard-ui) (the design system).

> **Developer Preview.** APIs may change between 0.x releases; in Spree 6 the React Dashboard becomes the default admin.

## Tech stack

Vite · TanStack Router (file-based, type-safe) · TanStack Query · React Hook Form + Zod · shadcn/ui + Base UI + Tailwind CSS · lucide-react · Recharts · Tiptap · Sonner · Biome.

## Using it

Don't wire this package by hand — scaffold a host app, which pins the stack and configures the Vite integration (`@spree/dashboard/vite`) for you:

```bash
# in a create-spree-app project (or pass --react-dashboard at create time)
spree add dashboard
```

The host consumes the exported `<Dashboard />` shell and `createDashboardRouter`, activates any installed dashboard plugins through auto-discovery, and composes their file routes into one typed route tree.

## Documentation

The full guides live on the docs site — this README intentionally stays short:

- [Overview](https://spreecommerce.org/docs/developer/dashboard/overview) & [concepts](https://spreecommerce.org/docs/developer/dashboard/concepts) — architecture, auth, permissions, multi-store
- [Customization](https://spreecommerce.org/docs/developer/dashboard/customization/quickstart) — your pages, nav, slots, tables, translations
- [Plugins](https://spreecommerce.org/docs/developer/dashboard/plugins/overview) — build and distribute dashboard extensions
- [Deployment](https://spreecommerce.org/docs/developer/dashboard/deployment) — served by the Spree server at `/dashboard` (default) or a CDN
- [Public API](https://spreecommerce.org/docs/developer/dashboard/public-api)

## Contributing

The dashboard lives in the [spree/spree monorepo](https://github.com/spree/spree) under `packages/dashboard` — see the repository docs (`CLAUDE.md`) for local development against a Spree backend and the Playwright E2E suite.

## License

MIT
