# @spree/admin package

## Overview

This is the new admin dashboard for Spree using Spree Admin API (via Spree SDK package in `../sdk`) which will replace existing Rails (full-stack/monolith) admin dashboard located in `../../spree/admin`.

This package will be installed as a dependency when developer creates a new Spree project using `create-spree-app`.

Admin SDK documentation: `packages/sdk/ADMIN_SDK.md`

## Authentication

Authentication is handled by the Spree SDK package via the `secretKey` configuration option. You need a secreat key to use this package. Should read `SPREE_SECRET_KEY` environment variable by default. We also need to support `SPREE_API_URL` environment variable pointing to the Spree backend API (defaults to `http://localhost:3000`)

User authentication is handled via JWT short lived tokens. Everything is built into the Spree SDK package.

```typescript
import { createSpreeClient } from '@spree/sdk';

// Initialize the client
const client = createSpreeClient({
  baseUrl: process.env.SPREE_API_URL,
  secretKey: process.env.SPREE_SECRET_KEY,
});

// Authentication
const { token, user } = await client.admin.auth.login({
  email: 'customer@example.com',
  password: 'password123',
});
```

## Conventions

We should use conventions when handling forms, lists, and other UI components to reduce boilerplate and make it easier for developers to extend the admin dashboard.

## Tech stack

Let's remember to use the newest versions of each library (as of March 2026).

* Build & Dev: Vite (obvious choice for a pure client-side SPA — fast HMR, clean config, outputs static files you can bundle into the Rails gem or deploy standalone)
* Routing: TanStack Router — type-safe routes, file-based convention, built-in loader pattern pairs perfectly with TanStack Query for prefetching on navigation
* Data Fetching: TanStack Query — handles caching, background refetches, optimistic updates. Your @spree/admin-sdk becomes the query function layer. Wrap SDK methods as custom hooks (useProducts, useOrder, etc.)
* Forms: React Hook Form + Zod for validation schemas. Zod schemas can mirror your API contracts, and if you're auto-generating types from OpenAPI specs, you can derive Zod schemas from the same source
* UI: shadcn/ui + Tailwind. Copy-paste ownership model means your plugin authors can extend or override components without fighting a component library's abstraction
* Auth: For JWT — store the access token in memory (React context/state), refresh token in an httpOnly cookie if possible, or memory as fallback. TanStack Router's beforeLoad guards check auth state before rendering protected routes. A simple AuthProvider context that exposes login(), logout(), getToken() and injects the token into the SDK client instance
* State: You likely don't need a global state library. TanStack Query covers server state, React Hook Form covers form state, and a small AuthContext covers the session. If something edges toward complex client-only state later, Zustand is the lightest option that won't fight you
* Linting/Formatting: Biome — single tool, fast, no ESLint/Prettier config sprawl
* Testing: Vitest + React Testing Library for unit/integration, Playwright for E2E

## Extension points

Developers will be able to extend the admin dashboard by adding custom pages, components, and logic.

There are 3 main areas where developers can extend the admin dashboard:

1. Navigation - needs to be configurable via registry
2. Tables - record listing, eg. products, orders. Developers need to be able to customize table columns and filters.
3. Pages - developers should be able to add custom pages, extend routes, and add custom logic.
3. Components - developers should be able to add custom components and extend existing ones. Developers should be able to inject their own components into existing pages, eg. new fields on product form page.

## Design

We can inspire from the rails admin dashboard design, located at `../../spree/admin` (look for `spree_admin.html.erb` layout file and stylesheets located at `../../spree/admin/assets/tailwind`).
