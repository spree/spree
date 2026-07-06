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

## 2026-07-06 (continued) — rebrand, locale-only URLs, product seeding, Render build fix

Status: in progress. Storefront rebrand shipped and verified; backend has an unresolved build failure from the Gemfile.lock issue described below (fix pushed, redeploy not yet confirmed green).

Storefront (`sklepikFront`, Vercel project `sklepikkk`):

- Rebranded as "Kakałowy Sklepik" (`getStoreName()`/`getStoreDescription()` defaults in `src/lib/store.ts`), removed all demo-only Spree/GitHub/quickstart links and the Spree logo from `Header`, `Footer`, `HeroSection`, and the checkout layout.
- Made Polish the default locale with no URL prefix; every other locale (currently just `en`) gets a `/{locale}` prefix. Removed the `/{country}` URL segment entirely — this is a single-market store, so the country used for market/currency resolution (`getDefaultCountry()`) is now a fixed server-side default instead of a URL segment. Route tree moved `src/app/[country]/[locale]/` → `src/app/[locale]/`; `src/lib/spree/middleware.ts` rewritten for "as-needed" locale prefixing (rewrite to the default locale internally, canonicalize an explicit `/pl/...` URL back to the unprefixed form); `src/lib/utils/path.ts` (`buildBasePath`/`extractBasePath`/`getPathWithoutPrefix`) updated to match. `src/app/sitemap.ts` and `robots.ts` updated for locale-only URLs.
- Product URLs use the product slug again (reverted the earlier ID-based emergency fix — Store API does return `slug`, the original issue was a TypeScript-only problem).
- Full `npm run build` and `npx vitest run` (89 tests) verified green before push.

Backend (`spree/api`):

- `available_on` added to the admin products API's permitted params — products created via the API were invisible on the storefront even when `status: active` and in stock, because the store-facing scope requires `available_on` set in the past when no channel context resolves visibility via `ProductPublication`, and there was no way to set it.
- Seeded 6 real "Kakałowy Sklepik" cocoa-themed products directly via the Admin API (`curl` against the live Render backend with the seed admin JWT) — not a code change, no PR, just data. Also had to flip the store's default stock location `propagate_all_variants` to `true` (was `false`, so new variants never got a stock item) and manually set `count_on_hand` on each — Store API's own `available` scope pagination quirk (25/page, item was on page 4) briefly looked like the stock items didn't exist at all.
- **Found a real deploy bug**: `bin/render-build.sh` only clones `spree-starter` into `server/` when that directory doesn't already exist, so `server/Gemfile.lock` persists across builds. Once `SPREE_PATH` was introduced (previous session) to point the Gemfile at this fork's local gems instead of published ones, the old persisted lockfile — resolved before that change — kept bundler looking for the published `spree (>= 5.5.0.rc3)` gem, causing a hard `Bundler::GemNotFound` build failure. Fixed by deleting `Gemfile.lock` before every `bundle install` (matches spree-starter's own convention of not committing a lockfile at all). Pushed as `8143907`; **redeploy not yet confirmed to succeed**.
- Also observed one **out-of-memory crash** on the live Render instance (>512MB, free/starter-tier limit) during this session's heavy API testing; Render auto-recovered ~1 minute later. Not yet known whether this recurs under normal (non-testing) load — worth watching after the plan upgrade decision below.

Admin dashboard flicker — extensive investigation, inconclusive final state:

- Confirmed via real deploy (commit `cbe5490`, live ~21 min before last check) that both known reload-loop code paths in `packages/dashboard-core/src/lib/i18n.ts` are fixed and deployed; `localStorage` values inspected directly (Application tab) show fully consistent state (`spree-admin-locale: pl`, `spree-admin-locale-auto-store: store_UkLWZg9DAJ`) — no stale/inconsistent value that would explain a loop.
- User continued to observe rapid flicker/reload on `sklepik-gamma.vercel.app` after logging in, even in a fresh incognito window. A `console.trace`-based `window.location.reload` interceptor was handed to the user to get a definitive stack trace; before that ran to conclusion, the browser's own navigation log showed `Navigated to chrome://newtab/` interleaved with the dashboard URL and a back/forward-cache restore — a page cannot script-trigger a navigation to `chrome://newtab/`, which points at something outside the app (browser/DevTools "Responsive" device mode, or an extension) rather than a code bug.
- Also saw a transient, unrelated `Uncaught TypeError: Failed to resolve module specifier "spree/admin/controllers/display_name_controller"` — a legacy Rails/Stimulus asset path that has no reason to load in this Vite/React app at all; most likely a stale cached resource from the same long-reused incognito window (this domain briefly served different content earlier in the day). Did not reappear after closing all incognito windows and starting a completely fresh one.
- **Not conclusively resolved.** Next session: reproduce (or fail to reproduce) on a normal browser window without DevTools' responsive/device-toolbar mode active, ideally on a different device, before spending more time on it.

Architecture question raised and answered (not implemented): could the storefront and admin dashboard be merged into one site with email/password gating the admin view? Recommendation was to keep them as two separate deployments (different frameworks — Next.js vs Vite/TanStack Router; separate deploys give independent scaling, caching rules, and security blast-radius) but put both behind one custom domain later via a Vercel path rewrite (`/admin/*` → the dashboard deployment), once a domain is purchased.

Vercel deploy-hook / throttling behavior (dashboard project only): manually clicking "Redeploy" in the Vercel UI appears to unstick the project's ability to pick up new commits shortly afterward — happened twice this session. Still unconfirmed whether this is a genuine Hobby-plan rate limit; treat it as a known quirk to work around (manual UI redeploy, then retry the deploy hook) rather than a solved problem.

Next steps:

- Confirm the Render Gemfile.lock fix (`8143907`) actually produces a green build.
- Once green, verify `available_on` now persists and the 6 seeded products appear on `sklepikkk.vercel.app`.
- Re-check the dashboard flicker on a plain browser window (no DevTools responsive mode) before investigating further.
- Decide Render plan: `$7/mo` Starter removes the free-tier cold start but is the same 512MB RAM as free — may not prevent a repeat of the OOM crash seen this session; watch for recurrence under real (non-testing) traffic before deciding whether Standard (~$25/mo, 2GB) is needed.
- Payment gateway configuration, legal pages, and a custom domain remain the pre-launch blockers noted in the previous entry.

## 2026-07-06 (continued) — post-recovery technical audit

Status: backend + admin dashboard operational; storefront catalog fixed at the data layer, awaiting an edge-cache refresh. This entry is a candid audit written after a long chain of cascading failures, to record what is fragile (not just what is fixed) and to seed a deeper external review.

What actually got fixed this session (in order):
- Render build: engine migrations were never copied into the host app, so `db:migrate` never applied them (`spree:install:migrations` added to `bin/render-build.sh`).
- Two migrations (`role_users` store_id, `variants` preorder fields) lacked `if_not_exists`, causing a duplicate-column crash once `server/` began being recloned every build.
- Admin API 500 on every membership-checked endpoint: missing `spree_role_users.store_id` column (the same migration gap) — this was the "endless skeletons" symptom.
- Dashboard infinite reload loop: `reconcileStoreDefaultLocale` compared against i18next's live `resolvedLanguage` (which races bundle registration at boot) instead of persisted storage.
- Product image URLs rendered as `https://localhost:3000/...`: added `CDN_HOST` env → `Spree.cdn_host` default in the core engine initializer.
- Catalog invisible on the storefront: products had `available_on: nil` AND no `ProductPublication` binding them to the default channel — both required, neither set on API-seeded products.
- Currency USD→PLN: the store carried 7 leftover demo Markets (US default). Consolidated to a single Polska/PLN/pl market. This cascaded — dropping locales blanked 5/6 product names (content lived under `en`, which stopped being "supported"); had to re-add `en` as a supported locale and copy content into `pl`, then add PLN prices for all 6 variants.
- Real data-corruption bug found: saving a product price in the dashboard turned `24.99` into `24990` (decimal-separator / number-parse bug, surfaces with PLN comma formatting). Corrected the value; the underlying bug is NOT fixed.

Structural fragility observed (the "why this keeps breaking"):
1. Currency ↔ locale ↔ product-visibility are tightly and implicitly coupled. A single "change the default market" action silently broke product names (translation fallback), prices (currency-scoped prices), and catalog visibility. The data model (Markets / Channels / ProductPublications / Mobility translations / per-currency Prices) has too many co-dependent preconditions for a product to be "visible and correct," with no single validation surfacing when one is unmet.
2. Engine migrations are not durable across deploys — the build recreates `server/` from scratch and re-copies migrations under fresh timestamps every time, which already caused one production crash. Current handling is defensive (idempotent guards), not a real solution.
3. Multi-layer caching on the storefront (Next.js `"use cache"` + Vercel edge cache) makes corrected data invisible for 10–15 min with no signal that it's *only* cache — indistinguishable from "still broken" without header/log access.
4. Admin dashboard does not surface API failures: a 500 renders as permanent loading skeletons, not an error. Every backend fault this session was invisible in the UI.
5. No end-to-end test covers the market/currency-change → catalog-visibility path; the entire evening's failure chain would have been caught pre-production by one such test.

Deep-research prompt for a full external diagnosis lives in `docs/research-prompt-technical-audit.md`.

Next steps:
- Fix the dashboard price parse bug (`24.99` → `24990`) — highest priority, silent data corruption.
- Make the admin SPA render API errors instead of infinite skeletons.
- Add an e2e test: change default market/currency, assert catalog still renders with correct names + prices.
- Everything from prior entries (payments, legal pages, domain, Render plan) still stands.
