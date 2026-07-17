# @spree/sdk

Official TypeScript SDK for the [Spree Commerce](https://spreecommerce.org) Store API v3 — fully typed resource clients, guest and customer authentication, carts and checkout, with runtime Zod schemas generated from the API's serializers.

## Installation

```bash
npm install @spree/sdk
```

## Quick Start

```typescript
import { createClient } from '@spree/sdk';

const client = createClient({
  baseUrl: 'https://api.mystore.com',
  publishableKey: 'spree_pk_xxx',
});

// Browse the catalog
const products = await client.products.list({ limit: 10, expand: ['variants', 'media'] });

// Cart + checkout
const cart = await client.carts.create();
await client.carts.items.create(cart.id, { variant_id: 'var_abc123', quantity: 2 }, { spreeToken: cart.token });

// Customer authentication (JWT)
const { token } = await client.auth.login({ email: 'customer@example.com', password: 'password123' });
const orders = await client.customer.orders.list({}, { token });
```

## Documentation

The full guides live on the docs site — this README intentionally stays short:

- [SDK quickstart](https://spreecommerce.org/docs/developer/sdk/quickstart)
- [Authentication](https://spreecommerce.org/docs/developer/sdk/authentication) — publishable key, customer JWT + refresh, guest cart tokens
- [Configuration](https://spreecommerce.org/docs/developer/sdk/configuration) — retries, custom fetch, error handling
- [Store resources](https://spreecommerce.org/docs/developer/sdk/store/products) — products, cart & checkout, payments, account, wishlists, markets
- [Extending the client](https://spreecommerce.org/docs/developer/sdk/extending) — custom endpoints
- [Store API reference](https://spreecommerce.org/docs/api-reference/store-api/introduction)

## License

MIT
