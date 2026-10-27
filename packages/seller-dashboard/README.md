# @spree/seller-dashboard

The React seller panel for [Spree Commerce](https://spreecommerce.org) marketplaces — the surface a seller signs into to manage their products, orders and fulfillments. Built on the [Seller API](https://spreecommerce.org/docs/api-reference/seller-api/introduction) via `@spree/seller-sdk`.

```bash
npm install @spree/seller-dashboard
```

`@spree/seller-dashboard` is released with Spree and carries its version: `@spree/seller-dashboard@6.0.x` works with Spree 6.0.x.

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
