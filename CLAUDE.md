# Kakałowy Sklepik — silnik commerce: zasady dla agentów

## Kontekst projektu (przeczytaj najpierw)

To repozytorium to backend + panel administracyjny własnej platformy e-commerce **Kakałowy Sklepik** (produkty kakao). Silnik jest forkiem Spree Commerce, ale projekt jest samodzielny: upstream Spree to fundament techniczny, nie wyznacza celu ani roadmapy. Storefront klienta żyje w osobnym repo `pawelekbyra/sklepikFront` (Next.js) i konsumuje Store API v3 z tego repo.

Obowiązkowa lektura przed pracą:

- [`docs/kierunek-projektu.md`](docs/kierunek-projektu.md) — **kanon**: cel, podział repo, hierarchia decyzji, kiedy wolno zmieniać core.
- [`docs/stan-projektu.md`](docs/stan-projektu.md) — bieżący stan, znane problemy.
- [`docs/roadmap.md`](docs/roadmap.md) — backlog i priorytety (P0 przed P1 itd.).
- [`docs/architektura.md`](docs/architektura.md) — mapa systemu i hostingu (Render + Vercel + R2).

## Protokół dokumentacji (obowiązkowy)

Dokumentacja ma **zawsze odzwierciedlać rzeczywisty stan projektu**. Po każdym zakończonym zadaniu, w tym samym PR/commicie:

1. Zaktualizuj [`docs/stan-projektu.md`](docs/stan-projektu.md) — popraw treść (co działa / znane problemy), nie dopisuj dziennika; historia jest w gicie.
2. Jeśli zadanie było z roadmapy — zmień jego status w [`docs/roadmap.md`](docs/roadmap.md).
3. Jeśli zmieniłeś core silnika, API, checkout albo płatności — dodaj wpis w [`docs/engine-decisions.md`](docs/engine-decisions.md) (kontekst, decyzja, uzasadnienie, wpływ na storefront).
4. Jeśli zmieniłeś deploy/infrastrukturę — zaktualizuj [`docs/deployment-render.md`](docs/deployment-render.md) i/lub [`docs/architektura.md`](docs/architektura.md).
5. Nie twórz nowych plików-notatek (handoffy, statusy, audyty). Aktualizuj istniejące dokumenty. Większe plany architektoniczne: `docs/plans/` wg `_template.md`.

Zasady twarde: nie commituj sekretów; nie łam kompatybilności Store API bez decyzji w `engine-decisions.md`; sprawdzaj kod zamiast ufać opisom; commity małe i logiczne, po polsku lub angielsku, bez detali implementacyjnych w body.

---

## Monorepo Structure

| Directory | Description |
|---|---|
| `spree/core` | Ruby gem — models, services, business logic (`spree_core`) |
| `spree/api` | Ruby gem — Store & Admin REST APIs v3 (`spree_api`) |
| `spree/admin` | Legacy Rails admin — **wyłączony** na rzecz `packages/dashboard`; służy tylko jako referencja zachowań |
| `spree/emails` | Transactional emails (optional) — docelowo nieużywane; e-maile konsumenckie wysyła storefront przez webhooki |
| `packages/dashboard` | Panel admina — React SPA (Vite, TanStack Router/Query, RHF+Zod, shadcn/Base UI). Deploy: Vercel |
| `packages/dashboard-ui` | Design system — headless komponenty, dane przez propsy, zero importów providerów/hooków |
| `packages/dashboard-core` | Framework panelu — registries, providers, infra hooks, singleton klienta admin SDK, `defineDashboardPlugin` |
| `packages/sdk` | `@spree/sdk` — TypeScript klient Store API |
| `packages/admin-sdk` | `@spree/admin-sdk` — TypeScript klient Admin API |
| `packages/sdk-core` | Wspólna warstwa HTTP/retry/error (prywatna) |
| `packages/cli` | `@spree/cli` — zarządzanie projektem przez Docker |
| `server/` | Rails host-app klonowany ze `spree/spree-starter` (.gitignored; lokalnie `pnpm server:setup`, na Renderze tworzony w buildzie) |

## Development Server (`server/`)

One-time bootstrap (Docker required, no host Ruby): `pnpm install && pnpm server:setup`. It clones spree-starter into `server/`, boots the edge stack (monorepo gems bind-mounted), and prepares + seeds the DB. Re-running it is a **full reset** (wipes DB + volumes).

Day-to-day from the repo root: `pnpm server:dev` (foreground) / `server:stop` / `server:restart` / `server:logs` / `server:console` / `server:seed` / `server:load_sample_data`. CLI commands run from `server/`: `pnpm exec spree <cmd>`.

| What changed | What to run |
|---|---|
| Ruby code in `spree/*` gems | Nothing — bind-mounted, reloads on next request |
| New migration in a gem | Nothing — next `pnpm server:dev` boot runs `spree:install:migrations db:prepare` (or `cd server && pnpm exec spree migrate` while running) |
| Gem dependencies | Next boot self-heals; while running: `cd server && pnpm exec spree bundle install` |
| Compose files / `server/.env` | `pnpm server:dev` (force-recreates web + worker) |
| Broken beyond repair | `pnpm server:setup` (full reset) |

Backend: http://localhost:3000. Admin SPA: `cd packages/dashboard && pnpm dev` → http://localhost:5173 (proxy `/api/*` → :3000). Seed admin user: patrz `spree/core/app/services/spree/seeds/admin_user.rb`.

**Uwaga produkcyjna:** na Renderze `server/` jest klonowany na świeżo przy każdym deployu (build i release to osobne kroki — migracje wykonują się w release'ie, `bin/render-release.sh`, nie w buildzie), a każdorazowe kopiowanie migracji silnika nadaje im nowe timestampy — **każda nowa migracja w `spree/core/db/migrate` musi być idempotentna** (`if_not_exists`/`if_exists`) dopóki `server/` pozostaje efemeryczny. Szczegóły: [`docs/deployment-render.md`](docs/deployment-render.md).

## General rules

- ONLY comment complex or non-obvious code — no comment noise.
- Commit message body: the "what" and "why", never the "how".
- Docs follow the same principle — purpose and usage, not implementation detail.

## Backend (Ruby)

### Architecture Principles

- All code namespaced under `Spree::`; follow Rails conventions and the Rails Security Guide.
- RESTful routes; CanCanCan for authorization (listings: `accessible_by(current_ability, :show)`, other actions: `authorize!`).
- Always scope fetching for security (`current_store.orders`, never bare `Spree::Order`).
- Ransack for filtering, Pagy for pagination.
- Services only when necessary — prefer models and concerns. No logic in controllers or serializers.
- Use `Spree.user_class` / `Spree.admin_user_class`, never user models directly.
- Yard comments only for non-obvious public methods.

### Spree::Current

Per-request context: `Spree::Current.store` / `.currency` / `.locale` — available in models, controllers, jobs, services.

### Models

- Inherit from `Spree.base_class`; include `Spree::Metafields` / `Spree::Metadata` where applicable.
- ALWAYS pass `class_name` and `dependent` on associations (`dependent: :destroy_async` for high-fanout).
- String columns instead of enums; state machines via `state_machines-activerecord` (column `status`; legacy `state`).
- NEVER cast IDs to integer — treat as strings.
- Uniqueness validations: `scope: spree_base_uniqueness_scope` + DB index.
- Soft delete via `acts_as_paranoid` (paranoia gem). Config via Model Preferences.
- NEVER hardcode table names — use `Model.table_name`.

### Migrations

- `ActiveRecord::Migration[7.2]`; no FK constraints; no default values; `null: false` on required columns.
- Data transformations in rake tasks, never in migrations.
- **Idempotent DDL** (`if_not_exists:`/`if_exists:`) — patrz uwaga produkcyjna wyżej.
- JSON columns cross-DB: `t.respond_to?(:jsonb) ? t.jsonb(:metadata) : t.json(:metadata)`.

### API Controllers (v3)

Store API (klient) i Admin API (back-office) to dwie połówki tego samego v3 — te same konwencje routingu, parametrów i formatu odpowiedzi; różni je zakres danych, autoryzacja i domyślnie włączone akcje.

- Base: `Spree::Api::V3::ResourceController` — Pagy, Ransack, CanCanCan, prefixed IDs, HTTP caching.
- Store: `…::Store::ResourceController` — publishable key, **read-only by default**.
- Admin: `…::Admin::ResourceController` — secret key (scopes) lub JWT (CanCanCan), **full CRUD by default**.
- Overridable: `model_class`, `serializer_class` (via `Spree.api.serializer_name`), `scope` (call `super` and chain), `find_resource`, `permitted_params`, `collection_includes`.
- **Flat params** — `params.permit(:name, :slug)`, nigdy `params.require(:product).permit(...)`.
- **Read/write symmetry:** serializer exposes `label` ⇒ controller permits `:label`. Legacy column names bridged by model aliases (`def label=(v); self.presentation = v; end`), never by the client.

### Prefixed IDs

Stripe-style (`prod_86Rf07xd4z`): always return and accept prefixed IDs; `BaseSerializer` auto-converts primary `id`; associations use `object.assoc&.prefixed_id`; lookups via `find_by_prefix_id!`.

### Serializers (Alba)

`spree/api/app/serializers/spree/api/v3/`. **Admin extends Store.**

- Store (customer-visible): public data, computed display values, customer pricing. **No timestamps, no internal state** (cost_price, audit fields, private metadata).
- Admin (back-office): always `created_at`/`updated_at`/`deleted_at`, cost price, internal notes/status, operational relations.
- `typelize attr: :type` for computed attributes; never `typelize_from`.

### Events

`order.publish_event('order.completed')`; subscribers in `app/subscribers/spree/` (`subscribes_to '...'`, `handle(event)`), payloads use prefixed IDs. New models: `publishes_lifecycle_events` + event serializer.

### API Authentication

- Publishable keys (`pk_…`) — Store API, `X-Spree-API-Key`; safe client-side.
- Secret keys (`sk_…`) — Admin API, server-to-server, scope-based (`read_products`, `write_orders`, …).
- JWT `Authorization: Bearer` — logged-in customer (Store) / admin user (Admin, CanCanCan) — to używa panel admina.
- Guest cart tokens — `X-Spree-Token`.

### Security & Performance

- CanCanCan checks on all actions; `params.permit` allowlists; Ransack allowlists on models (`whitelisted_ransackable_*`).
- `includes`/`preload` against N+1 (`ar_lazy_preload` active); `Rails.cache` for expensive ops; proper indexes.

### I18n

`Spree.t`; translations in `config/locales/en.yml` (+ `pl.yml` — panel i sklep są domyślnie polskie).

## Frontend (TypeScript)

pnpm workspace + Turbo; Tsup builds; Vitest tests; **Biome** (not ESLint) — root `biome.json`, per-package extends.

```bash
pnpm install / build / test / typecheck / lint / lint:fix / format
```

### SDKs

- `@spree/sdk` (Store) i `@spree/admin-sdk` (Admin): flat resource pattern (`client.products.list()`), retry z backoffem, `SpreeError`, Ransack params przez `transformListParams()` w `sdk-core`. Testy: Vitest + MSW.
- Generated types: `packages/sdk/src/types/generated/` (Store*), `packages/admin-sdk/src/types/generated/` (Admin*); Zod: `packages/sdk/src/zod/generated/`.

### Type Generation Pipeline

Po zmianie serializerów Alba:

```bash
cd spree/api && bundle exec rake typelizer:generate
cd packages/sdk && pnpm generate:zod
cd spree/api && bundle exec rspec spec/integration/
bundle exec rake rswag:specs:swaggerize        # regeneruje docs/api-reference/*.yaml — nie edytować ręcznie
cd packages/sdk && pnpm test
```

Lefthook pre-commit regeneruje typy+Zod automatycznie przy commitach serializerów; kroki 3–5 uruchamiaj sam przed pushem.

### @spree/dashboard — panel admina

Zasady kluczowe:

1. **Admin API jest jedynym źródłem danych.** Brakuje endpointu/atrybutu → najpierw dodaj w `spree/api`, przegeneruj typy, dopiero potem konsumuj.
2. Legacy `spree/admin` służy tylko jako referencja zachowań — nie portuj UX 1:1.
3. SDK zawsze przez custom hooki w `src/hooks/` (`useOrders`, `useProduct`) — nigdy `adminClient` bezpośrednio w komponentach.
4. Granice pakietów: `dashboard-ui` = headless UI (dane przez propsy), `dashboard-core` = framework/registries/providers, `dashboard` = routes/hooki/schematy/locales.

**Translations:** każdy widoczny string przez i18next — zero hardcodowanego tekstu w JSX/kolumnach/opcjach. Klucze: `packages/dashboard/src/locales/*.json` (app) i `packages/dashboard-core/src/locales/*.json` (cross-cutting `admin.common.*`, `admin.fields.*`). Nowy klucz dodajesz do **wszystkich** plików językowych. Schematy w `src/schemas/` trzymają wartości kanoniczne, nigdy labelki — pary `{value, label}` buduj w komponencie.

**Forms:** React Hook Form + Zod (`zodResolver`); submit w try/catch z `mapSpreeErrorsToForm` (`@/lib/form-errors`) — 422 → błędy pól/`errors.root`; hooki na `useResourceMutation` nie toastują 422. Schematy współdzielone w `src/schemas/<resource>.ts`. Żadnych mapperów form↔API maskujących różnice nazw pól — napraw API (read/write symmetry).

**Komponenty — pułapki Base UI:**
- `<Select>` nie renderuje labelek sam — podaj `items` (statyczne) albo render-prop w `<SelectValue>` (dynamiczne); searchable → `<Combobox>`.
- `<Popover>` bywa martwy w portalu `<Sheet>` — renderuj panel inline (`absolute top-full z-50` + pointerdown-outside + Escape). Referencja: `components/spree/color-picker.tsx`.
- Daty wyłącznie przez `<StoreDatePicker>` (strefa czasowa sklepu ze `<StoreProvider>`); w `<Sheet>` z propem `inline`.
- `acts_as_list` ⇒ drag-and-drop (dnd-kit) zamiast pola liczbowego position; `<ResourceTable reorder={...}>` dla tabel, `useFieldArray` + `DndContext` dla edytorów zagnieżdżonych.

## Testing

Always run tests before committing.

### Backend (RSpec)

```bash
cd spree && bundle install && cd core && bundle install
bundle exec rake test_app      # dummy app (once)
bundle exec rspec              # or spec/models/spree/foo_spec.rb:7
```

Factory Bot (factories in `lib/spree/testing_support/factories/`), prefer `build` over `create`; no tests for standard Rails validations; controller specs z `render_views` + `stub_authorization!`; integration specs tylko happy-path/422 (generują przykłady OpenAPI); `Timecop` dla czasu.

### Frontend

```bash
cd packages/sdk && pnpm test               # Vitest + MSW
cd packages/dashboard && pnpm test:e2e     # Playwright (boots Rails test server + Vite)
```

E2E w stylu Capybary: steruj UI, asertuj na UI (`getByRole`/`getByLabel` + `toBeVisible`), **nie** `waitForResponse` na kształt API. Unikalne nazwy z `Date.now()`; duplikaty przycisków disambiguuj przez scoping (`page.getByRole('dialog').getByRole('button', …)`).
