# Agent handoff: Render backend deployment

## Status na koniec dnia

Ten dokument jest handoffem dla kolejnego agenta pracującego nad backendiem `pawelekbyra/sklepik` i deploymentem na Render.

Najważniejszy stan:

```text
Frontend KakaowySklepikFront
→ ma już zmergowany produktowy adapter Spree Store API v3

Backend sklepik
→ ma dokumentację kontraktu Store API v3
→ ma dokumentację Render readiness
→ ma decyzję roboczą, że docelowo deployowalny backend powinien być aplikacją server/
→ ma checklistę bezpieczeństwa przed wygenerowaniem/commitowaniem server/
```

Nie ma jeszcze działającego backend URL.

Nie ma jeszcze ustawionego `SPREE_API_URL` dla frontu.

Nie było jeszcze runtime validation frontu przeciwko działającemu backendowi.

## Co próbowaliśmy zrobić na Renderze

Celem było rozpoczęcie przygotowania backendu `pawelekbyra/sklepik` do deploymentu na Renderze.

Użytkownik:

```text
1. założył / otworzył Render,
2. połączył GitHuba,
3. wybrał repo pawelekbyra/sklepik,
4. wybrał na razie darmowy plan Render do rozpoznania konfiguracji,
5. uruchomił próbę builda.
```

Darmowy plan został wybrany tylko do rozpoznania. Nie jest traktowany jako docelowy plan produkcyjny dla backendu sklepu.

## Jaką konfigurację Render zaproponował błędnie

Render początkowo wykrył repo jako aplikację Node/PNPM i pokazywał komendy w stylu:

```text
Build Command:
pnpm install --frozen-lockfile; pnpm run build

Start Command:
yarn start
```

To nie jest właściwa konfiguracja dla backendu Spree/Rails.

`sklepik` nie powinien być deployowany jako frontend Node app ani startowany przez `yarn start`.

## Jaki build faktycznie padł

Po przełączeniu/ustawieniu próby Ruby build Render odpalił:

```text
Running build command 'bundle install'...
```

Build log:

```text
==> Cloning from https://github.com/pawelekbyra/sklepik
==> Checking out commit 88bd8e1cfa9f1aef646ece589580381bd0d6c4ee in branch main
==> Using Ruby version 3.4.4 (default)
==> Running build command 'bundle install'...
Could not locate Gemfile
==> Build failed
==> Requesting Node.js version 22
==> Using Node.js version 22.23.1 via /opt/render/project/src/.node-version
```

## Dlaczego build nie wyszedł

Build nie wyszedł, bo Render uruchomił `bundle install` w root repo, a root repo nie zawiera `Gemfile`.

To nie był zasadniczo problem wersji Ruby.

To był problem złego katalogu / złego modelu aplikacji:

```text
Render budował root repo jako Rails app
ale root repo nie jest bezpośrednią Rails app
```

Root repo ma `package.json` z workflow `pnpm` / `turbo` i skryptami `server:*`.

Najważniejszy skrypt:

```text
server:create
→ git clone --depth 1 https://github.com/spree/spree-starter.git server
→ usuwa server/.git i server/.gitignore
→ zapisuje server/.env z SPREE_PATH=.. oraz SECRET_KEY_BASE
```

Dodatkowo `.gitignore` ignoruje obecnie:

```text
server/
```

Wniosek: właściwa aplikacja backendowa Spree prawdopodobnie powstaje w katalogu `server/`, a nie w root repo.

## Dokumenty już dodane / zmergowane

W repo `pawelekbyra/sklepik` są już dokumenty porządkujące ten stan:

```text
docs/render-deployment-readiness.md
→ opisuje błąd Render, strukturę repo, warianty deployu, env vars, Postgres, Redis/worker, storage, admin, publishable key

docs/backend-app-decision.md
→ porównuje warianty: official spree-starter, committed server app, Docker
→ rekomenduje roboczo committed server app jako kierunek

docs/server-app-safety-checklist.md
→ opisuje zasady bezpiecznego wygenerowania i ewentualnego commitowania server/
→ lista plików, których nie wolno commitować
→ checklista reviewera dla przyszłego PR z server/
```

## Aktualna decyzja robocza

Rekomendowany kierunek:

```text
Wariant B: wygenerowany i commitowany katalog server/ jako właściwa aplikacja backendowa Kakaowego Sklepiku.
```

Powód:

```text
sklepik ma być backendowym źródłem prawdy commerce,
Spree Admin należy do backendu sklepik,
Store API dla frontu powinno pochodzić z tego repo,
Render będzie mógł później użyć Root Directory = server,
decyzje o API/cart/checkout/payment pozostają w jednym miejscu.
```

Ta decyzja nie oznacza jeszcze, że `server/` został wygenerowany albo że można go bezpiecznie commitować.

## Czego nie robić dalej

Nie należy teraz:

```text
kontynuować Render deployu z root repo jako Rails app,
klikać builda z bundle install w root,
używać pnpm/yarn start jako finalnego backend start command,
ustawiać custom domain,
podpinać Cloudflare DNS,
dodawać SPREE_API_URL do frontu,
commitować server/ bez inspekcji,
commitować server/.env,
commitować master.key albo credentials key,
commitować log/tmp/storage,
commitować prawdziwych danych admina,
implementować koszyka,
implementować checkoutu,
zmieniać Store API pod wygodę frontu.
```

## Następny techniczny krok dla kolejnego agenta

Następny agent powinien wykonać osobny techniczny PR, którego celem jest tylko wygenerowanie i inspekcja `server/`.

Zakres następnego PR:

```text
1. uruchomić pnpm install,
2. uruchomić pnpm run server:create,
3. sprawdzić strukturę server/,
4. potwierdzić server/Gemfile,
5. potwierdzić server/bin/rails,
6. potwierdzić server/config/database.yml,
7. potwierdzić server/config/storage.yml,
8. sprawdzić server/Gemfile.lock pod kątem absolutnych ścieżek hosta,
9. sprawdzić, jakie sekrety powstały,
10. nie commitować server/.env,
11. nie commitować master.key / credentials keys,
12. przygotować minimalną zmianę .gitignore,
13. przygotować wstępne Render notes dla Root Directory = server.
```

Ten PR nie powinien jeszcze robić produkcyjnego deployu.

## Bezpieczny kierunek .gitignore

Obecnie `server/` jest ignorowany.

Jeśli następny PR ma commitować `server/`, musi jednocześnie ochronić runtime/secrets pliki.

Kierunkowo:

```gitignore
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

To jest kierunek, nie gotowa finalna konfiguracja bez sprawdzenia wygenerowanej struktury.

## Po udanym PR z server/

Dopiero po bezpiecznym commitowaniu i review `server/` wracamy do Render.

Wtedy konfiguracja Render powinna iść w kierunku:

```text
Root Directory: server
Runtime: Ruby albo Docker — do potwierdzenia po inspekcji server/
Build Command: do potwierdzenia
Start Command: do potwierdzenia
Pre-deploy migrations: do potwierdzenia
Postgres: Render Postgres
Redis / worker: do potwierdzenia
Storage: S3/R2 do późniejszej decyzji
```

## Relacja z frontendem

Nie podpinamy frontu do backendu, dopóki backend nie działa.

`KakaowySklepikFront` ma już adapter produktów Spree API v3, ale runtime validation musi poczekać na działający backend URL oraz publishable key.

Po uruchomieniu backendu trzeba będzie sprawdzić:

```text
GET /api/v3/store/products
GET /api/v3/store/products/{slug albo prod_id}
X-Spree-Api-Key
expand=default_variant,variants,media,primary_media,option_types
media/primary_media URLs
price.currency
variants / option_values
```

## Najlepszy następny krok

Następny agent powinien zacząć od:

```text
Przeczytaj:
- docs/render-deployment-readiness.md
- docs/backend-app-decision.md
- docs/server-app-safety-checklist.md
- docs/agent-handoff-render.md

Następnie przygotuj techniczny PR generujący i inspektujący server/ zgodnie z checklistą, bez sekretów i bez deploymentu produkcyjnego.
```
