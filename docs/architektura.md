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
│  PRODUKCJA: Oracle Cloud VPS (od 2026-07-09)          │
│  141.253.103.172 (IP; docelowo domena)                │
│  ├── Postgres + Redis (Docker na tej samej VM)        │
│  ├── Rails/Puma/Sidekiq (Docker)                      │
│  └── Media:    Cloudflare R2, bucket                  │
│                kakaowy-sklepik-media (Active Storage) │
└──────────────────────────────────────────────────────┘
```

Migracja backendu z Rendera na Oracle Cloud **zakończona 2026-07-09** (F8). Backend Rails/API + Postgres + Redis + Sidekiq + Nginx/SSL działają w Docker Compose na Oracle VPS (`VM.Standard.E4.Flex`, 1 OCPU, 8 GB RAM, Ubuntu 22.04, region Paris). Storefront i panel admina zostały zaktualizowane (rewrite URL-i w Vercelu) i wskazują teraz na nowy Oracle backend. R2 pozostaje zewnętrznym storage'iem.

Uwaga na mylącą nazwę: projekt Vercel `sklepik_back` to **panel administracyjny (React SPA)**, nie backend Rails. Backend Rails działa teraz na Oracle Cloud (był na Renderze).

## Repozytoria

| Repo | Zawartość |
|---|---|
| `pawelekbyra/sklepik` | Silnik Rails (`spree/core`, `spree/api`), panel admina (`packages/dashboard`, `dashboard-core`, `dashboard-ui`), SDK (`packages/sdk`, `admin-sdk`, `sdk-core`), CLI, deployment backendu (`render.yaml`, `bin/render-build.sh`, docelowo `docs/deployment-oracle.md`) |
| `pawelekbyra/sklepikFront` | Storefront Next.js 16 / React 19, `@spree/sdk`, webhooki e-mail, deployment Vercel |

## Przepływy danych

- **Klient kupuje:** storefront → Store API (`X-Spree-API-Key` publishable key; koszyk gościa przez token w cookie). Cały rendering server-side w Next.js, cache przez `"use cache"` + edge Vercela.
- **Operator zarządza:** dashboard → Admin API (JWT po zalogowaniu; single-origin proxy `/api/*` → obecnie Render w `packages/dashboard/vercel.json`, po cutoverze Oracle), dzięki czemu httpOnly refresh cookie działa bez CORS.
- **Media produktów:** upload przez Admin API → Active Storage → R2 (S3-compatible); URL-e publiczne budowane z `CDN_HOST`.
- **E-maile transakcyjne:** backend wysyła webhooki → storefront (`src/app/api/webhooks`, react-email/Resend). Silnikowe `spree/emails` nie jest używane docelowo.
- **Inwalidacja cache storefrontu:** ten sam webhook endpoint (Admin → Ustawienia → Webhooks, wskazuje na `{storefront}/api/webhooks/spree`) ma też subskrybowane `product.created`/`updated`/`deleted`/`activated`/`archived`/`out_of_stock`/`back_in_stock` — storefront busuje na nich cache produktu zamiast czekać na TTL (F4, `sklepikFront/docs/technical-debt.md`). Zasada na przyszłość: nowy event dopisuje się do subskrypcji w adminie **tylko** razem z handlerem po stronie frontu (`sklepikFront/src/lib/webhooks/handlers.ts`) — inaczej to martwy ruch webhookowy bez efektu.

## Środowiska i zmienne

| Gdzie | Kluczowe zmienne |
|---|---|
| Oracle Cloud (backend — produkcja od 2026-07-09) | `.env` na serwerze: `DATABASE_URL`, `REDIS_URL`, `SECRET_KEY_BASE`, `RAILS_MASTER_KEY`, `SPREE_PATH` (gemy z tego forka), `CDN_HOST=https://141.253.103.172` (tymczasowo IP, docelowo domena). R2 credentials w envie wewnątrz `web` kontenera; wszystkie sekrety wyłącznie na serwerze, nigdy w repo. VM: `VM.Standard.E4.Flex`, 1 OCPU, 8 GB RAM, Ubuntu 22.04, VCN `sklepik-vcn`, public subnet. Szczegóły: [`deployment-oracle.md`](deployment-oracle.md). |
| Render (legacy — wycofany) | Był używany do 2026-07-09. |
| Vercel `sklepik_front` | `SPREE_API_URL=https://141.253.103.172`, `SPREE_PUBLISHABLE_KEY`, `NEXT_PUBLIC_SITE_URL`, `NEXT_PUBLIC_DEFAULT_LOCALE=pl` — pełna lista: `sklepikFront/docs/deployment-vercel.md` |
| Vercel `sklepik_back` | Root Directory `packages/dashboard`; backend URL w `packages/dashboard/vercel.json` (rewrites) zmieniony z Rendera na Oracle (2026-07-09) |

Sekrety trzymamy wyłącznie w dashboardach hostingów albo na serwerze. Nigdy w repo.

## Deployment

- Backend obecnie: [`deployment-render.md`](deployment-render.md) — jak realnie działa build na Render (i jakie ma znane ryzyka).
- Backend docelowo: [`deployment-oracle.md`](deployment-oracle.md) — decyzja migracyjna, wybrany VPS, zasady bezpieczeństwa i checklisty cutoveru.
- Storefront: `sklepikFront/docs/deployment-vercel.md`.
- Admin: deploy automatyczny z repo `sklepik` (Root Directory `packages/dashboard`); znany quirk — webhook Vercela potrafi przestać łapać pushe, pomaga ręczny "Redeploy" w UI.

## Historia wyborów infrastruktury

- Neon Postgres i Upstash Redis były testowane na starcie (przez Vercel) i **zostały porzucone** — produkcyjny backend korzysta obecnie z bazy i Redisa na Render.
- Render free/starter okazał się zbyt słaby dla backendu Rails/Spree: cold start i dwukrotny OOM przy ruchu API; Starter nie rozwiązuje RAM, a pełniejszy Render setup z większym webem i workerem Sidekiq robi się relatywnie drogi.
- Oracle Cloud został wybrany jako kierunek migracji backendu: najpierw próbowany Always Free Ampere A1, ale w regionie Paris wystąpił `Out of capacity`; zaakceptowany fallback to płatny, mały `VM.Standard.E4.Flex` 1 OCPU / 8 GB RAM, bo celem jest stabilny sklep z drogą rozbudowy, nie najtańszy możliwy hosting za wszelką cenę.
- Kierunek "Vercel Commerce jako storefront" został **odrzucony** (brak ROI — `@spree/sdk` + obecny storefront realizują ten sam zakres bez pisania adaptera Shopify→Spree).
- Legacy Rails admin (`spree/admin`) jest wyłączony na rzecz React SPA (`packages/dashboard`).
