<p>
  <a href="https://spreecommerce.org">
    <img src="https://spreecommerce.org/wp-content/themes/spree/images/logo.svg" alt="Spree Commerce open source headless eCommerce platform for B2B, Multi-vendor Marketplace, cross-border eCommerce, multi-tenant eCommerce" width="250" />
  </a>
</p>

[Website](https://spreecommerce.org)
·
[Next.js Storefront](https://github.com/spree/storefront)
·
[Demo](https://demo.spreecommerce.org/)
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

Copy and paste the following command to your terminal to set up Spree in 5 minutes:

```bash
npx create-spree-app@latest my-store
```

This sets up the Spree Commerce backend, the Admin Dashboard, and the [Next.js storefront](https://github.com/spree/storefront) in a single project. The storefront is built with Next.js 16, React 19, Tailwind CSS 4, and TypeScript.

You need to have Node.js (22+) installed and Docker running. Learn more in the [installation docs](https://spreecommerce.org/docs/developer/getting-started/quickstart).

Or deploy directly to the cloud:

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/spree/spree-starter)

> **Note**
> This uses Render's free plan for quick evaluation. Free instances spin down after inactivity and may take 30-60s to wake up. For production, see [recommended sizing](https://spreecommerce.org/docs/developer/deployment/render#production-sizing).

If you prefer to install Spree manually, you may follow the [Quickstart Guide](https://spreecommerce.org/docs/developer/getting-started/quickstart).

If you like what you see, consider giving Spree a GitHub star ⭐

Thank you for supporting Spree open-source ❤️

## Features

Everything below ships in this repository under the BSD 3-Clause license.

* **[REST API & TypeScript SDK](https://spreecommerce.org/docs/api-reference/store-api/introduction)** — production-grade REST API with flat JSON, publishable keys, rate limiting, and OpenAPI 3.0 spec. The [TypeScript SDK](https://spreecommerce.org/docs/developer/sdk/quickstart) adds autocomplete and type safety.
* **[Next.js Storefront](https://github.com/spree/storefront)** — open-source storefront built with Next.js 16, React 19, Tailwind CSS 4, and TypeScript. Full shopping experience, multi-region URL routing, Stripe payments (Apple Pay, Google Pay, Klarna, Affirm), customer accounts, and SEO built in. [Try the demo](https://demo.spreecommerce.org/)
* **[Cross-Border Commerce](https://spreecommerce.org/docs/user/settings/markets)** — Markets bundle currency, language, payment methods, and shipping rules per country. Translations Center for bulk product localization. EU Omnibus Directive compliance with automatic 30-day price history.
* **[B2B & Wholesale](https://spreecommerce.org/docs/developer/core-concepts/products#price-lists)** — [Price Lists](https://spreecommerce.org/docs/developer/core-concepts/products#price-lists) for regional, B2B, and wholesale pricing. [Customer Groups](https://spreecommerce.org/docs/user/customers/customer-groups) for segmentation. Companies, company locations, and company contacts for buyer organizations. Gated storefronts via publishable keys.
* **[Multi-Store](https://spreecommerce.org/docs/use-case/multi-store/capabilities)** — run multiple storefronts off a single Spree backend, each with its own domain, branding, products, and currency.
* **[Payment Sessions](https://spreecommerce.org/docs/developer/core-concepts/payments)** — provider-agnostic payment processing. Ship with [Stripe](https://spreecommerce.org/docs/integrations/payments/stripe), [Adyen](https://spreecommerce.org/docs/integrations/payments/adyen) and PayPal without changing storefront checkout code.
* **[Promotions & Gift Cards](https://spreecommerce.org/docs/user/promotions/create-a-promotion)** — advanced promotions engine and [Gift Cards](https://spreecommerce.org/docs/developer/core-concepts/store-credits-gift-cards).
* **Products & Catalog** — [Metafields](https://spreecommerce.org/docs/developer/core-concepts/metafields), [CSV importer/exporter](https://spreecommerce.org/docs/user/manage-products/import-products), digital products, product tags, [bulk operations](https://spreecommerce.org/docs/user/manage-products/bulk-product-operations).
* **[MeiliSearch Integration](https://spreecommerce.org/docs/integrations/search/meilisearch)** — typo-tolerant product search and faceted filtering.
* **Admin Dashboard** — built with [Tailwind CSS](https://spreecommerce.org/docs/developer/admin/custom-css), [Tables DSL](https://spreecommerce.org/docs/developer/admin/tables), and [role-based permissions](https://spreecommerce.org/docs/developer/customization/permissions).
* **Integrations & Extensibility** — [Event Bus](https://spreecommerce.org/docs/developer/core-concepts/events), [Webhooks 2.0](https://spreecommerce.org/docs/developer/core-concepts/webhooks), native integrations ([GA4](https://spreecommerce.org/docs/integrations/analytics/google-analytics), [GTM](https://spreecommerce.org/docs/integrations/analytics/google-tag-manager), [Klaviyo](https://spreecommerce.org/docs/integrations/marketing/klaviyo)).
* **AI-Ready Development** — AGENTS.md and bundled offline docs ship with every scaffolded project.

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
| REST API, TypeScript SDK, Next.js storefront | ✅ | ✅ |
| Multi-store, Markets, cross-border, multi-currency | ✅ | ✅ |
| Price Lists, Customer Groups, gated storefronts, wholesale | ✅ | ✅ |
| Promotions, gift cards, digital products, MeiliSearch | ✅ | ✅ |
| **B2B Buyer organizations (companies, locations, contacts)** | 🔜 6.0 | ✅ |
| **B2B approval workflows & ERP integrations** — role-based approval chains, procurement and ERP connectors | — | ✅ |
| **Multi-vendor Marketplace** — vendors, commissions, split payments, vendor payouts (native multi-vendor [coming in Spree 6.0](https://github.com/spree/spree/milestones?direction=asc&sort=due_date&state=open)) | 🔜 6.0 | ✅ |
| **Marketplace automations** — Shopify/WooCommerce vendor sync, Stripe Connect onboarding, automated commission rules | — | ✅ |
| **Multi-tenant SaaS** — super-admin layer, tenant provisioning, white-label billing, central operations across hundreds of tenant stores | — | ✅ |
| **Enterprise security** — SSO (SAML/OIDC), encryption at-rest, audit logging, PCI-compliant architecture | — | ✅ |
| **SLA support** — dedicated success manager, guaranteed response times, LTS releases, 24/7 monitoring | — | ✅ |

[Contact our Sales team](https://spreecommerce.org/contact/) for an Enterprise Edition demo, or [join Discord](https://discord.spreecommerce.org) to use the open-source edition with the community.

## License

Spree Commerce core code in the **[spree/spree](https://github.com/spree/spree)** repository is released under the free, open-source [BSD-3-Clause](https://opensource.org/license/bsd-3-clause) license ([LICENSE](https://github.com/spree/spree/blob/main/LICENSE)).

If you like what you see, consider giving Spree a GitHub star ⭐

Thank you for supporting Spree open-source ❤️
