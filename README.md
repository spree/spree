<p>
  <a href="https://spreecommerce.org">
    <img src="https://spreecommerce.org/wp-content/themes/spree/images/logo.svg" alt="Spree Commerce open source headless eCommerce platform for B2B, Multi-vendor Marketplace, cross-border eCommerce, multi-tenant eCommerce" width="250" />
  </a>
</p>

# Spree Commerce

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
·
[Enterprise](https://spreecommerce.org/enterprise/)

[![Gem Total Downloads](https://img.shields.io/gem/dt/spree)](https://rubygems.org/gems/spree)
[![codecov](https://codecov.io/gh/spree/spree/graph/badge.svg?token=DPFc7HbJvU)](https://codecov.io/gh/spree/spree)
[![License](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)


Open-source headless eCommerce platform with a complete REST API, TypeScript SDK, and a production-ready Next.js storefront.

Everything you need to launch cross-border storefronts, B2B wholesale, multi-vendor marketplaces, or multi-tenant SaaS.

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

* **[REST API & TypeScript SDK](https://spreecommerce.org/docs/api-reference/store-api/introduction)** -- production-grade REST API with flat JSON, publishable keys, rate limiting, and OpenAPI 3.0 spec. The [TypeScript SDK](https://spreecommerce.org/docs/developer/sdk/quickstart) adds autocomplete and type safety.
* **[Next.js Storefront](https://github.com/spree/storefront)** -- open-source storefront built with Next.js 16, React 19, Tailwind CSS 4, and TypeScript. Full shopping experience, multi-region URL routing, Stripe payments (Apple Pay, Google Pay, Klarna, Affirm), customer accounts, and SEO built in. [Try the demo](https://demo.spreecommerce.org/)
* **[Cross-Border Commerce](https://spreecommerce.org/docs/user/settings/markets)** -- Markets bundle currency, language, payment methods, and shipping rules per country. Translations Center for bulk product localization. EU Omnibus Directive compliance with automatic 30-day price history.
* **[Payment Sessions](https://spreecommerce.org/docs/developer/core-concepts/payments)** -- provider-agnostic payment processing. Ship with [Stripe](https://spreecommerce.org/docs/integrations/payments/stripe), add [Adyen](https://spreecommerce.org/docs/integrations/payments/adyen) or PayPal without changing storefront checkout code.
* **[MeiliSearch Integration](https://spreecommerce.org/docs/integrations/search/meilisearch)** -- typo-tolerant product search and faceted filtering
* **AI-Ready Development** -- AGENTS.md and bundled offline docs ship with every scaffolded project. OpenAPI 3.0 specs enable typed client generation for any language.
* **Admin Dashboard** -- rebuilt admin with [Tailwind CSS](https://spreecommerce.org/docs/developer/admin/custom-css), [Tables DSL](https://spreecommerce.org/docs/developer/admin/tables), and [role-based permissions](https://spreecommerce.org/docs/developer/customization/permissions)
* **Pricing & Promotions** -- [Price Lists](https://spreecommerce.org/docs/developer/core-concepts/products#price-lists) for regional/B2B/wholesale pricing, [Customer Groups](https://spreecommerce.org/docs/user/customers/customer-groups), [Gift Cards](https://spreecommerce.org/docs/developer/core-concepts/store-credits-gift-cards), and an advanced [Promotions Engine](https://spreecommerce.org/docs/user/promotions/create-a-promotion)
* **Products & Catalog** -- [Metafields](https://spreecommerce.org/docs/developer/core-concepts/metafields), [CSV importer/exporter](https://spreecommerce.org/docs/user/manage-products/import-products), digital products, product tags, [bulk operations](https://spreecommerce.org/docs/user/manage-products/bulk-product-operations)
* **Integrations & Extensibility** -- [Event Bus](https://spreecommerce.org/docs/developer/core-concepts/events), [Webhooks 2.0](https://spreecommerce.org/docs/developer/core-concepts/webhooks), native integrations ([GA4](https://spreecommerce.org/docs/integrations/analytics/google-analytics), [GTM](https://spreecommerce.org/docs/integrations/analytics/google-tag-manager), [Klaviyo](https://spreecommerce.org/docs/integrations/marketing/klaviyo), [MeiliSearch](https://spreecommerce.org/docs/integrations/search/meilisearch))

Read the full announcement: **[Announcing Spree Commerce 5.4: A Complete Open Source eCommerce Stack](https://spreecommerce.org/announcing-spree-commerce-5-4/)**

## Documentation

Spree Commerce supports complex commerce scenarios natively and lets you combine them as your business evolves: [B2B eCommerce](https://spreecommerce.org/docs/use-case/b2b/b2b-capabilities), [multi-store](https://spreecommerce.org/docs/use-case/multi-store/capabilities), [cross-border](https://spreecommerce.org/multi-region-ecommerce/), [multi-vendor marketplace](https://spreecommerce.org/docs/use-case/marketplace/capabilities), [digital products](https://spreecommerce.org/docs/use-case/digital-products/capabilities), [multi-tenant commerce](https://spreecommerce.org/docs/use-case/multi-tenant/multi-tenant-capabilities).

## Enterprise Support

Your success is backed by the team that builds Spree. [Contact us](https://spreecommerce.org/get-started/) to get access to:

* **Dedicated Success Manager** -- your single point of contact who understands your business and coordinates resources
* **SLA-Backed Response Times** -- guaranteed response windows for issue resolution depending on severity
* **Group Chat & Email Support** -- direct access to our team through Slack, Teams, or email
* **Long-Term Support (LTS)** -- extended maintenance and security patches with predictable upgrade cycles
* **Priority Fixes & Change Requests** -- priority access to new features and version upgrades
* **24/7 Monitoring & Response** -- round-the-clock infrastructure monitoring with proactive alerting
* **Professional Services On-Demand** -- development consulting, custom integrations, and implementation services

## Enterprise Edition

Spree Commerce [Enterprise Edition](https://spreecommerce.org/enterprise/) adds enterprise-grade security and purpose-built modules for complex commerce scenarios -- B2B wholesale, multi-vendor marketplace, and multi-tenant eCommerce. Built on the same open-source REST API and BSD 3-Clause core, so your team keeps full ownership of the code, the data, and the infrastructure. Zero platform fees. Zero transaction fees. Use each module independently or combine them as your business evolves.

**Enterprise-grade security by default:**

* Encryption at-rest (AES-256) and in-transit (TLS 1.3)
* Single Sign-On (SSO) -- Okta, Azure AD, Google Workspace, or any SAML/OIDC provider
* PCI DSS-compliant architecture with tokenized payments
* Role-Based Access Control with granular permissions
* Audit logging for compliance reviews
* Continuous security patches delivered through the LTS program

**Enterprise Edition modules:**

* **Multi-vendor Marketplace** -- automated vendor onboarding (Shopify, WooCommerce, CSV), product and order sync, split payments, and vendor payouts via Stripe Connect
* **B2B eCommerce** -- customer-specific price lists, buyer organizations with roles and approval workflows, gated storefronts, and ERP/procurement integrations
* **Multi-tenant eCommerce** -- host hundreds of independent stores as a white-label SaaS, franchise network, or multi-brand platform with central control over billing, fulfillment, and operations

[Contact our Sales team](https://spreecommerce.org/get-started/) to get access to the Enterprise Edition.

## What you can build with Spree

### [Next.js eCommerce Storefront](https://github.com/spree/storefront)

A production-ready, open-source storefront built with Next.js 16, React 19, and TypeScript. Fork it, customize it, deploy it. [Try the live demo](https://demo.spreecommerce.org/)

<table>
  <tr>
    <td><a href="https://demo.spreecommerce.org/"><img src="https://spreecommerce.org/wp-content/uploads/2026/04/Spree-Commerce-Next.js-Storefront-Homepage.webp" alt="Spree Commerce - Next.js Storefront - Home" width="400" /></a></td>
    <td><a href="https://demo.spreecommerce.org/"><img src="https://spreecommerce.org/wp-content/uploads/2026/04/Spree-Commerce-Next.js-Storefront-Product-Detail-Page-PDP.webp" alt="Spree Commerce - Next.js Storefront - Product" width="400" /></a></td>
    <td><a href="https://demo.spreecommerce.org/"><img src="https://spreecommerce.org/wp-content/uploads/2026/04/Spree-Commerce-Next.js-Storefront-PageSpeed-Lighthouse.webp" alt="Spree Commerce - Next.js Storefront - Lighthouse" width="400" /></a></td>
  </tr>
</table>

### [Multi-vendor marketplace](https://spreecommerce.org/marketplace-ecommerce/)

Launch a multi-vendor marketplace with automated vendor onboarding (two-way sync with Shopify, WooCommerce, other platforms), product catalog curation, Stripe Connect or Adyen for Platforms marketplace payment splitting and vendor payouts, granular commission management, marketplace promos, cross-border sales and many other features. 

* [Marketplace eCommerce Capabilities](https://spreecommerce.org/docs/use-case/marketplace/capabilities)
* [Marketplace eCommerce Admin Panel](https://spreecommerce.org/docs/use-case/marketplace/admin-dashboard)
* [Marketplace eCommerce Vendor Panel](https://spreecommerce.org/docs/use-case/marketplace/vendor-dashboard)
* [Marketplace eCommerce Customer Experience](https://spreecommerce.org/docs/use-case/marketplace/customer-ux)

<img alt="Spree Commerce - Multi-vendor Marketplace eCommerce" src="https://github.com/spree/spree/assets/12614496/c4ddd118-df4c-464e-b1fe-d43862e5cf25" width="600" >

### [B2B eCommerce Platform](https://spreecommerce.org/use-cases/b2b-ecommerce-platform/)

Customer segmentation for personalized shopping experiences, customer-specific volume pricing, buyer organizations with approval workflows, and gated storefronts. Integrate with any ERP or procurement system through the REST API and TypeScript SDK. Combine this capability with a Multi-vendor Marketplace, Cross-border eCommerce or both.

* [B2B eCommerce Capabilities](https://spreecommerce.org/docs/use-case/b2b/b2b-capabilities)
* [B2B eCommerce Admin Capabilities](https://spreecommerce.org/docs/use-case/b2b/b2b-admin-capabilities)
* [B2B eCommerce Buyer Experience](https://spreecommerce.org/docs/use-case/b2b/b2b-buyer-capabilities)

<img alt="Spree Commerce - B2B eCommerce Platform" src="https://github.com/spree/spree/assets/12614496/e0a184f6-31ad-4f7f-b30b-6f8a501b6f63" width="600" >

### [Cross-border eCommerce](https://spreecommerce.org/multi-region-ecommerce/)

Sell in multiple markets with local currencies, languages, payment methods, and shipping rules. Markets bundle per-country configuration so each customer sees a localized storefront from a single platform. Combine this capability with a Multi-vendor Marketplace, a B2B eCommerce Platform or both. 

<img alt="Spree Commerce - Cross-border eCommerce" src="https://spreecommerce.org/wp-content/uploads/2024/07/multi-region-country-shopping-1024x575.webp" width="600" >

### [Wholesale eCommerce](https://spreecommerce.org/use-cases/wholesale-ecommerce/)

Price Lists, gated storefronts, and bulk ordering. Sell to multiple customer segments through separate storefronts with the right assortment and pricing. Combine this capability with a Multi-vendor Marketplace, Cross-border eCommerce or both.

<img src="https://github.com/spree/spree/assets/12614496/bac1e551-f629-47d6-a983-b385aa65b1bd"  alt="Spree Commerce - Wholesale eCommerce Platform" width="600" >

### [Multi-tenant eCommerce Platform](https://spreecommerce.org/multi-tenant-white-label-ecommerce/)

Host hundreds of independent stores as a white-label SaaS, franchise network, or multi-brand platform. Each tenant gets their own dashboard, storefront, and branding. B2B2B or B2B2C.

* [Multi-Tenant Capabilities](https://spreecommerce.org/docs/use-case/multi-tenant/multi-tenant-capabilities)
* [Multi-Tenant Super Admin Capabilities](https://spreecommerce.org/docs/use-case/multi-tenant/super-admin-capabilities)
* [Tenant Capabilities](https://spreecommerce.org/docs/use-case/multi-tenant/tenant-capabilities)

<img src="https://github.com/spree/spree/assets/12614496/cf651354-6180-4927-973f-c650b80ccdb0"  alt="Spree Commerce - Multi-tenant eCommerce Platform" width="600" >

## Community & Contributing

Spree is an open source project, and we love contributions in any form -- pull requests, issues, feature ideas!

Follow our [Contributing Guide](https://spreecommerce.org/docs/developer/contributing/quickstart)

[Join our Discord](https://discord.spreecommerce.org) to meet other community members.

## Contact

[Contact us](https://spreecommerce.org/get-started/) and let's go!

## License

Spree Commerce core code in the **[spree/spree](https://github.com/spree/spree)** repository is released under the free, open-source [BSD-3-Clause](https://opensource.org/license/bsd-3-clause) license ([LICENSE](https://github.com/spree/spree/blob/main/LICENSE)).

If you like what you see, consider giving Spree a GitHub star ⭐

Thank you for supporting Spree open-source ❤️
