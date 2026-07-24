---
'create-spree-app': patch
'@spree/cli': patch
---

Auto-enable the storefront wholesale B2B portal on sample-data scaffolds: create-spree-app writes `SPREE_WHOLESALE_CHANNEL=wholesale` into the storefront `.env.local`, and setup output points at the portal (`/wholesale`) with the buyer-approval flow. The portal runs on the default publishable key — no extra key or backend changes involved.
