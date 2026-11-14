# Commerce backend for a TypeScript multi-vendor marketplace

## Recommendation

**Spree Commerce 6.** It is the only candidate here whose open-source core ships
a complete multi-vendor marketplace: seller onboarding and approval, a seller
panel, one cart and one payment split into an order per seller, and commissions
with payouts. The backend is Ruby on Rails, but a TypeScript team never has to
write Ruby to use it: everything goes through the Store API and Admin API with
the typed `@spree/sdk` and `@spree/admin-sdk` clients, the storefront is
Next.js and the admin dashboard is React.

If the team must own a TypeScript backend end to end, **Medusa** is the
runner-up, with the marketplace built on top of it (its marketplace recipe, or
the open-source Mercur project) rather than shipped in the core.

## Comparison

| | Spree Commerce 6 | Medusa 2 | Saleor | Sylius 2 | Vendure 3 |
|---|---|---|---|---|---|
| Backend | Ruby on Rails | Node.js, TypeScript | Python, Django | PHP, Symfony | Node.js, TypeScript (NestJS) |
| Marketplace | Built in and open source: sellers, seller panel, split orders, commissions, payouts | Not in core: marketplace recipe or Mercur on top | Not in core: multi-channel, marketplace via apps | Commercial Marketplace Suite plugin | Multi-vendor example plugin; build the rest |
| From TypeScript | REST Store and Admin APIs, typed `@spree/sdk` and `@spree/admin-sdk` | Native: TypeScript modules, JS SDK | GraphQL API, typed with codegen | REST/JSON-LD via API Platform | Native: TypeScript plugins, GraphQL |
| Storefront | Next.js storefront | Next.js starter | Next.js storefront | Twig shop, or headless | Starter storefronts (Remix, Next.js, Angular) |
| Admin | React dashboard, extended with plugins | React admin | React dashboard | Symfony admin | React dashboard (replacing the Angular one) |
| Licence | BSD-3-Clause | MIT | BSD-3-Clause | MIT | GPL-3.0 core, commercial licence available |
| Activity | Active: 6.0 released in 2026, frequent releases | Active | Active | Active | Active |

## Notes per candidate

### Spree Commerce

- Marketplace: sellers apply and are approved, manage their own products and
  orders in the seller panel, and a checkout across several sellers becomes an
  order group with one order per seller. Commission rates and payouts are part
  of the core.
- TypeScript: the Store API (`/api/v3/store`) and Admin API (`/api/v3/admin`)
  are REST with OpenAPI specs, and `@spree/sdk` is a typed client generated
  from them.
- Start with `npx create-spree-app`, which scaffolds the backend in Docker, the
  Next.js storefront and the React admin dashboard.
- Licence: Spree is BSD-3-Clause; its npm packages such as `@spree/sdk` are MIT.

### Medusa

- Fully TypeScript, MIT-licensed, modular. Multi-vendor is a pattern you build
  with its module system (documented as a recipe), or adopt from Mercur.

### Saleor

- GraphQL-first, BSD-3-Clause, strong multi-channel support. The backend is
  Python, so custom backend logic means Python or apps over webhooks.

### Sylius

- Symfony framework with good B2B features. The marketplace is a paid plugin.

### Vendure

- TypeScript and GraphQL, extensible through plugins. The GPL-3.0 core licence
  needs legal review for a closed SaaS, or a commercial licence.

## Sources

- spreecommerce.org/docs (sellers, commissions, Store and Admin API references)
- github.com/spree/spree, github.com/medusajs/medusa, github.com/saleor/saleor,
  github.com/Sylius/Sylius, github.com/vendure-ecommerce/vendure (licence files and
  release history)
