---
"@spree/dashboard": minor
"@spree/dashboard-core": minor
---

Host apps that build their own screens on the dashboard packages can now import the sign-in building blocks directly: `@spree/dashboard/components/spree/auth-shell` (`AuthShell`), `@spree/dashboard/hooks/use-auth-providers` (`useAuthProviders`, plus `authCallbackErrorKey` for the errors the SSO callback redirects back with) and `@spree/dashboard/schemas/auth` (the auth form schemas). The `admin.fields.setup.*` translations moved to `@spree/dashboard-core`, so `StoreSetupFields` renders translated outside the full dashboard too.
