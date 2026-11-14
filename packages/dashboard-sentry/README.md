# @spree/dashboard-sentry

Sentry error tracking for the Spree admin dashboard and seller panel.

```bash
pnpm add @spree/dashboard-sentry
```

Set `VITE_SENTRY_DSN` to a browser (React) Sentry project's DSN and rebuild. The dashboard's Vite plugin loads the package on its own; no code changes are needed.

| Variable | Purpose |
|---|---|
| `VITE_SENTRY_DSN` | Sentry project DSN. Off while blank |
| `VITE_SENTRY_ENVIRONMENT` | Environment name. Defaults to the Vite mode |
| `VITE_SENTRY_RELEASE` | Release name, for example the deployed commit |
| `VITE_SENTRY_ENABLE_IN_DEVELOPMENT` | `true` to report from the dev server |

It reports uncaught errors, unhandled promise rejections and the errors the panel's error screens catch, with the signed-in user and a `panel` tag (`admin` or `seller`). Single-use tokens in URLs and messages are redacted before sending.

Full guide: https://spreecommerce.org/docs/developer/dashboard/recipes/error-tracking
