---
"@spree/dashboard": patch
"@spree/dashboard-ui": patch
---

The dashboard type-checks again against TanStack Router 1.170, which types a route error as `unknown`. `ErrorState` now accepts whatever a route throws for its `error` prop and shows the message when it is an `Error`.
