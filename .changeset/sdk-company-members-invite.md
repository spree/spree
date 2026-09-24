---
"@spree/sdk": patch
---

`companies.members.create` now always returns the `CompanyInvitation`: adding a member from the storefront sends an invitation even to an existing customer, who joins by accepting it.
