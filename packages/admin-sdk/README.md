# @spree/admin-sdk

Official TypeScript SDK for the **Spree Commerce Admin API** — manage products, orders, customers, fulfillments, payments, and store configuration from server-to-server integrations or admin tooling.

> **Developer Preview.** The Admin API is in active development and may change between minor versions. Pin to a specific version of `@spree/admin-sdk` in production and review the [changelog](./CHANGELOG.md) before upgrading.

## Installation

```bash
npm install @spree/admin-sdk
```

## Quick start

```typescript
import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://store.example.com',
  secretKey: 'sk_xxx', // server-to-server; JWT auth for admin UIs also supported
})

const { data: orders } = await client.orders.list({
  status_eq: 'complete',
  sort: '-completed_at',
  limit: 25,
})

const customer = await client.customers.create({
  email: 'jane@example.com',
  first_name: 'Jane',
  last_name: 'Doe',
  tags: ['wholesale'],
})
```

## Documentation

The full guides live on the docs site — this README intentionally stays short:

- [Admin SDK quickstart](https://spreecommerce.org/docs/developer/sdk/admin/quickstart)
- [Authentication](https://spreecommerce.org/docs/developer/sdk/admin/authentication) — scoped secret keys vs. admin JWT
- [Resources](https://spreecommerce.org/docs/developer/sdk/admin/resources) — every resource client and its methods
- [Querying & errors](https://spreecommerce.org/docs/developer/sdk/admin/querying-and-errors) — filtering, sorting, pagination, `SpreeError`
- [Extending the client](https://spreecommerce.org/docs/developer/sdk/admin/extending) — custom endpoints
- [Admin API reference](https://spreecommerce.org/docs/api-reference/admin-api/introduction)

## Contributing

The SDK lives in the [spree/spree monorepo](https://github.com/spree/spree) under `packages/admin-sdk` — see the repository docs for the development setup and the serializer → types → Zod generation pipeline.

## License

MIT
