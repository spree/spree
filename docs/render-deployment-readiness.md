# Render deployment readiness

## Status

Ten dokument opisuje aktualny stan przygotowania repozytorium `pawelekbyra/sklepik` do deploymentu backendu Spree na Renderze.

To jest dokument audytowy. Nie przesądza jeszcze finalnej konfiguracji produkcyjnej.

Na tym etapie celem jest ustalić, dlaczego pierwszy build na Renderze się nie udał i jak bezpiecznie przygotować backend do środowiska dev/staging, zanim frontend `KakaowySklepikFront` zacznie używać `SPREE_API_URL`.

## Obecny błąd Render

Pierwsza próba deployu zakończyła się błędem:

```text
Running build command 'bundle install'...
Could not locate Gemfile
Build failed
```

Render odpalił `bundle install` w katalogu głównym repozytorium, ale w root repo nie ma `Gemfile`.

Wniosek: problem nie polega na samej wersji Ruby, tylko na tym, że Render buduje niewłaściwy katalog albo repo nie jest bezpośrednio deployowalną aplikacją Rails z katalogu głównego.

## Struktura repo

Root repo zawiera `package.json` z workflow opartym o `pnpm`, `turbo` i Spree CLI.

Istotne skrypty z root `package.json`:

```text
server:create
server:setup
server:dev
server:build
server:restart
server:stop
server:console
server:logs
server:seed
server:load_sample_data
```

Najważniejszy sygnał:

```text
server:create
→ klonuje https://github.com/spree/spree-starter.git do katalogu server
```

Oznacza to, że backend Rails/Spree może być tworzony jako aplikacja w katalogu `server`, a nie istnieć bezpośrednio w root repo.

## Czy root repo jest deployowalne?

Na podstawie obecnego błędu Render i struktury `package.json` root repo nie powinno być traktowane jako bezpośrednio deployowalna aplikacja Rails.

Root repo wygląda bardziej jak:

```text
Spree source / workspace / narzędziowy wrapper
+
skrypty do utworzenia i obsługi aplikacji server
```

Nie należy uruchamiać w root repo:

```bash
bundle install
```

jeżeli root nie zawiera `Gemfile`.

## Katalog server

Katalog `server` jest kluczowy dla decyzji deploymentowej.

Do potwierdzenia:

```text
czy katalog server istnieje lokalnie po uruchomieniu pnpm run server:create
czy katalog server jest commitowany do repo
czy server zawiera Gemfile
czy server zawiera bin/rails
czy server zawiera config/database.yml
czy server zawiera Dockerfile albo Procfile
```

Jeżeli `server` jest właściwą aplikacją Rails, Render powinien używać:

```text
Root Directory: server
```

ale tylko jeśli katalog `server` jest commitowany do repo albo build potrafi go powtarzalnie wygenerować.

## Rekomendowany wariant deployu

Na obecnym etapie nie należy kontynuować deployu root repo jako Ruby app.

Są trzy możliwe warianty:

### Wariant A — oficjalny Spree Starter na Render

Użyć oficjalnego `spree-starter` jako deployowalnej aplikacji Rails.

Plusy:

```text
najprostsza ścieżka do działającego backendu
zgodna z kierunkiem Spree starter
mniej walki z root repo
```

Minusy:

```text
trzeba zdecydować, jak połączyć to z naszym repo sklepik
może wymagać osobnego repo backend app albo przeniesienia wygenerowanego server
```

### Wariant B — commitowany katalog server

Wygenerować aplikację przez:

```bash
pnpm run server:create
pnpm run server:setup
```

a następnie potraktować `server` jako właściwą aplikację backendową.

Plusy:

```text
mamy własny backend app w repo
Render może użyć Root Directory = server
łatwiej mapować admin/API na nasze repo
```

Minusy:

```text
trzeba świadomie zdecydować, czy commitujemy wygenerowany server
trzeba pilnować aktualizacji Spree startera
repo może stać się cięższe
```

### Wariant C — Docker

Deploy przez Docker może być dobry, jeśli istnieje stabilny Dockerfile dla aplikacji backendowej.

Plusy:

```text
większa powtarzalność środowiska
łatwiej kontrolować system dependencies
```

Minusy:

```text
więcej DevOps
trzeba mieć właściwy Dockerfile dla server/backendu
nie rozwiązuje problemu braku aplikacji Rails w root
```

## Render Web Service

Nie używać konfiguracji wykrytej przez Render jako Node/PNPM frontend:

```text
Build Command:
pnpm install --frozen-lockfile; pnpm run build

Start Command:
yarn start
```

Te komendy nie są właściwe dla backendu `sklepik`.

Dla backendu Spree Render Web Service powinien docelowo wskazywać na właściwą aplikację Rails, prawdopodobnie przez:

```text
Root Directory: server
Runtime: Ruby
```

albo:

```text
Runtime: Docker
```

jeśli zostanie wybrany wariant kontenerowy.

## Render Postgres

Backend Spree będzie wymagał bazy PostgreSQL.

Do ustalenia:

```text
czy aplikacja używa DATABASE_URL
czy config/database.yml poprawnie obsługuje DATABASE_URL w production
czy potrzebne są dodatkowe rozszerzenia Postgres
czy migracje uruchamiamy przez pre-deploy command
```

Na Renderze docelowo powinien powstać osobny Postgres service.

## Render Redis / worker

Backend commerce zwykle potrzebuje osobnego mechanizmu jobów/cache.

Do ustalenia:

```text
czy Spree app używa Sidekiq
czy potrzebny jest Redis albo Render Key Value
jaka jest komenda worker service
czy worker powinien być osobnym Render Background Worker
```

Nie uruchamiać jeszcze workerów produkcyjnych bez potwierdzenia konfiguracji.

## Env vars

Prawdopodobne zmienne dla środowiska production/staging:

```text
RAILS_ENV=production
RAILS_MASTER_KEY
SECRET_KEY_BASE
DATABASE_URL
RAILS_SERVE_STATIC_FILES=true
REDIS_URL albo odpowiednik Render Key Value
```

Do potwierdzenia przez realny plik `server/config` i dokumentację aplikacji.

Nie commitować sekretów.

Nie commitować `master.key`.

Nie wpisywać prawdziwych kluczy w dokumentacji.

## Build command

Nie ma jeszcze zatwierdzonej komendy build.

Jeżeli wybierzemy Ruby runtime i `Root Directory: server`, prawdopodobny kierunek to komenda typu:

```bash
bundle install && bundle exec rails assets:precompile
```

ale należy ją potwierdzić względem realnego `server/Gemfile`, asset pipeline i konfiguracji Spree startera.

Jeżeli wybierzemy Docker, build command będzie wynikał z Dockerfile.

Nie należy używać `bundle install` w root repo bez `Gemfile`.

## Start command

Nie ma jeszcze zatwierdzonej komendy start.

Dla Ruby runtime i aplikacji Rails prawdopodobny kierunek to:

```bash
bundle exec rails server -b 0.0.0.0 -p $PORT
```

ale należy to potwierdzić po ustaleniu, gdzie znajduje się właściwa aplikacja Rails.

Nie używać:

```bash
yarn start
```

jako start command dla backendu Spree.

## Pre-deploy migrations

Po wybraniu właściwej aplikacji Rails trzeba ustalić pre-deploy command dla migracji, prawdopodobnie:

```bash
bundle exec rails db:migrate
```

Migracji produkcyjnych nie należy odpalać, dopóki nie ma poprawnie skonfigurowanej bazy i env vars.

## Assets

Do ustalenia:

```text
czy admin Spree wymaga assets:precompile
czy aplikacja używa Propshaft/Sprockets/Vite/innego pipeline
czy RAILS_SERVE_STATIC_FILES=true wystarczy na Renderze
```

## Storage / media

Na produkcji nie należy polegać na lokalnym ephemeral filesystem dla zdjęć produktów.

Do rozważenia:

```text
S3-compatible storage
Cloudflare R2
AWS S3
```

Na obecnym etapie nie konfigurujemy jeszcze storage. Trzeba najpierw potwierdzić, jak `server/config/storage.yml` jest ustawiony.

## Admin setup

Do ustalenia:

```text
jak tworzymy konto admina
czy istnieje seed/setup task
czy można użyć Spree CLI
czy dane admina powinny być tworzone ręcznie w konsoli albo przez jednorazowy task
```

Nie commitować loginów, haseł ani tokenów.

## Publishable key

Frontend `KakaowySklepikFront` będzie potrzebował publishable key do Store API jako:

```text
SPREE_PUBLISHABLE_KEY
```

wysyłany do backendu jako:

```text
X-Spree-Api-Key
```

Do ustalenia:

```text
jak wygenerować publishable key w Spree Admin albo przez task/API
czy publiczna lista produktów wymaga tego nagłówka
czy key ma być osobny dla dev/staging/production
```

Nie commitować prawdziwych kluczy.

## Free plan vs production

Aktualnie wybrano darmowy plan Render tylko do rozpoznania konfiguracji.

Darmowy plan może wystarczyć do krótkiego eksperymentu, ale nie jest docelowy dla backendu sklepu, ponieważ backend commerce powinien mieć stabilną dostępność dla:

```text
Store API
Spree Admin
checkoutu
webhooków płatności
background jobs
połączeń z bazą
```

Docelowo backend powinien działać na płatnym planie, jeśli Render zostanie utrzymany jako hosting.

## Czego nie robić

Na tym etapie nie należy:

```text
kontynuować deployu root repo jako Ruby app z bundle install
używać komend pnpm/yarn jako finalnego backend start command
dodawać custom domain
podpinać Cloudflare DNS
wklejać sekretów do GitHuba
commitować master.key
dodawać SPREE_API_URL do frontu bez działającego backendu
zmieniać Store API pod wygodę frontu
zmieniać core Spree bez decyzji w docs/engine-decisions.md
implementować koszyka
implementować checkoutu
```

## Następny krok

Najlepszy następny krok to ustalić, czy pracujemy wariantem:

```text
A. oficjalny spree-starter jako osobna deployowalna aplikacja,
B. commitowany katalog server w tym repo,
C. Docker dla właściwej aplikacji backendowej.
```

Dopiero po tej decyzji można wrócić do panelu Render i ustawić:

```text
Root Directory
Runtime
Build Command
Start Command
Pre-deploy Command
Postgres
Redis / worker
Env vars
```

Po działającym backendzie wracamy do runtime validation adaptera `KakaowySklepikFront/lib/spree`.
