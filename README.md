<p>
  <a href="https://spreecommerce.org">
    <img src="https://spreecommerce.org/wp-content/themes/spree/images/logo.svg" alt="Spree Commerce open source headless eCommerce platform for B2B, Multi-vendor Marketplace, cross-border eCommerce, multi-tenant eCommerce" width="250" />
  </a>
</p>

[Website](https://spreecommerce.org)
·
[Free Sandbox](https://console.spree.sh)
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


Open-source headless eCommerce platform with a complete REST API, TypeScript SDK, and a production-ready Next.js storefront. BSD 3-Clause licensed — keep full ownership of your code, data, and infrastructure.

Everything you need to launch cross-border storefronts, B2B wholesale, or a custom commerce backend.

## Getting Started

The fastest way to try Spree is to [create a free sandbox](https://console.spree.sh) — a hosted Spree store with the Admin Dashboard and storefront, nothing to install.

To run Spree locally instead, copy and paste the following command to your terminal to set it up in 5 minutes:

```bash
npx create-spree-app@latest my-store
```

This sets up the Spree Commerce backend, the Admin Dashboard, and the [Next.js storefront](https://github.com/spree/storefront) in a single project. The storefront is built with Next.js 16, React 19, Tailwind CSS 4, and TypeScript.

You need to have Node.js (22+) installed and Docker running. Learn more in the [installation docs](https://spreecommerce.org/docs/developer/getting-started/quickstart).

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
spree generate api_resource Brand name:string description:rich_text  #  Creates full API endpoints, models and database schema for a Brand resource
spree api get /orders -q status_eq=complete --limit 10               # query the Admin API
spree api post /products -d '{"name":"Classic Tee","prices":[{"currency":"USD","amount":"29.99"}]}'  # create resources
```

`spree api endpoints` and `spree api schema` explore the full API offline. See the [CLI docs](https://spreecommerce.org/docs/developer/cli/quickstart).

## Features

Everything below ships in this repository under the BSD 3-Clause license.

* **[REST API & TypeScript SDK](https://spreecommerce.org/docs/api-reference/store-api/introduction)** — production-grade REST API, publishable keys, rate limiting, and OpenAPI 3.0 spec. The [TypeScript SDK](https://spreecommerce.org/docs/developer/sdk/quickstart) adds autocomplete and type safety.
* **[Spree CLI](https://spreecommerce.org/docs/developer/cli/quickstart)** — manage projects from the terminal (boot, generate, migrate, upgrade) and call the Admin API directly with `spree api get/post/...` — zero-config in local dev, built for scripts and AI agents.
* **[Next.js Storefront](https://github.com/spree/storefront)** — open-source storefront built with Next.js 16, React 19, Tailwind CSS 4, and TypeScript. Full shopping experience, multi-region URL routing, Stripe payments (Apple Pay, Google Pay, Klarna, Affirm), customer accounts, and SEO built in. [Try the demo](https://demo.spreecommerce.org/)
* **[Cross-Border Commerce](https://spreecommerce.org/docs/user/settings/markets)** — Markets bundle currency, language, payment methods, and shipping rules per country. Translations Center for bulk product localization. EU Omnibus Directive compliance with automatic 30-day price history.
* **[B2B & Wholesale](https://spreecommerce.org/docs/developer/core-concepts/products#price-lists)** — [Price Lists](https://spreecommerce.org/docs/developer/core-concepts/products#price-lists) for regional, B2B, and wholesale pricing. [Customer Groups](https://spreecommerce.org/docs/user/customers/customer-groups) for segmentation. Companies, company locations, and company contacts for buyer organizations. Catalogs for curated, per-segment product assortments. Gated storefronts via publishable keys.
* **[Sales Channels](https://spreecommerce.org/docs/developer/core-concepts/channels)** — run multiple storefronts, Points of Sale, B2B panels, mobile apps off a single Spree backend, each with its products, pricing, payment methods, and shipping rules
* **[Payment Sessions](https://spreecommerce.org/docs/developer/core-concepts/payments)** — provider-agnostic payment processing. Shipped with [Stripe](https://spreecommerce.org/docs/integrations/payments/stripe), [Adyen](https://spreecommerce.org/docs/integrations/payments/adyen) and [PayPal](https://spreecommerce.org/docs/integrations/payments/paypal) plugins ready to use with Next.js storefront. Add your own with the [Payment Provider SDK](https://spreecommerce.org/docs/developer/how-to/custom-payment-method).
* **[Promotions & Gift Cards](https://spreecommerce.org/docs/user/promotions/create-a-promotion)** — advanced rules-based promotions engine and native [Gift Cards](https://spreecommerce.org/docs/developer/core-concepts/store-credits-gift-cards) support.
* **Products & Catalog** — [Metafields](https://spreecommerce.org/docs/developer/core-concepts/metafields), [CSV importer/exporter](https://spreecommerce.org/docs/user/manage-products/import-products), digital products, product tags, [bulk operations](https://spreecommerce.org/docs/user/manage-products/bulk-product-operations).
* **[MeiliSearch Integration](https://spreecommerce.org/docs/integrations/search/meilisearch)** — typo-tolerant product search and faceted filtering.
* **Admin Dashboard** — built with [Tailwind CSS](https://spreecommerce.org/docs/developer/admin/custom-css) with [role-based permissions](https://spreecommerce.org/docs/developer/customization/permissions).
* **Integrations & Extensibility** — [Event Bus](https://spreecommerce.org/docs/developer/core-concepts/events), [Webhooks 2.0](https://spreecommerce.org/docs/developer/core-concepts/webhooks), native integrations ([GA4](https://spreecommerce.org/docs/integrations/analytics/google-analytics), [GTM](https://spreecommerce.org/docs/integrations/analytics/google-tag-manager), [Klaviyo](https://spreecommerce.org/docs/integrations/marketing/klaviyo)).
* **[Agentic Development](https://spreecommerce.org/docs/developer/agentic/overview)** — [25 agent skills](https://github.com/spree/agent-skills) (`npx skills add spree/agent-skills`) teaching AI coding agents Spree's conventions, a [docs MCP server](https://spreecommerce.org/docs/developer/agentic/mcp), [LLM-ready documentation](https://spreecommerce.org/docs/developer/agentic/llm-docs) (llms.txt, per-page Markdown, offline npm package), and a generated AGENTS.md/CLAUDE.md in every scaffolded project.

## Deployment

Spree backend can be deployed everywhere, on cloud, on prem or VPS. We provide official Docker images and Dockerfiles so you can use AWS, Azure, GCP, Render, Railway, Fly.io, Heroku, or any other Docker-compatible host. The Next.js storefront can be deployed to Vercel, Netlify, or any Node.js host. [See the Deployment Documentation](https://spreecommerce.org/docs/developer/deployment) for more details.

If you want to quickly evaluate Spree, you can use the [free sandbox](https://console.spree.sh) — a hosted Spree store with the Admin Dashboard and storefront, nothing to install.

## Screenshots

### [Next.js eCommerce Storefront](https://github.com/spree/storefront)

A production-ready, open-source storefront built with Next.js 16, React 19, and TypeScript. Fork it, customize it, deploy it. [Try the live demo](https://demo.spreecommerce.org/)

<table>
  <tr>
    <td><a href="https://demo.spreecommerce.org/"><img src="https://spreecommerce.org/wp-content/uploads/2026/04/Spree-Commerce-Next.js-Storefront-Homepage.webp" alt="Spree Commerce - Next.js Storefront - Home" width="400" /></a></td>
    <td><a href="https://demo.spreecommerce.org/"><img src="https://spreecommerce.org/wp-content/uploads/2026/04/Spree-Commerce-Next.js-Storefront-Product-Detail-Page-PDP.webp" alt="Spree Commerce - Next.js Storefront - Product" width="400" /></a></td>
    <td><a href="https://demo.spreecommerce.org/"><img src="https://spreecommerce.org/wp-content/uploads/2026/04/Spree-Commerce-Next.js-Storefront-PageSpeed-Lighthouse.webp" alt="Spree Commerce - Next.js Storefront - Lighthouse" width="400" /></a></td>
  </tr>
</table>

### [Cross-border eCommerce](https://spreecommerce.org/multi-region-ecommerce/)

Sell in multiple markets with local currencies, languages, payment methods, and shipping rules. Markets bundle per-country configuration so each customer sees a localized storefront from a single platform.

<img alt="Spree Commerce - Cross-border eCommerce" src="https://spreecommerce.org/wp-content/uploads/2024/07/multi-region-country-shopping-1024x575.webp" width="600" >

### [Wholesale & B2B Pricing](https://spreecommerce.org/use-cases/wholesale-ecommerce/)

Price Lists, Customer Groups, and gated storefronts. Sell to multiple customer segments with the right assortment and pricing per segment.

<img src="https://github.com/spree/spree/assets/12614496/bac1e551-f629-47d6-a983-b385aa65b1bd" alt="Spree Commerce - Wholesale eCommerce Platform" width="600" >

### [Multi-vendor Marketplace](https://spreecommerce.org/marketplace-ecommerce/)

Launch a multi-vendor marketplace with vendor accounts, product catalog curation, split payments, vendor payouts, and commission management. The Enterprise Edition adds automated vendor onboarding (Shopify, WooCommerce sync) and Stripe Connect / Adyen for Platforms integrations.

<img alt="Spree Commerce - Multi-vendor Marketplace eCommerce" src="https://github.com/spree/spree/assets/12614496/c4ddd118-df4c-464e-b1fe-d43862e5cf25" width="600" >

## Community & Contributing

Spree is an open-source project, and we love contributions in any form — pull requests, issues, feature ideas.

* Follow our [Contributing Guide](https://spreecommerce.org/docs/developer/contributing/quickstart)
* [Join our Discord](https://discord.spreecommerce.org) to meet other community members
* Browse the [Roadmap](https://github.com/spree/spree/milestones?direction=asc&sort=due_date&state=open) and open [Issues](https://github.com/spree/spree/issues)

## Spree Enterprise Edition

Spree is built and maintained by a funded team behind the open-source project. Beyond the open-source Core, we offer a paid [Enterprise Edition](https://spreecommerce.org/enterprise/) for organizations that need additional modules and SLA-backed support.

Enterprise Edition is built on top of the same open-source REST API and BSD 3-Clause Core, so your team keeps full ownership of the code, the data, and the infrastructure. Zero platform fees. Zero transaction fees.

### What's in Core vs. Enterprise

| Capability | Open-source (this repo) | Enterprise Edition |
|---|---|---|
| **REST API**, **TypeScript SDK**, Next.js storefront | ✅ | ✅ |
| **Sales Channels**, **Markets**, cross-border, multi-currency | ✅ | ✅ |
| **Promotions**, **Gift Cards**, **Digital Products** | ✅ | ✅ |
| Payment integrations: **Stripe**, **Adyen**, **PayPal** | ✅ | ✅ |
| Automatic tax calculation with **Avatax** & **Stripe Tax** | ✅ | ✅ |
| **B2B & Wholesale** — Price Lists, Customer Groups, gated storefronts | ✅ | ✅ |
| **B2B Buyer organizations** (companies, locations, contacts) | Coming soon in Spree 6.0 | ✅ |
| **B2B Catalogs** — curated per-segment product assortments | Coming soon in Spree 6.0 | ✅ |
| **B2B approval workflows & ERP integrations** — role-based approval chains, procurement and ERP connectors | — | ✅ |
| **Multi-vendor Marketplace** — vendor onboarding, vendor panel, commissions, split payments, vendor payouts | Coming soon in Spree 6.0 | ✅ |
| **Marketplace automations** — Shopify/WooCommerce vendor sync, Stripe Connect onboarding, automated commission rules, advanced reporting | — | ✅ |
| **Multi-tenant SaaS** — super-admin layer, tenant provisioning, white-label billing, central operations across hundreds of tenant stores | — | ✅ |
| **Enterprise security** — SSO (SAML/OIDC), encryption at-rest, audit logging, PCI-compliant architecture | — | ✅ |
| **SLA support** — dedicated success manager, guaranteed response times, LTS releases, 24/7 monitoring | — | ✅ |

[Contact our Sales team](https://spreecommerce.org/contact/) for an Enterprise Edition demo, or [join Discord](https://discord.spreecommerce.org) to use the open-source edition with the community.

## License

Spree Commerce core code in the **[spree/spree](https://github.com/spree/spree)** repository is released under the free, open-source [BSD-3-Clause](https://opensource.org/license/bsd-3-clause) license ([LICENSE](https://github.com/spree/spree/blob/main/LICENSE)).

If you like what you see, consider giving Spree a GitHub star ⭐

Thank you for supporting Spree open-source ❤️
