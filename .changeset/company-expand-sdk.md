---
"@spree/sdk": patch
---

`CompanyMembership` and `CompanyInvitation` can expand `company`. `companyInvitations.lookup()` takes `params` as its second argument, as other reads do, so pass `{ expand: ['company'] }` to get the company; request options move to the third argument. `company_name` and `store_name` on the lookup are deprecated and removed in 6.5: read `company.name` from the expand and the store's name from `store.get()`.
