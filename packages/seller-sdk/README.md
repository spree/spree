# @spree/seller-sdk

TypeScript client for the [Spree Commerce](https://spreecommerce.org) Seller API — the marketplace branch used by sellers to manage their own products, orders, fulfillments and payouts.

> **Beta.** Published under the `beta` tag while Spree 6.0 is in beta, and
> promoted to `latest` at 6.0 GA. Install it explicitly:
>
> ```bash
> npm install @spree/seller-sdk@beta
> ```

## Usage

```ts
import { createClient } from '@spree/seller-sdk'

const client = createClient({ baseUrl: 'https://your-store.com' })
const products = await client.products.list()
```

Sellers authenticate against the seller branch (`/seller/auth/*`), which issues its own token audience — a seller token is never an admin token.

## Documentation

- [Seller API reference](https://spreecommerce.org/docs/api-reference/seller-api/introduction) — endpoints, authentication, errors
- [Spree developer documentation](https://spreecommerce.org/docs)

## License

MIT
