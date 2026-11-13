---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
---

Saving a supplier under a name already in use, or with an invalid email, shows the reason under the field on the supplier sheet and page instead of doing nothing. `useServerErrors` in `@spree/dashboard-core` gives a form kept in plain state the same server messages `mapSpreeErrorsToForm` gives a React Hook Form.
