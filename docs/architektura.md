# Architektura systemu

Jedyna mapa systemu Kakałowy Sklepik. Jeśli infrastruktura się zmienia, aktualizuje się ten plik — nie tworzy się nowych map.

## Trzy aplikacje, jeden backend

```text
┌─────────────────────┐        ┌──────────────────────┐
│  Storefront (klient) │        │  Admin (operator)    │
│  Next.js             │        │  React SPA (Vite)    │
│  repo: sklepikFront  │        │  repo: sklepik       │
│  Vercel: sklepik_front│       │  packages/dashboard  │
│  sklepikkk.vercel.app│        │  Vercel: sklepik_back│
└─────────┬───────────┘        │  sklepik-gamma       │
          │ Store API v3        │  .vercel.app         │
          │ (@spree/sdk,        └──────────┬──────────┘
          │  publishable key)              │ Admin API v3
          │                                │ (JWT, proxy /api/* w vercel.json)
          ▼                                ▼
┌──────────────────────────────────────────────────────┐
│  Backend Rails (fork Spree) — repo: sklepik           │
│  Render: kakaowy-sklepik-backend (Frankfurt)          │
│  kakaowy-sklepik.onrender.com                         │
│  ├── Postgres: kakaowy-sklepik-db (Render, free)      │
│  ├── Redis:    kakaowy-sklepik-redis (Render, free)   │
│  └── Media:    Cloudflare R2, bucket                  │
│                kakaowy-sklepik-media (Active Storage) │
└──────────────────────────────────────────────────────┘
```

Uwaga na mylącą nazwę: projekt Vercel `sklepik_back` to **panel administracyjny (React SPA)**, nie backend Rails. Backend Rails żyje wyłącznie na Render.

## Repozytoria

| Repo | Zawartość |
|---|---|
| `pawelekbyra/sklepik` | Silnik Rails (`spree/core`, `spree/api`), panel admina (`packages/dashboard`, `dashboard-core`, `dashboard-ui`), SDK (`packages/sdk`, `admin-sdk`, `sdk-core`), CLI, deployment backendu (`render.yaml`, `bin/render-build.sh`) |
| `pawelekbyra/sklepikFront` | Storefront Next.js 16 / React 19, `@spree/sdk`, webhooki e-mail, deployment Vercel |

## Przepływy danych

- **Klient kupuje:** storefront → Store API (`X-Spree-API-Key` publishable key; koszyk gościa przez token w cookie). Cały rendering server-side w Next.js, cache przez `"use cache"` + edge Vercela.
- **Operator zarządza:** dashboard → Admin API (JWT po zalogowaniu; single-origin proxy `/api/*` → Render w `packages/dashboard/vercel.json`, dzięki czemu httpOnly refresh cookie działa bez CORS).
- **Media produktów:** upload przez Admin API → Active Storage → R2 (S3-compatible); URL-e publiczne budowane z `CDN_HOST`.
- **E-maile transakcyjne:** backend wysyła webhooki → storefront (`src/app/api/webhooks`, react-email/Resend). Silnikowe `spree/emails` nie jest używane docelowo.
- **Inwalidacja cache storefrontu:** ten sam webhook endpoint (Admin → Ustawienia → Webhooks, wskazuje na `{storefront}/api/webhooks/spree`) ma też subskrybowane `product.created`/`updated`/`deleted`/`activated`/`archived`/`out_of_stock`/`back_in_stock` — storefront busuje na nich cache produktu zamiast czekać na TTL (F4, `sklepikFront/docs/technical-debt.md`). Zasada na przyszłość: nowy event dopisuje się do subskrypcji w adminie **tylko** razem z handlerem po stronie frontu (`sklepikFront/src/lib/webhooks/handlers.ts`) — inaczej to martwy ruch webhookowy bez efektu.

## Środowiska i zmienne

| Gdzie | Kluczowe zmienne |
|---|---|
| Render (backend) | `DATABASE_URL`, `REDIS_URL`, `SECRET_KEY_BASE`, `SPREE_PATH` (gemy z tego forka), `CDN_HOST`, dane R2 (w dashboardzie Render, nie w repo) |
| Vercel `sklepik_front` | `SPREE_API_URL`, `SPREE_PUBLISHABLE_KEY`, `NEXT_PUBLIC_SITE_URL`, `NEXT_PUBLIC_DEFAULT_LOCALE=pl` — pełna lista: `sklepikFront/docs/deployment-vercel.md` |
| Vercel `sklepik_back` | Root Directory `packages/dashboard`; backend URL wpisany w `packages/dashboard/vercel.json` (rewrites) |

Sekrety trzymamy wyłącznie w dashboardach hostingów. Nigdy w repo.

## Deployment

- Backend: [`deployment-render.md`](deployment-render.md) — jak realnie działa build na Render (i jakie ma znane ryzyka).
- Storefront: `sklepikFront/docs/deployment-vercel.md`.
- Admin: deploy automatyczny z repo `sklepik` (Root Directory `packages/dashboard`); znany quirk — webhook Vercela potrafi przestać łapać pushe, pomaga ręczny "Redeploy" w UI.

## Historia wyborów infrastruktury

- Neon Postgres i Upstash Redis były testowane na starcie (przez Vercel) i **zostały porzucone** — produkcyjny backend korzysta z bazy i Redisa na Render.
- Kierunek "Vercel Commerce jako storefront" został **odrzucony** (brak ROI — `@spree/sdk` + obecny storefront realizują ten sam zakres bez pisania adaptera Shopify→Spree).
- Legacy Rails admin (`spree/admin`) jest wyłączony na rzecz React SPA (`packages/dashboard`).
