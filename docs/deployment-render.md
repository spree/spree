# Deployment backendu na Render

Opis **faktycznego** zachowania deployu. Jeśli zmieniasz `render.yaml`, `bin/render-build.sh` albo `bin/render-release.sh`, zaktualizuj ten plik w tym samym commicie.

## Zasoby (Blueprint `render.yaml`)

| Zasób | Nazwa | Uwagi |
|---|---|---|
| Web service | `kakaowy-sklepik-backend` | Ruby, Frankfurt, health check `/up`, `plan: starter` w blueprint (żywy serwis zachowywał się jak free — cold start; zweryfikować zgodność) |
| Postgres | `kakaowy-sklepik-db` | plan free |
| Redis | `kakaowy-sklepik-redis` | plan free |
| Worker Sidekiq | — | zakomentowany; wymaga płatnego planu (roadmapa F7) |

Adres: `https://kakaowy-sklepik.onrender.com`.

## Trzy fazy deployu

Render rozdziela deploy na `buildCommand` (produkuje obraz aplikacji), `preDeployCommand` (migruje bazę na zbudowanym obrazie, **przed** przełączeniem ruchu) i `startCommand` (właściwy proces). Migracje **nie są już częścią builda** — to była przyczyna produkcyjnego crasha opisanego niżej.

### 1. Build (`bin/render-build.sh`)

1. Klonuje świeży `spree/spree-starter` do `server/` (przez `server.next`, stary katalog odsuwa na bok) — `server/` jest **efemeryczny**, odtwarzany przy każdym buildzie.
2. Wymusza Ruby `3.4.4` (upstream pinuje 4.0.1, co wywala instalator Rendera).
3. Zapisuje `SPREE_PATH` do `server/.env` → bundler bierze gemy **z tego forka** (`spree/core`, `spree/api`, …), nie z RubyGems. Bez tego zmiany z repo nie trafiają na produkcję.
4. `bundle lock/install/check` (z `BUNDLE_IGNORE_CONFIG=1`), `assets:precompile` (z `SECRET_KEY_BASE_DUMMY=1`).

Baza danych nie jest dotykana w tym kroku.

### 2. Release / pre-deploy (`bin/render-release.sh`)

Uruchamiane przez `preDeployCommand` w `render.yaml`, na zbudowanym już obrazie, zanim Render przełączy ruch na nową wersję. Jeśli ten krok zawiedzie, stara wersja aplikacji zostaje aktywna — nowa nigdy nie dostaje ruchu z na wpół zmigrowaną bazą.

Jeśli brak `DATABASE_URL` — krok jest pomijany (np. build-only smoke test). W przeciwnym razie: `rake spree:install:migrations` (kopiuje migracje silnika do host-appa — konieczne przy każdym release'ie, bo `server/` jest świeży), potem `db:prepare`, `db:migrate`, `spree:role_users:backfill_store_ids`.

### 3. Start

`cd server && bundle exec puma -C config/puma.rb`.

## Znane ryzyko — timestampy migracji (roadmapa F1, częściowo zamknięte)

`spree:install:migrations` kopiuje migracje silnika do świeżo klonowanego `server/db/migrate`, nadając im nowe timestampy przy każdym release'ie (host-app nie ma poprzedniej kopii do porównania po nazwie). Migracja bez pełnej idempotentności (`if_not_exists`/`if_exists`) może wtedy próbować wykonać się drugi raz na bazie, która już ma tę kolumnę/indeks/tabelę — kończy się to `duplicate column`/`duplicate index` i wywaliło produkcyjny release (naprawione w `role_users`/`variants`).

Rozdzielenie builda i release'u (wyżej) **nie usuwa** tego ryzyka samo z siebie — usuwa tylko efekt uboczny "częściowo zbudowana wersja dostaje ruch". Docelowe rozwiązanie to decyzja, czy `server/` ma zostać efemeryczny na stałe, czy przejść na trwały, commitowany katalog aplikacji (wtedy migracje mają stabilne, jednorazowe timestampy jak w każdym normalnym projekcie Rails). Do tego czasu obowiązuje zasada: **każda nowa migracja w `spree/core/db/migrate` musi być idempotentna** — wszystkie migracje z bieżącej serii rozwojowej (kwiecień–czerwiec 2026, m.in. `channels`, `product_publications`, `order_approvals`, `stock_reservations`) mają już `if_not_exists`/`if_exists` jako pas bezpieczeństwa.

## Zmienne środowiskowe

Ustawiane w `render.yaml` / dashboardzie Render: `DATABASE_URL`, `REDIS_URL` (z zasobów), `SECRET_KEY_BASE` (generowane), `RAILS_ENV=production`, `CDN_HOST` (host publicznych URL-i mediów), `RAILS_SERVE_STATIC_FILES`, `SPREE_PATH=/opt/render/project/src`, `RAILS_MASTER_KEY` (ręcznie). Dane dostępowe R2 (Active Storage) — wyłącznie w dashboardzie Render.

## Rollback

Render trzyma poprzednie buildy — "Rollback" w dashboardzie przywraca poprzednią wersję **kodu**, ale nie cofa migracji bazy. Migracje piszemy więc tak, żeby stary kod działał z nowym schematem (addytywnie).

## Diagnostyka

- Logi: dashboard Render → service → Logs.
- Cold start ~18 s po ~15 min bezczynności (free tier); raz zaobserwowany OOM >512 MB przy intensywnym ruchu API.
- Zdrowie: `GET /up`.
