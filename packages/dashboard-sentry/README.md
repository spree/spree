# @spree/dashboard-sentry

Sentry error tracking for the Spree admin dashboard and seller panel.

```bash
pnpm add @spree/dashboard-sentry
```

Start it in the app's `src/main.tsx`, before the app renders:

```tsx
import { initDashboardSentry } from '@spree/dashboard-sentry'

initDashboardSentry({ dsn: import.meta.env.VITE_SENTRY_DSN })
```

It takes any Sentry browser option, plus `enableInDevelopment` (off by default). Without a DSN it does nothing.

It reports uncaught errors, unhandled promise rejections and the errors the panel's error screens catch, with the signed-in user and a `panel` tag (`admin` or `seller`). Single-use tokens in URLs, messages and breadcrumbs are redacted before sending, after your own `beforeSend` and `beforeBreadcrumb`.

Full guide: https://spreecommerce.org/docs/developer/dashboard/recipes/error-tracking
