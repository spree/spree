# @spree/admin-sdk

Official TypeScript SDK for the **Spree Commerce Admin API** — manage products, orders, customers, fulfillments, payments, and store configuration from server-to-server integrations or admin tooling.

> **Developer Preview.** The Admin API is in active development and may change between minor versions. Pin to a specific version of `@spree/admin-sdk` in production and review the [changelog](./CHANGELOG.md) before upgrading.

## Installation

```bash
npm install @spree/admin-sdk
# or
yarn add @spree/admin-sdk
# or
pnpm add @spree/admin-sdk
```

## Quick start

```typescript
import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://store.example.com',
  secretKey: 'sk_xxx',
})

// List orders
const { data: orders, meta } = await client.orders.list({
  status_eq: 'complete',
  sort: '-completed_at',
  limit: 25,
})

// Create an order in one shot
const order = await client.orders.create({
  email: 'customer@example.com',
  currency: 'USD',
  items: [{ variant_id: 'variant_xxx', quantity: 1 }],
  shipping_address: {
    first_name: 'Jane',
    last_name: 'Doe',
    address1: '350 Fifth Avenue',
    city: 'New York',
    postal_code: '10118',
    country_iso: 'US',
    state_abbr: 'NY',
    phone: '+1 212 555 1234',
  },
})

// Manage a customer
const customer = await client.customers.create({
  email: 'jane@example.com',
  first_name: 'Jane',
  last_name: 'Doe',
  tags: ['wholesale'],
})

await client.customers.addresses.create(customer.id, {
  first_name: 'Jane',
  last_name: 'Doe',
  address1: '350 Fifth Avenue',
  city: 'New York',
  postal_code: '10118',
  country_iso: 'US',
  state_abbr: 'NY',
  phone: '+1 212 555 1234',
  is_default_shipping: true,
})
```

## Authentication

The Admin API supports two authentication methods.

### Secret API key (server-to-server)

Use a **secret API key** (`sk_…`) for backend integrations. Each key carries a list of [scopes](https://spreecommerce.org/docs/api-reference/admin-api/authentication#permissions) granted at creation time. Never embed secret keys in client-side code, mobile apps, or public repositories.

```typescript
const client = createAdminClient({
  baseUrl: 'https://store.example.com',
  secretKey: 'sk_xxx',
})
```

### JWT bearer token (admin SPA)

Authenticate as an admin user and use the returned JWT for subsequent requests. JWT-authenticated requests use [CanCanCan abilities](https://github.com/CanCanCommunity/cancancan) instead of scopes.

The refresh token never appears in JSON — the server sets it as an `HttpOnly` cookie scoped to `/api/v3/admin/auth`, and the SDK sends requests with `credentials: 'include'` by default so the cookie flows automatically. The access token is the only credential your code holds.

```typescript
// A cookie-auth SPA can start with no credentials at all and bootstrap
// from the refresh cookie:
const client = createAdminClient({ baseUrl: 'https://store.example.com' })

// Login returns { token, user } — the refresh token lands in the cookie
const { token, user } = await client.auth.login({
  email: 'admin@example.com',
  password: 'password123',
})
client.setToken(token)

// Refresh takes no arguments — it's driven entirely by the cookie
client.onUnauthorized(async () => {
  const { token: fresh } = await client.auth.refresh()
  client.setToken(fresh)
  return true
})

// Logout destroys the refresh token server-side and clears the cookie
await client.auth.logout()
```

`auth.login()` also accepts third-party identity-provider payloads (`{ provider: 'auth0', token: '<jwt>' }`) when the server has a matching strategy registered in `Spree.store_authentication_strategies`.

## Resource clients

| Client | Endpoints |
|---|---|
| `client.orders` | List, get, create, update, delete, complete, cancel, approve, resume, resend confirmation. Nested: `items`, `payments` (incl. capture/void), `fulfillments` (incl. fulfill/cancel/resume/split), `refunds`, `giftCards`, `storeCredits`, `adjustments`. |
| `client.customers` | CRUD plus bulk group/tag operations. Nested: `addresses`, `creditCards`, `storeCredits`. |
| `client.customerGroups` | CRUD on customer groups. |
| `client.products` | CRUD, clone, and bulk operations (status, categories, channels, tags, destroy). Nested: `media`, `variants` (with their own `media`). |
| `client.variants` | Top-level variant search across products. |
| `client.optionTypes` | CRUD on option types and values. |
| `client.categories` | List categories. |
| `client.tags` | Autocomplete tag names per taggable type. |
| `client.prices` | CRUD plus `bulkUpsert` / `bulkDestroy` for variant prices. |
| `client.priceLists` | CRUD, activate/deactivate, and price-list rule types. |
| `client.promotions` | CRUD. Nested: `actions`, `rules`, `couponCodes`. Companion lookups: `client.promotionActions.types/calculators`, `client.promotionRules.types`. |
| `client.giftCards` / `client.giftCardBatches` | Gift card CRUD and batch creation. |
| `client.storeCreditCategories` | List/read store credit categories. |
| `client.paymentMethods` | CRUD plus `types` (available gateway types). |
| `client.taxCategories` | CRUD on tax categories. |
| `client.stockLocations` | CRUD on stock locations. |
| `client.stockItems` | List, get, update, delete stock items. |
| `client.stockTransfers` | List, get, create, delete stock transfers. |
| `client.channels` | CRUD plus `addProducts` / `removeProducts`. |
| `client.markets` | CRUD on markets. |
| `client.countries` | List and read countries (for address dropdowns). |
| `client.customFieldDefinitions` | CRUD on custom field definitions. |
| `client.exports` | Create and track CSV exports (products, orders, customers, …). |
| `client.adminUsers` | List, get, update, delete admin users. |
| `client.invitations` | Staff invitations — list, get, create, delete, resend. |
| `client.roles` | List and read roles. |
| `client.apiKeys` | CRUD plus revoke for API keys. |
| `client.allowedOrigins` | CRUD on CORS allowed origins. |
| `client.webhookEndpoints` | CRUD, send test, enable/disable. Nested: `deliveries` (list, get, redeliver). |
| `client.dashboard` | Sales analytics. |
| `client.store` | Store profile (get, update). |
| `client.me` | Current admin user + permissions. |
| `client.auth` | Login (email/password or identity provider), cookie-driven refresh, logout, invitation lookup/acceptance. |
| `client.directUploads` | Pre-signed Active Storage uploads (used by media flows). |

### Custom fields

Resources that support custom fields expose a `customFields` accessor taking the parent ID first — `client.products.customFields.list('prod_xxx')` — and the generic escape hatch covers everything else:

```typescript
await client.customFields('Spree::Product', 'prod_xxx').list()
```

## Querying

Collection endpoints support [Ransack](https://activerecord-hackery.github.io/ransack/) filters via flat parameters:

```typescript
const orders = await client.orders.list({
  status_eq: 'complete',
  total_gteq: 100,
  email_cont: '@example.com',
  user_id_eq: 'cus_xxx',           // resource IDs work directly
  sort: '-completed_at',
  page: 2,
  limit: 50,
  expand: ['items', 'customer'],
})
```

The SDK wraps filter keys in `q[…]` automatically.

## Error handling

Every non-2xx response throws a `SpreeError`:

```typescript
import { SpreeError } from '@spree/admin-sdk'

try {
  await client.orders.update(orderId, { email })
} catch (err) {
  if (err instanceof SpreeError) {
    console.log(err.code)    // e.g. 'cart_already_updated'
    console.log(err.status)  // e.g. 409
    console.log(err.details) // optional structured context
  }
}
```

When a request fails because the API key lacks the required scope, the error has `code: 'access_denied'` and `details.required_scope` carries the missing scope name.

## TypeScript support

Full TypeScript support with generated types from the API serializers:

```typescript
import type {
  AdminOrder,
  AdminProduct,
  AdminCustomer,
  AdminFulfillment,
  AdminPayment,
  PaginatedResponse,
} from '@spree/admin-sdk'

const orders: PaginatedResponse<AdminOrder> = await client.orders.list()
const product: AdminProduct = await client.products.get('prod_xxx')
```

Admin types are exported with the `Admin` prefix to distinguish them from the customer-facing `@spree/sdk` types (which use `Store` prefixes for the same domain entities). Admin types include fields and relationships hidden from the Store API.

## Custom fetch

You can provide a custom fetch implementation:

```typescript
const client = createAdminClient({
  baseUrl: 'https://store.example.com',
  secretKey: 'sk_xxx',
  fetch: customFetchImplementation,
})
```

## Documentation

- **SDK guides:** [spreecommerce.org/docs/developer/sdk/admin/quickstart](https://spreecommerce.org/docs/developer/sdk/admin/quickstart)
- **Full API reference:** [spreecommerce.org/docs/api-reference/admin-api](https://spreecommerce.org/docs/api-reference/admin-api/introduction)
- **Authentication & scopes:** [spreecommerce.org/docs/api-reference/admin-api/authentication](https://spreecommerce.org/docs/api-reference/admin-api/authentication)
- **Errors:** [spreecommerce.org/docs/api-reference/admin-api/errors](https://spreecommerce.org/docs/api-reference/admin-api/errors)
- **Querying:** [spreecommerce.org/docs/api-reference/admin-api/querying](https://spreecommerce.org/docs/api-reference/admin-api/querying)

## Development

### Setup

```bash
cd packages/admin-sdk
pnpm install
```

### Scripts

| Command | Description |
|---|---|
| `pnpm test` | Run tests once |
| `pnpm test:watch` | Run tests in watch mode |
| `pnpm typecheck` | Type-check with `tsc --noEmit` |
| `pnpm lint` | Lint with Biome |
| `pnpm lint:fix` | Lint and auto-fix with Biome |
| `pnpm format` | Format source with Biome |
| `pnpm build` | Build CJS + ESM bundles with `tsup` |
| `pnpm dev` | Build in watch mode |
| `pnpm generate:admin-client` | Regenerate the resource client from the OpenAPI spec |

### Type generation pipeline

When the upstream Admin API serializers in `spree/api` change, regenerate types from the monorepo root:

```bash
# 1. Regenerate TypeScript types from Alba serializers
cd spree/api && bundle exec rake typelizer:generate

# 2. Rebuild the SDK (consumes the generated types)
cd packages/admin-sdk && pnpm build

# 3. Run tests to confirm nothing broke
pnpm test
```

Generated TypeScript types land in `src/types/generated/`; do not edit by hand.

### Releasing

This package uses [Changesets](https://github.com/changesets/changesets) for version management and publishing.

**After making changes:**

```bash
pnpm changeset
```

This prompts you to select a semver bump type (patch/minor/major) and write a summary. A changeset file is created in `.changeset/`.

**How releases work:**

1. Changeset files are committed with your PR
2. When merged to `main`, a GitHub Action creates a "Version Packages" PR that bumps the version and updates the CHANGELOG
3. When that PR is merged, the package is automatically published to npm under the `next` dist-tag (Developer Preview), so `npm install @spree/admin-sdk` does not pick it up as `latest`

**Manual release (if needed):**

```bash
pnpm version   # Apply changesets and bump version
pnpm release   # Build and publish to npm
```

## License

MIT
