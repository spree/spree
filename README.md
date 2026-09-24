<p>
  <a href="https://spreecommerce.org">
    <img src="https://spreecommerce.org/wp-content/themes/spree/images/logo.svg" alt="Spree Commerce open source headless eCommerce platform for B2B, Multi-seller Marketplace, cross-border eCommerce, multi-tenant eCommerce" width="250" />
  </a>
</p>

[Website](https://spreecommerce.org)
·
[Next.js Storefront](https://github.com/spree/storefront)
·
[Documentation](https://spreecommerce.org/docs/)
·
[API](https://spreecommerce.org/docs/api-reference/)
·
[Roadmap](https://github.com/spree/spree/milestones?direction=asc&sort=due_date&state=open)
·
[Discord](https://discord.spreecommerce.org)

[![Gem Total Downloads](https://img.shields.io/gem/dt/spree)](https://rubygems.org/gems/spree)
[![codecov](https://codecov.io/gh/spree/spree/graph/badge.svg?token=DPFc7HbJvU)](https://codecov.io/gh/spree/spree)
[![License](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

**Build commerce the way you want it.** Spree is an open-source commerce platform with a complete REST API, TypeScript SDKs, a React admin dashboard, and a production-ready Next.js storefront. BSD 3-Clause licensed — keep full ownership of your code, data, and infrastructure.

Teams use Spree to build **multi-vendor marketplaces** and **B2B and wholesale** channels, as well as headless DTC, cross-border and omnichannel selling — all from one set of commerce primitives, and all alongside the ERP, PIM, and payment systems you already run.

## Use Cases

Spree ships commerce primitives, so the same core serves very different businesses.

### [Multi-vendor Marketplace](https://spreecommerce.org/docs/developer/how-to/build-a-marketplace)

Seller onboarding with configurable requirement checklists, orders split per seller at completion, a flexible [commission engine](https://spreecommerce.org/docs/developer/core-concepts/commissions), a payout ledger with Stripe Connect, and a dedicated Seller Panel. All in the open-source core.

<img alt="Spree Commerce - Multi-vendor Marketplace eCommerce" src="https://github.com/spree/spree/assets/12614496/c4ddd118-df4c-464e-b1fe-d43862e5cf25" width="600" >

### [B2B & Wholesale](https://spreecommerce.org/docs/developer/how-to/build-a-b2b-store)

[Price lists](https://spreecommerce.org/docs/developer/core-concepts/pricing) with volume tiers, [customer groups](https://spreecommerce.org/docs/user/customers/customer-groups), [companies](https://spreecommerce.org/docs/developer/core-concepts/companies) with locations, contacts and tax exemptions, [catalogs](https://spreecommerce.org/docs/developer/core-concepts/catalogs) for per-segment assortments, and storefronts gated to approved buyers.

<img src="https://github.com/spree/spree/assets/12614496/bac1e551-f629-47d6-a983-b385aa65b1bd" alt="Spree Commerce - Wholesale eCommerce Platform" width="600" >

### [Headless & Omnichannel](https://spreecommerce.org/docs/developer/core-concepts/channels)

Run web storefronts, mobile apps, points of sale, B2B panels and marketplaces off one backend. [Channels](https://spreecommerce.org/docs/developer/core-concepts/channels) give each surface its own catalog, pricing, payment methods and order attribution.

The [Next.js storefront](https://github.com/spree/storefront) is one such surface — production-ready, open source, built with Next.js 16, React 19 and TypeScript. Fork it, customize it, deploy it. [Try the live demo](https://demo.spreecommerce.org/)

<table>
  <tr>
    <td><a href="https://demo.spreecommerce.org/"><img src="https://spreecommerce.org/wp-content/uploads/2026/04/Spree-Commerce-Next.js-Storefront-Homepage.webp" alt="Spree Commerce - Next.js Storefront - Home" width="400" /></a></td>
    <td><a href="https://demo.spreecommerce.org/"><img src="https://spreecommerce.org/wp-content/uploads/2026/04/Spree-Commerce-Next.js-Storefront-Product-Detail-Page-PDP.webp" alt="Spree Commerce - Next.js Storefront - Product" width="400" /></a></td>
    <td><a href="https://demo.spreecommerce.org/"><img src="https://spreecommerce.org/wp-content/uploads/2026/04/Spree-Commerce-Next.js-Storefront-PageSpeed-Lighthouse.webp" alt="Spree Commerce - Next.js Storefront - Lighthouse" width="400" /></a></td>
  </tr>
</table>

### [Cross-border Commerce](https://spreecommerce.org/docs/developer/core-concepts/markets)

[Markets](https://spreecommerce.org/docs/developer/core-concepts/markets) bundle currency, language, payment methods and shipping per region, so each customer sees a localized storefront from a single platform. [Translations](https://spreecommerce.org/docs/developer/core-concepts/translations) for product content, EU Omnibus price history and customs duties are built in.

<img alt="Spree Commerce - Cross-border eCommerce" src="https://spreecommerce.org/wp-content/uploads/2024/07/multi-region-country-shopping-1024x575.webp" width="600" >

### [Multi-tenant SaaS](https://spreecommerce.org/docs/developer/multi-tenant/quickstart) <sup>Enterprise</sup>

Run a SaaS platform where each tenant gets its own isolated store — catalog, orders, customers, payment methods and branding — with staff able to manage several tenants. Requires the [Enterprise Edition](https://spreecommerce.org/pricing).

## Getting Started

Copy and paste the following command to your terminal to set up Spree locally in 5 minutes:

```bash
npx create-spree-app@latest my-store
```

This sets up the Spree backend, the React Admin Dashboard, and optionally the [Next.js storefront](https://github.com/spree/storefront) in a single project. The storefront is built with Next.js 16, React 19, Tailwind CSS 4, and TypeScript.

You need Node.js 24+ installed and Docker running. Learn more in the [installation docs](https://spreecommerce.org/docs/developer/getting-started/quickstart).

If you like what you see, consider giving Spree a GitHub star ⭐

Thank you for supporting Spree open-source ❤️

### Agentic Development

Building with an AI coding agent? Install the [Spree agent skills](https://github.com/spree/agent-skills) — they teach Claude Code, Cursor, Copilot, and 60+ other tools Spree's conventions, customization patterns, and upgrade flows:

```bash
npx skills add spree/agent-skills
```

Then connect the [docs MCP server](https://spreecommerce.org/docs/developer/agentic/mcp) and let your agent build with you. Learn more in the [Agentic Development docs](https://spreecommerce.org/docs/developer/agentic/overview).

### Spree CLI

[`@spree/cli`](packages/cli) manages your Spree project from the terminal — boot the stack, run generators and migrations, tail logs — and calls the **Admin API** directly with simple `get`/`post`/`patch`/`delete` commands. It's a fast way to inspect and script your store, and works hands-free for AI agents (zero-config credentials in local dev):

```bash
spree dev                                                            # boot the project (web + worker + db)
spree generate api_resource Brand name:string description:rich_text  # Creates full API endpoints, models and database schema for a Brand resource
spree api get /orders -q status_eq=complete --limit 10               # query the Admin API
spree api post /products -d '{"name":"Classic Tee","prices":[{"currency":"USD","amount":"29.99"}]}'  # create resources
```

`spree api endpoints` and `spree api schema` explore the full API offline. See the [CLI docs](https://spreecommerce.org/docs/developer/cli/quickstart).

## Features

Everything below ships in this repository under the BSD 3-Clause license.

* **[REST API & TypeScript SDKs](https://spreecommerce.org/docs/api-reference/store-api/introduction)** — a REST API for storefronts, admins and sellers, with publishable keys, scoped secret keys, rate limiting and an OpenAPI 3.0 spec. Three typed clients: [`@spree/sdk`](packages/sdk) (Store), [`@spree/admin-sdk`](packages/admin-sdk) (Admin) and [`@spree/seller-sdk`](packages/seller-sdk) (Seller).
* **[React Admin Dashboard](https://spreecommerce.org/docs/developer/dashboard/overview)** — a Vite + React SPA built on TanStack Router and Query, shadcn/ui and Tailwind. Extend it with [plugins](https://spreecommerce.org/docs/developer/dashboard/plugins/overview) — nav entries, routes, table columns and slot widgets — without forking it. Ships with a matching **Seller Panel** for marketplace vendors.
* **[Next.js Storefront](https://github.com/spree/storefront)** — open-source storefront built with Next.js 16, React 19, Tailwind CSS 4, and TypeScript. Full shopping experience, multi-region URL routing, Stripe payments (Apple Pay, Google Pay, Klarna, Affirm), customer accounts, and SEO built in. [Try the demo](https://demo.spreecommerce.org/)
* **[Spree CLI](https://spreecommerce.org/docs/developer/cli/quickstart)** — manage projects from the terminal (boot, generate, migrate, upgrade) and call the Admin API directly with `spree api get/post/...` — zero-config in local dev, built for scripts and AI agents.
* **[Marketplace & Payouts](https://spreecommerce.org/docs/developer/core-concepts/sellers)** — seller onboarding with a configurable requirements checklist, per-seller order splitting, a [commission engine](https://spreecommerce.org/docs/developer/core-concepts/commissions) with EU commission taxation, and a payout ledger with Stripe Connect payouts.
* **[B2B & Wholesale](https://spreecommerce.org/docs/developer/how-to/build-a-b2b-store)** — [price lists](https://spreecommerce.org/docs/developer/core-concepts/pricing) with volume tiers and negotiated rates, [customer groups](https://spreecommerce.org/docs/user/customers/customer-groups) for segmentation, [companies](https://spreecommerce.org/docs/developer/core-concepts/companies) with locations, contacts and validated tax exemptions, and [catalogs](https://spreecommerce.org/docs/developer/core-concepts/catalogs) for per-segment assortments.
* **[Payments](https://spreecommerce.org/docs/developer/core-concepts/payments)** — provider-agnostic payment sessions that finish reliably even when a tab closes. Ships with [Stripe](https://spreecommerce.org/docs/integrations/payments/stripe), [Adyen](https://spreecommerce.org/docs/integrations/payments/adyen) and [PayPal](https://spreecommerce.org/docs/integrations/payments/paypal). Add your own with the [Payment Provider SDK](https://spreecommerce.org/docs/developer/how-to/custom-payment-method).
* **[Promotions & Gift Cards](https://spreecommerce.org/docs/developer/core-concepts/promotions)** — a rules-based [promotions engine](https://spreecommerce.org/docs/developer/core-concepts/promotions) for percentage and fixed discounts, free shipping, BOGO offers and coupon codes, plus native [store credits and gift cards](https://spreecommerce.org/docs/developer/core-concepts/store-credits-gift-cards).
* **[Fulfillment](https://spreecommerce.org/docs/developer/core-concepts/fulfillments)** — shipping, digital delivery and in-store pickup, [delivery profiles and zones](https://spreecommerce.org/docs/developer/core-concepts/delivery-setup), multi-location [inventory](https://spreecommerce.org/docs/developer/core-concepts/inventory), and [returns, exchanges and claims](https://spreecommerce.org/docs/developer/core-concepts/returns-exchanges-claims).
* **[Taxes & Compliance](https://spreecommerce.org/docs/developer/core-concepts/taxes)** — inclusive or added-on tax, automatic calculation via Avalara and Stripe Tax, cross-border [customs fees & duties](https://spreecommerce.org/docs/developer/core-concepts/fees), and [data privacy](https://spreecommerce.org/docs/developer/core-concepts/data-privacy) tooling for GDPR subject requests and EU Omnibus price history.
* **Products & Catalog** — [custom fields](https://spreecommerce.org/docs/developer/core-concepts/metafields) on any record, [CSV imports and exports](https://spreecommerce.org/docs/developer/core-concepts/imports-exports), digital products, product tags, a shared [media library](https://spreecommerce.org/docs/developer/core-concepts/media) and bulk operations.
* **[Provider Contracts](https://spreecommerce.org/docs/developer/providers/overview)** — plug your existing stack in rather than replacing it: [ERP](https://spreecommerce.org/docs/developer/providers/erp), [PIM](https://spreecommerce.org/docs/developer/providers/pim), [WMS and carriers](https://spreecommerce.org/docs/developer/providers/fulfillment), [DAM](https://spreecommerce.org/docs/developer/providers/dam), [SSO](https://spreecommerce.org/docs/developer/providers/sso) and [payouts](https://spreecommerce.org/docs/developer/providers/payouts).
* **[Security & Identity](https://spreecommerce.org/docs/developer/providers/sso)** — [OpenID Connect](https://spreecommerce.org/docs/developer/providers/sso) single sign-on for staff and customers, [custom auth adapters](https://spreecommerce.org/docs/developer/how-to/custom-api-authentication) for any JWT issuer, [role-based permissions](https://spreecommerce.org/docs/developer/customization/permissions) scoped per store, and a [PCI-compliant](https://spreecommerce.org/docs/developer/security/pci_compliance) payment architecture where card data never touches your server.
* **[MeiliSearch Integration](https://spreecommerce.org/docs/integrations/search/meilisearch)** — typo-tolerant product search and faceted filtering, or [bring your own search provider](https://spreecommerce.org/docs/developer/how-to/custom-search-provider).
* **Integrations & Extensibility** — [Event Bus](https://spreecommerce.org/docs/developer/core-concepts/events), [Webhooks](https://spreecommerce.org/docs/developer/core-concepts/webhooks), [OpenTelemetry](spree/opentelemetry) instrumentation, and native integrations ([GA4](https://spreecommerce.org/docs/integrations/analytics/google-analytics), [GTM](https://spreecommerce.org/docs/integrations/analytics/google-tag-manager), [Klaviyo](https://spreecommerce.org/docs/integrations/marketing/klaviyo)).
* **[Agentic Development](https://spreecommerce.org/docs/developer/agentic/overview)** — [agent skills](https://github.com/spree/agent-skills) (`npx skills add spree/agent-skills`) teaching AI coding agents Spree's conventions, a [docs MCP server](https://spreecommerce.org/docs/developer/agentic/mcp), [LLM-ready documentation](https://spreecommerce.org/docs/developer/agentic/llm-docs) (llms.txt, per-page Markdown, offline npm package), and a generated AGENTS.md/CLAUDE.md in every scaffolded project.

## Deployment

The Spree backend can be deployed anywhere — cloud, on-prem or VPS. We provide official Docker images and Dockerfiles, so you can use AWS, Azure, GCP, Render, Railway, Fly.io, Heroku, or any other Docker-compatible host. The Next.js storefront can be deployed to Vercel, Netlify, or any Node.js host. See the [Deployment Documentation](https://spreecommerce.org/docs/developer/deployment) for more details.

## Community & Contributing

Spree is an open-source project, and we love contributions in any form — pull requests, issues, feature ideas.

* Follow our [Contributing Guide](https://spreecommerce.org/docs/developer/contributing/quickstart)
* [Join our Discord](https://discord.spreecommerce.org) to meet other community members
* Browse the [Roadmap](https://github.com/spree/spree/milestones?direction=asc&sort=due_date&state=open) and open [Issues](https://github.com/spree/spree/issues)

## Spree Enterprise Edition

Spree is built and maintained by a funded team behind the open-source project. Beyond the open-source core, we offer a paid [Enterprise Edition](https://spreecommerce.org/enterprise/) for organizations that need additional modules and SLA-backed support.

Enterprise adds **B2B approval workflows** with role-based approval chains and ERP connectors, **marketplace automations** such as Shopify and WooCommerce seller sync and advanced reporting, **[multi-tenant SaaS](https://spreecommerce.org/docs/developer/multi-tenant/quickstart)** — running many isolated tenant stores from one deployment, with a super-admin, tenant provisioning and white-label billing — **audit logging and encryption at-rest**, and **SLA support** with a dedicated success manager, LTS releases and 24/7 monitoring.

Everything else — the APIs, the SDKs, the dashboard, marketplace, B2B and cross-border — is in this repository. Enterprise Edition builds on the same BSD 3-Clause core, so your team keeps full ownership of the code, the data, and the infrastructure. Zero platform fees. Zero transaction fees.

[Contact our Sales team](https://spreecommerce.org/contact/) for an Enterprise Edition demo, or [join Discord](https://discord.spreecommerce.org) to use the open-source edition with the community.

## License

Spree Commerce core code in the **[spree/spree](https://github.com/spree/spree)** repository is released under the free, open-source [BSD-3-Clause](https://opensource.org/license/bsd-3-clause) license ([LICENSE](https://github.com/spree/spree/blob/main/LICENSE)).

If you like what you see, consider giving Spree a GitHub star ⭐

Thank you for supporting Spree open-source ❤️
