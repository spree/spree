# Backend app decision

## Status

Ten dokument zapisuje decyzję roboczą dotyczącą tego, czym ma być deployowalny backend Kakaowego Sklepiku w repo `pawelekbyra/sklepik`.

To jest dokument decyzyjny, nie finalna konfiguracja produkcyjna.

Na obecnym etapie nie generujemy ani nie commitujemy katalogu `server`. Najpierw zapisujemy fakty i rekomendację.

## Problem

Pierwsza próba deployu backendu na Renderze uruchomiła `bundle install` w katalogu głównym repo i zakończyła się błędem:

```text
Could not locate Gemfile
```

To potwierdza, że root repo nie jest zwykłą, bezpośrednio deployowalną aplikacją Rails.

Root repo ma `package.json` z workflow `pnpm` / `turbo` i skryptami `server:*`. Najważniejszy skrypt:

```text
server:create
→ git clone --depth 1 https://github.com/spree/spree-starter.git server
→ usuwa server/.git oraz server/.gitignore
→ zapisuje server/.env z SPREE_PATH=.. i SECRET_KEY_BASE
```

Skrypt setupu `scripts/server-setup.sh` potwierdza, że lokalny backend dev jest tworzony w `./server`, a następnie uruchamiany jako edge/dev stack z Docker Compose, workerem i webem.

W `.gitignore` katalog `server/` jest obecnie ignorowany.

Wniosek: obecne repo jest workspace / źródłem Spree + narzędziowym wrapperem, a właściwa aplikacja backendowa sklepu powstaje przez `spree-starter` w katalogu `server`.

## Dostępne warianty

Mamy trzy realne warianty:

```text
A. official spree-starter jako osobna aplikacja
B. commitowany server app w tym repo
C. Docker dla właściwej aplikacji backendowej
```

## Wariant A: official spree-starter

W tym wariancie deployujemy oficjalny `spree-starter` albo osobne repo utworzone na jego bazie.

Plusy:

```text
najprostsza ścieżka do deployowalnej aplikacji Rails
mniej tarcia z root repo
zgodność z oficjalnym kierunkiem Spree startera
łatwiej użyć Render Ruby runtime albo oficjalnego flow startera
```

Minusy:

```text
backend Kakaowego Sklepiku rozjeżdża się z repo sklepik
trzeba zdecydować, gdzie zapisujemy decyzje backendowe
trzeba utrzymać relację między source/engine repo a app repo
większe ryzyko chaosu przy zmianach API, admina, checkoutu i płatności
```

Ten wariant może być dobry do szybkiego eksperymentu, ale słabiej pasuje do decyzji, że `pawelekbyra/sklepik` jest backendowym źródłem prawdy projektu.

## Wariant B: committed server app

W tym wariancie generujemy aplikację przez istniejące workflow:

```bash
pnpm run server:create
pnpm run server:setup
```

Następnie świadomie przestajemy traktować `server/` jako wyłącznie lokalny artifact i robimy z niego właściwą aplikację backendową Kakaowego Sklepiku.

Wymaga to osobnej decyzji i zmiany `.gitignore`, bo obecnie `server/` jest ignorowany.

Plusy:

```text
sklepik pozostaje jednym backendowym repo projektu
admin, Store API, seedy, konfiguracja i decyzje backendowe są w jednym miejscu
Render może deployować Root Directory = server
frontend KakaowySklepikFront ma jasne źródło backendu
łatwiej dokumentować decyzje w docs/engine-decisions.md i docs/admin-access.md
```

Minusy:

```text
repo stanie się większe
trzeba pilnować, żeby nie commitować sekretów z server/.env
trzeba rozwiązać aktualizacje ze spree-startera
trzeba uważać na lockfile i SPREE_PATH, bo obecny dev edge flow może przepisywać Gemfile.lock
```

To jest preferowany kierunek, jeśli chcemy, aby `pawelekbyra/sklepik` było faktycznym backendem sklepu, a nie tylko źródłem/monorepo Spree.

## Wariant C: Docker

W tym wariancie deployujemy backend przez Docker.

Plusy:

```text
większa powtarzalność środowiska
większa kontrola nad dependencies
łatwiej ujednolicić web i worker
```

Minusy:

```text
więcej DevOps
wciąż trzeba mieć właściwą aplikację backendową, najpewniej w server/
nie rozwiązuje samo z siebie problemu braku Gemfile w root
trzeba potwierdzić Dockerfile i production command dla backendu
```

Docker może być później dobrym wariantem, ale nie powinien być pierwszą próbą ratowania błędnie ustawionego Render Web Service.

## Rekomendacja

Rekomendowany kierunek roboczy:

```text
Wariant B: wygenerowany i commitowany katalog server jako właściwa aplikacja backendowa Kakaowego Sklepiku.
```

Uzasadnienie:

```text
sklepik ma być backendowym źródłem prawdy commerce,
Spree Admin należy do backendu sklepik,
Store API dla frontu powinno pochodzić z tego repo,
Render może później użyć Root Directory = server,
decyzje o API/cart/checkout/payment pozostają w jednym miejscu,
unikamy tworzenia osobnego, nieudokumentowanego backend app repo.
```

Ta rekomendacja nie oznacza jeszcze, że należy natychmiast commitować `server/`. Najpierw trzeba wykonać osobny PR, który wygeneruje `server`, usunie z niego sekrety i potwierdzi, że zawiera deployowalną aplikację Rails.

## Dlaczego

Projekt ma już jasny podział:

```text
KakaowySklepikFront
→ storefront klientów

sklepik
→ Spree backend, admin, Store API, produkty, zamówienia, płatności
```

Jeśli backend app mieszka poza `sklepik`, ten podział zaczyna się rozmywać.

Commitowany `server/` jest bardziej przewidywalny dla agentów, dokumentacji i deploymentu niż dynamiczne generowanie backendu w Render buildzie.

Dynamiczne generowanie `server/` podczas builda Render przez `pnpm run server:create` jest ryzykowne, bo:

```text
build zależy od zewnętrznego repo spree-starter w czasie deployu,
trudniej śledzić zmiany backend app,
trudniej reviewować zmiany admina/API,
sekrety i lockfile mogą powstawać w niekontrolowanym momencie,
Render build nie powinien być miejscem podejmowania decyzji architektonicznych.
```

## Konsekwencje dla Render

Po przyjęciu wariantu B Render powinien celować w aplikację Rails w katalogu `server`:

```text
Root Directory: server
Runtime: Ruby albo Docker — do potwierdzenia po wygenerowaniu server
```

Nie należy deployować root repo jako Ruby app.

Nie należy używać rootowych komend Node/PNPM jako finalnych backend commands:

```text
pnpm install --frozen-lockfile; pnpm run build
yarn start
```

Po wygenerowaniu i commitowaniu `server/` trzeba osobno potwierdzić:

```text
Build Command
Start Command
Pre-deploy migrations
Postgres DATABASE_URL
Redis / worker
assets precompile
storage
admin setup
publishable key
```

## Konsekwencje dla repo

Wariant B wymaga osobnego PR, który:

```text
wygeneruje server/ z użyciem istniejącego server:create/server:setup flow albo kontrolowanego odpowiednika,
sprawdzi, czy server zawiera Gemfile i bin/rails,
usunie lub wykluczy sekrety,
zmieni .gitignore tak, żeby commitować właściwe pliki server/,
nie commitnie server/.env,
nie commitnie master.key,
nie commitnie lokalnych logów/tmp/storage,
udokumentuje, które pliki server/ są źródłem prawdy.
```

Przed commitem trzeba szczególnie sprawdzić:

```text
server/.env
server/config/master.key
server/log
server/tmp
server/storage
server/public/assets
server/Gemfile.lock
```

## Konsekwencje dla przyszłych zmian Spree

Commitowany `server/` oznacza, że trzeba świadomie zarządzać aktualizacjami ze Spree startera.

Nie należy później bezrefleksyjnie nadpisywać `server/` przez ponowne `server:create`, bo to może skasować lokalne decyzje projektu.

Po przyjęciu wariantu B trzeba traktować `server/` jako aplikację sklepu, a nie jako jednorazowy artifact.

Zmiany backendowe powinny nadal być dokumentowane w:

```text
docs/engine-decisions.md
docs/admin-access.md
docs/render-deployment-readiness.md
```

## Czego nie robić

Na tym etapie nie należy:

```text
klikać kolejnych deployów Render z root repo i bundle install,
commitować server/ bez osobnego review,
commitować sekretów,
commitować master.key,
commitować prawdziwych danych admina,
tworzyć render.yaml bez potwierdzonej aplikacji server,
zmieniać Store API pod wygodę frontu,
zmieniać core Spree bez decyzji,
implementować koszyka,
implementować checkoutu.
```

## Następny krok

Następny PR powinien być techniczno-weryfikacyjny, ale nadal ostrożny:

```text
wygenerować server/ lokalnie,
sprawdzić jego strukturę,
potwierdzić Gemfile/bin/rails/config,
przygotować bezpieczną zmianę .gitignore,
nie commitować sekretów,
udokumentować minimalną konfigurację Render dla Root Directory = server.
```

Dopiero po tym można wrócić do panelu Render i konfigurować backend z właściwym Root Directory oraz komendami Rails/Docker.
