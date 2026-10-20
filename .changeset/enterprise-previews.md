---
"@spree/dashboard": minor
"@spree/dashboard-core": minor
---

Added previews of Spree Enterprise features where they appear once installed: Quotes under Orders, Onboarding under Companies, Shopify under Sellers, Lots under Inventory, and Audit log in Users & permissions settings. Companies is now its own section in the sidebar rather than sitting under Customers. Set `VITE_SPREE_ENTERPRISE_PREVIEWS=false` at build time to leave the previews out. Settings entries accept a `badge`, and plugin pages under `/settings` get the settings page padding. Registry routes can sit under a built-in section (`/sellers/shopify`) instead of being taken by its record page.
