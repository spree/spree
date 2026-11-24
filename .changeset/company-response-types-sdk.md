---
"@spree/sdk": patch
---

`account.companies()` returns `AccountCompanyMembership[]` and `companyInvitations.lookup()` returns `CompanyInvitationDetails`. Both types are generated from the API's serializers and replace inline intersections with the same fields.
