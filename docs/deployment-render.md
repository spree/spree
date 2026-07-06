# Deployment backendu na Render

Opis **faktycznego** zachowania deployu. Jeśli zmieniasz `render.yaml` albo `bin/render-build.sh`, zaktualizuj ten plik w tym samym commicie.

## Zasoby (Blueprint `render.yaml`)

| Zasób | Nazwa | Uwagi |
|---|---|---|
| Web service | `kakaowy-sklepik-backend` | Ruby, Frankfurt, health check `/up`, `plan: starter` w blueprint (żywy serwis zachowywał się jak free — cold start; zweryfikować zgodność) |
| Postgres | `kakaowy-sklepik-db` | plan free |
| Redis | `kakaowy-sklepik-redis` | plan free |
| Worker Sidekiq | — | zakomentowany; wymaga płatnego planu (roadmapa F7) |

Adres: `https://kakaowy-sklepik.onrender.com`.

## Jak działa build (`bin/render-build.sh`)

1. Klonuje świeży `spree/spree-starter` do `server/` (przez `server.next`, stary katalog odsuwa na bok) — `server/` jest **efemeryczny**, odtwarzany przy każdym buildzie.
2. Wymusza Ruby `3.4.4` (upstream pinuje 4.0.1, co wywala instalator Rendera).
3. Zapisuje `SPREE_PATH` do `server/.env` → bundler bierze gemy **z tego forka** (`spree/core`, `spree/api`, …), nie z RubyGems. Bez tego zmiany z repo nie trafiają na produkcję.
4. `bundle lock/install/check` (z `BUNDLE_IGNORE_CONFIG=1`), `assets:precompile` (z `SECRET_KEY_BASE_DUMMY=1`).
5. Jeśli jest `DATABASE_URL`: `rake spree:install:migrations` (kopiuje migracje silnika do host-appa — konieczne przy każdym buildzie, bo `server/` jest świeży), potem `db:prepare`, `db:migrate`, `spree:role_users:backfill_store_ids`.

Start: `cd server && bundle exec puma -C config/puma.rb`.

## Znane ryzyko (P0 w roadmapie — F1)

Migracje wykonują się **w kroku builda**, a kopiowanie do świeżego `server/` nadaje im nowe timestampy przy każdym deployu. Migracja bez pełnej idempotentności (`if_not_exists`/`if_exists`) może wywalić produkcyjny build (`duplicate column`) — już się zdarzyło (naprawione punktowo w `role_users`/`variants`). Docelowo migracje mają wyjść z `buildCommand` do osobnej fazy release. Do tego czasu: **każda nowa migracja w `spree/core/db/migrate` musi być idempotentna.**

## Zmienne środowiskowe

Ustawiane w `render.yaml` / dashboardzie Render: `DATABASE_URL`, `REDIS_URL` (z zasobów), `SECRET_KEY_BASE` (generowane), `RAILS_ENV=production`, `CDN_HOST` (host publicznych URL-i mediów), `RAILS_SERVE_STATIC_FILES`, `SPREE_PATH=/opt/render/project/src`, `RAILS_MASTER_KEY` (ręcznie). Dane dostępowe R2 (Active Storage) — wyłącznie w dashboardzie Render.

## Rollback

Render trzyma poprzednie buildy — "Rollback" w dashboardzie przywraca poprzednią wersję **kodu**, ale nie cofa migracji bazy. Migracje piszemy więc tak, żeby stary kod działał z nowym schematem (addytywnie).

## Diagnostyka

- Logi: dashboard Render → service → Logs.
- Cold start ~18 s po ~15 min bezczynności (free tier); raz zaobserwowany OOM >512 MB przy intensywnym ruchu API.
- Zdrowie: `GET /up`.
