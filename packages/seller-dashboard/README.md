# @spree/seller-dashboard

The React seller panel for [Spree Commerce](https://spreecommerce.org) marketplaces — the surface a seller signs into to manage their products, orders and fulfillments. Built on the [Seller API](https://spreecommerce.org/docs/api-reference/seller-api/introduction) via `@spree/seller-sdk`.

> **Beta.** Published under the `beta` tag while Spree 6.0 is in beta, and
> promoted to `latest` at 6.0 GA. Install it explicitly:
>
> ```bash
> npm install @spree/seller-dashboard@beta
> ```

It shares its primitives with `@spree/dashboard` — components from `@spree/dashboard-ui`, framework pieces from `@spree/dashboard-core` — so the two panels stay visually and behaviourally consistent.

## Usage

Host it from a thin app that renders `<SellerDashboard />`. Scaffold one with:

```bash
npx spree add seller-dashboard
```

Rails serves the built bundle at `/sellers` when `SPREE_SELLER_PANEL_DIST_PATH` points at it — the Docker image built from the Spree starter does this for you.

## Documentation

- [Seller API reference](https://spreecommerce.org/docs/api-reference/seller-api/introduction) — the API this panel is built on
- [Spree developer documentation](https://spreecommerce.org/docs)

## License

MIT
