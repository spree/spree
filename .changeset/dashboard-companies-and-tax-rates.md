---
"@spree/dashboard": minor
"@spree/dashboard-core": minor
"@spree/dashboard-ui": minor
"@spree/admin-sdk": minor
---

Add dashboard pages for business customers and tax configuration.

Companies get a list and a detail page with their branches, tax registration
and exemption certificates; a branch has its own page listing the buyers
authorised to purchase for it. Customers gain the same tax registration panel
on their profile. Tax rates get a settings page, and a market can now name the
tax engine that prices it — showing what that engine cannot handle, so a
merchant learns about a gap while configuring rather than from a tax bill.

The admin SDK gains the customer tax-identifier endpoints and `tax_provider`
on market params.
