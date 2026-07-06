# Deployment status

## 2026-07-06

Status: succeeded.

The Render deployment completed successfully. The backend application is running, the database is connected, seed data was loaded, and the management panel was reached successfully.

Additional verification:

- the backend build and deploy completed successfully,
- sample data seeding completed,
- initial operator access was prepared,
- access to the management panel was confirmed.

Trial external services:

- Neon Postgres was added for testing through Vercel and used as the database provider.
- Upstash Redis was added for testing through Vercel and used as the Redis provider.
- The deployment was given environment variables for the external database and Redis connections.
- These provider integrations and environment values are recorded as trial configuration and have not been fully tested end-to-end yet.
- No provider secrets, tokens, passwords, or connection strings are stored in this repository.

Next steps:

- return the Render Build Command to the standard build script,
- keep environment values only in hosting/provider dashboards,
- continue with store configuration and storefront integration,
- verify the Neon and Upstash configuration end-to-end before treating it as production-ready.

## 2026-07-06 (continued) — admin dashboard deployment

Status: in progress. Backend fork now builds correctly; admin dashboard is deployed but two committed fixes have not gone live yet.

Architecture, clarified: three independently deployed pieces share one backend, not two.

- Storefront (customer-facing): Vercel project `sklepikkk`, Next.js, repo `pawelekbyra/sklepikFront`. Working, connected to the Store API.
- Backend (all data and business logic): Render service `kakaowy-sklepik-backend`, repo `pawelekbyra/sklepik`.
- Admin dashboard (operator-facing): Vercel project `sklepik`, Vite/React SPA (`packages/dashboard`), same repo, Root Directory `packages/dashboard`. New this session — an earlier session had already disabled the legacy Rails admin (`spree/admin`) in favor of this SPA, but the SPA itself had never been deployed anywhere until now, which is why the Polish/white-label admin work was invisible.

Backend fix:

- `bin/render-build.sh` was building with published RubyGems Spree releases instead of this fork's `spree/core`, `spree/api`, `spree/admin`, `spree/emails` gems (`SPREE_PATH` was deliberately left unset). Fixed to set `SPREE_PATH` to the repo root so fork changes actually reach the deployed backend.

Admin dashboard deployment:

- Vercel project `sklepik` imports `pawelekbyra/sklepik` with Root Directory `packages/dashboard`.
- `packages/dashboard/vercel.json` rewrites `/api/*` and `/rails/*` to the Render backend (single-origin proxy — no CORS, refresh-token cookie works under `SameSite=Lax`), plus a catch-all rewrite to `index.html` for the SPA's client-side routing.
- Login and the JWT auth flow verified working end-to-end through the proxy.
- Two pre-existing bugs found and fixed in `packages/dashboard-core`: missing SPA fallback caused 404s on any client-side route after the first load; and `auth-provider.tsx` read `localStorage` without the same try/catch guard used elsewhere in `i18n.ts`, so a restricted-storage context (private browsing) could throw, be misread as a failed token refresh, and clear a valid session — `switchLocale`/`reconcileStoreDefaultLocale` also reloaded the page unconditionally even when the locale write failed, risking an infinite reload loop.
- Both fixes are committed and pushed but had not deployed by end of session — Vercel's git webhook stopped picking up new pushes on this project partway through; a manual "Redeploy" only replayed the previously built commit, and a Deploy Hook call did not produce a new deployment either. Suspected Hobby-plan throttling; unconfirmed.

Known issue — Render free-tier cold start:

- `render.yaml` configures `plan: starter`, but the live service was observed to cold-start (~18s on the first request after ~15 minutes idle, ~0.5s once warm), consistent with the free tier. The committed blueprint and the live Render dashboard plan may be out of sync. Needs a paid plan before this can carry real traffic.

Not yet done (blockers before this can go live):

- Payment gateway configuration — spree-starter's Gemfile already includes `spree_stripe`, `spree_adyen`, `spree_paypal_checkout`, but none has been configured with real credentials.
- Legal pages (regulamin, polityka prywatności, prawo odstąpienia) — required for a Polish store.
- Custom domains for all three deployed pieces (currently `*.vercel.app` / `*.onrender.com`).
- Vercel account cleanup — roughly a dozen stray/duplicate projects exist alongside the two real ones (`sklepikkk`, `sklepik`).

Next steps:

- Confirm whether the Vercel deploy stall was a plan limit; retry pushing/redeploying the next day.
- Once the dashboard is current, re-test login end to end to confirm the auth-provider/i18n fixes resolved the reported post-login flicker.
- Configure a real payment gateway.
- Move Render to a paid plan.
