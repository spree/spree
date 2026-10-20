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
import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({ baseUrl: 'https://your-store.com' })

const { token } = await client.auth.login({ email: 'owner@example.com', password: '…' })
client.setToken(token)

// Who is signed in, and which sellers they may act for
const { user, sellers } = await client.me.get()
client.setSeller(sellers[0].id)

const products = await client.products.list()

// The signed-in person's own account: name, photo and panel language
await client.me.update({ first_name: 'Ada', selected_locale: 'de' })
```

`client.me()` — the form in 1.0.0-beta.1 and beta.2 — still works but is deprecated and logs a one-time warning; use `client.me.get()`.

Sellers authenticate against the seller branch (`/seller/auth/*`), which issues its own token audience — a seller token is never an admin token.

## Documentation

- [Seller API reference](https://spreecommerce.org/docs/api-reference/seller-api/introduction) — endpoints, authentication, errors
- [Spree developer documentation](https://spreecommerce.org/docs)

## License

MIT
