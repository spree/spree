# Server app safety checklist

## Status

Ten dokument opisuje zasady bezpiecznego wygenerowania, inspekcji i ewentualnego commitowania katalogu `server/` jako właściwej aplikacji backendowej Kakaowego Sklepiku.

To jest checklista przed technicznym PR-em. Ten dokument sam nie generuje `server/`, nie zmienia `.gitignore` i nie uruchamia deploymentu.

## Cel

Przygotować bezpieczne zasady dla następnego etapu:

```text
wygenerować server/
sprawdzić strukturę Rails/Spree
wykluczyć sekrety i lokalne pliki
ustalić minimalny diff do review
przygotować Render Root Directory = server
```

## Kontekst

Root repo `pawelekbyra/sklepik` nie jest bezpośrednio deployowalną Rails app, bo w root nie ma `Gemfile`.

Istniejące skrypty wskazują, że aplikacja backendowa powstaje w `server/`:

```text
pnpm run server:create
pnpm run server:setup
pnpm run server:dev
pnpm run server:seed
pnpm run server:load_sample_data
```

Obecnie `.gitignore` ignoruje `server/`, więc commitowanie tego katalogu wymaga osobnej, świadomej zmiany.

## Zasada główna

Nie commitować całego `server/` automatycznie.

Najpierw wygenerować, sprawdzić, odfiltrować, dopiero potem przygotować PR.

## Komendy do uruchomienia lokalnie lub w Codexie

Do wykonania w środowisku, które może uruchamiać komendy, Docker i pnpm:

```bash
pnpm install
pnpm run server:create
```

Opcjonalnie, jeśli celem jest lokalny boot:

```bash
pnpm run server:setup
```

Nie uruchamiać produkcyjnych migracji ani deployu Render z tego etapu.

## Co musi istnieć w server/

Po wygenerowaniu sprawdzić, czy istnieją:

```text
server/Gemfile
server/Gemfile.lock
server/bin/rails
server/config/application.rb
server/config/database.yml
server/config/storage.yml
server/config/routes.rb
server/config/environments/production.rb
server/docker-compose.dev.yml
```

Jeśli tych plików nie ma, nie commitować `server/` i wrócić do decyzji backend app.

## Pliki, których nie wolno commitować

Bez wyjątków nie commitować:

```text
server/.env
server/.env.*
server/config/master.key
server/config/credentials/*.key
server/tmp/**
server/log/**
server/storage/**
server/public/assets/**
server/public/packs/**
server/node_modules/**
server/vendor/bundle/**
server/.bundle/**
```

Nie commitować żadnych prawdziwych sekretów, tokenów, haseł, kluczy API, danych admina ani connection stringów.

## Pliki do szczególnego review

Przed merge dokładnie sprawdzić:

```text
server/Gemfile
server/Gemfile.lock
server/.ruby-version
server/package.json jeśli istnieje
server/Dockerfile jeśli istnieje
server/Procfile jeśli istnieje
server/config/database.yml
server/config/storage.yml
server/config/environments/production.rb
server/config/credentials.yml.enc
server/db/seeds.rb
server/docker-compose.dev.yml
```

Szczególnie uważać na `Gemfile.lock`, bo lokalny edge/dev flow może przepisywać lockfile pod `SPREE_PATH` i ścieżki hosta.

## Minimalna zmiana .gitignore

Obecnie `server/` jest ignorowany globalnie.

Następny PR może wymagać zmiany `.gitignore`, ale nie powinien po prostu usunąć ochrony bez dodania reguł bezpieczeństwa.

Preferowany kierunek:

```gitignore
# Commit the generated backend app, but never commit local secrets/runtime files.
!server/
!server/**
server/.env
server/.env.*
server/config/master.key
server/config/credentials/*.key
server/tmp/**
server/log/**
server/storage/**
server/public/assets/**
server/public/packs/**
server/node_modules/**
server/vendor/bundle/**
server/.bundle/**
```

Ten przykład trzeba dopasować do realnego `.gitignore` i struktury wygenerowanego `server/`.

## Render implications

Po bezpiecznym commitowaniu `server/` Render nie powinien budować root repo jako Rails app.

Wstępny kierunek:

```text
Root Directory: server
Runtime: Ruby albo Docker — do potwierdzenia po inspekcji server/
```

Nie używać dla backendu komend Node/PNPM wykrytych przez Render:

```text
pnpm install --frozen-lockfile; pnpm run build
yarn start
```

Nie ustawiać jeszcze custom domain ani Cloudflare DNS.

## Render config — do potwierdzenia po server/

Po wygenerowaniu `server/` trzeba dopiero ustalić:

```text
Build Command
Start Command
Pre-deploy Command
Postgres DATABASE_URL
Redis / worker command
RAILS_MASTER_KEY / SECRET_KEY_BASE
RAILS_SERVE_STATIC_FILES
storage dla mediów
admin setup
publishable key dla Store API
```

Nie dodawać finalnego `render.yaml` przed potwierdzeniem tych punktów.

## Admin i dane testowe

Jeśli generator tworzy admina albo dane sample, nie commitować żadnych danych logowania.

Jeśli potrzebne są seedy produktów, powinny być opisane osobnym, jawnie reviewowanym PR-em.

## Publishable key

Frontend będzie potrzebował:

```text
SPREE_PUBLISHABLE_KEY
```

wysyłanego jako:

```text
X-Spree-Api-Key
```

Ale prawdziwy key nie może trafić do repo.

W dokumentacji wolno używać tylko placeholderów:

```text
SPREE_PUBLISHABLE_KEY=<render/staging publishable key>
```

## Przed PR-em technicznym

Przed otwarciem PR z `server/` autor musi wypisać w opisie PR:

```text
jak wygenerowano server/
czy server ma Gemfile
czy server ma bin/rails
czy server bootuje lokalnie albo dlaczego nie sprawdzono
jakie pliki zostały świadomie wykluczone
czy .env/master.key/sekrety nie są w diffie
czy Render ma używać Root Directory = server
czy Runtime ma być Ruby czy Docker
co pozostaje do ustalenia
```

## Checklist reviewera

Reviewer powinien sprawdzić:

```text
czy PR nie zawiera sekretów
czy PR nie zawiera server/.env
czy PR nie zawiera master.key
czy PR nie zawiera lokalnych logów/tmp/storage
czy server/Gemfile istnieje
czy server/bin/rails istnieje
czy config/database.yml nie ma produkcyjnych sekretów
czy config/storage.yml nie zakłada local storage jako produkcji
czy Gemfile.lock nie ma absolutnych ścieżek hosta
czy .gitignore chroni runtime files
czy PR nie zmienia Store API bez decyzji
czy PR nie implementuje koszyka/checkoutu przy okazji
```

## Czego nie robić

Nie robić:

```text
generowania server/ bez review diffu
commitowania całego katalogu bez filtrowania
commitowania sekretów
commitowania lokalnych danych
odpalania Render deploy z root repo
ustawiania custom domain przed działającym backendem
dodawania SPREE_API_URL do frontu przed backend URL
implementowania koszyka
implementowania checkoutu
zmian core Spree przy okazji
```

## Następny krok

Następny techniczny PR powinien wygenerować `server/`, przedstawić pełny diff do review i zastosować tę checklistę.

Dopiero po zatwierdzeniu struktury `server/` wracamy do Render i ustawiamy backend z właściwym Root Directory.
