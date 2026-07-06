# Deep-research prompt — pełny audyt techniczny "Kakałowy Sklepik"

> Skopiuj całą treść poniżej (od linii `---`) do agenta typu deep research
> (np. z dostępem do przeglądania repozytoriów GitHub). Prompt jest napisany
> tak, by agent sam sklonował/przejrzał oba repo i wydał raport z priorytetami.

---

## Rola i cel

Jesteś starszym inżynierem audytującym gotowość produkcyjną sklepu e-commerce
zbudowanego na forku **Spree Commerce** (Rails/Ruby) z osobnym frontendem
**Next.js** i osobnym panelem admina **React/Vite**. Twoim zadaniem jest
**pełny, bezlitosny audyt techniczny** — nie tylko "co jest zepsute teraz",
ale **co jest architektonicznie kruche** i grozi kolejnymi kaskadowymi awariami.
Właściciel wprost NIE ufa, że kod jest dopracowany — potwierdź lub obal to
dowodami z kodu.

## Repozytoria do przeanalizowania

1. **Backend + Admin API + React dashboard** (monorepo):
   `https://github.com/pawelekbyra/sklepik` (branch `main`)
   - `spree/core`, `spree/api`, `spree/admin` — silniki Rails (Ruby)
   - `packages/dashboard`, `packages/dashboard-core`, `packages/dashboard-ui` — panel admina (React/Vite/TanStack)
   - `packages/admin-sdk`, `packages/sdk` — klienci TypeScript
   - `bin/render-build.sh`, `render.yaml` — deployment na Render
2. **Storefront** (sklep dla klientów):
   `https://github.com/pawelekbyra/sklepikFront` (branch `main`)
   - Next.js App Router, `src/app/[locale]/...`, deployment na Vercel

## Architektura (kontekst)

Trzy niezależnie wdrażane części, jeden wspólny backend:
- **Backend** — Render (Rails/Spree), baza Postgres (Neon), Redis (Upstash), pliki na Cloudflare R2.
- **Storefront** — Vercel, Next.js, łączy się przez publiczne Store API v3 (klucz `pk_...`).
- **Admin dashboard** — Vercel, React SPA, łączy się przez Admin API v3 (JWT).

Sklep jest jednorynkowy: domyślny język **polski bez prefiksu URL**, angielski pod `/en`,
jedna waluta **PLN**, jeden rynek (Market) Polska, jeden kanał (Channel) sprzedaży.

## Znane, potwierdzone problemy (użyj jako punkt wyjścia, NIE jako pełną listę)

Podczas ostatniej sesji naprawczej wystąpił łańcuch kaskadowych awarii.
Zweryfikuj każdy z tych punktów w kodzie, oceń czy naprawa jest trwała czy
tylko łatką, i **znajdź podobne wzorce w innych miejscach**:

1. **Migracje silników Spree nie są trwałe między deployami.** `bin/render-build.sh`
   klonuje `spree-starter` do `server/` od nowa przy każdym buildzie i kopiuje
   migracje pod nowymi znacznikami czasu → `schema_migrations` ich nie rozpoznaje →
   ryzyko ponownego uruchomienia i crashu `PG::DuplicateColumn`. Obecne zabezpieczenie
   to `if_not_exists` na migracjach (defensywne, nie docelowe). **Zbadaj: czy WSZYSTKIE
   migracje w `spree/core/db/migrate` są idempotentne? Jakie jest właściwe docelowe
   rozwiązanie (trwały `server/`? osobny krok migracji poza buildem)?**

2. **Silne, ukryte sprzężenie: waluta ↔ język ↔ widoczność produktu.** Zmiana
   domyślnego rynku (Market) po cichu zepsuła: (a) nazwy produktów (fallback tłumaczeń
   Mobility, gdy język przestaje być "supported"), (b) ceny (Prices są per-waluta),
   (c) widoczność katalogu (wymaga `available_on` W przeszłości ORAZ `ProductPublication`
   wiążącego produkt z kanałem). **Zbadaj model danych Market/Channel/ProductPublication/
   Mobility/Price. Ile warunków musi być spełnionych, żeby produkt był "widoczny i
   poprawny" na Store API? Czy istnieje JAKAKOLWIEK walidacja/ostrzeżenie, gdy jeden
   z nich jest niespełniony? Zaproponuj uproszczenie lub warstwę walidacyjną.**

3. **Bug parsowania ceny w dashboardzie.** Zapis ceny `24.99` w panelu zamienił ją
   na `24990` (podejrzenie: błąd separatora dziesiętnego przy formatowaniu PLN z przecinkiem).
   **Znajdź w `packages/dashboard` / `packages/dashboard-core` cały tor zapisu ceny
   (formularz → walidacja Zod → mapowanie → Admin SDK → API). Wskaż dokładną linię,
   gdzie `24.99` może się zamienić w `24990`. Sprawdź czy ten sam wzorzec dotyczy innych
   pól liczbowych (waga, wymiary, stan magazynowy).**

4. **Dashboard nie pokazuje błędów API.** Odpowiedź 500 renderuje się jako wieczne
   szkielety (skeleton), nie jako komunikat błędu. **Zbadaj hooki zapytań (TanStack Query)
   i komponenty stron: czy jest globalna obsługa błędów? Zaproponuj wzorzec, w którym
   błąd API zawsze coś pokazuje użytkownikowi.**

5. **Wielowarstwowy cache na storefroncie.** Next.js `"use cache"` (`cacheLife`) +
   Vercel edge cache powodują, że poprawione dane są niewidoczne 10–15 min.
   **Zbadaj `src/lib/data/*.ts` w storefroncie: strategia cache, tagi, brak
   rewalidacji na żądanie (`revalidateTag`/`revalidatePath`). Czy da się dodać
   sensowną inwalidację (np. webhook z backendu przy zmianie produktu)?**

6. **Pętla przeładowań i18n (naprawiona, ale zbadaj wzorzec).** `reconcileStoreDefaultLocale`
   w `packages/dashboard-core/src/lib/i18n.ts` porównywał się z żywym stanem i18next
   zamiast z localStorage. **Poszukaj innych miejsc, gdzie logika porównuje się z
   niestabilnym stanem runtime i może się zapętlić w `window.location.reload`.**

## Zakres audytu — przeanalizuj WSZYSTKO poniżej

### A. Poprawność i bezpieczeństwo danych
- Idempotentność wszystkich migracji; ryzyko utraty/uszkodzenia danych.
- Miejsca konwersji liczb/walut/dat między frontendem a API (jak pkt 3).
- Spójność read/write nazw pól w API v3 (dokumentacja mówi o symetrii read/write —
  sprawdź czy jest łamana).
- Obsługa UUID/prefixed IDs — czy gdzieś rzutuje się ID na integer.

### B. Architektura i sprzężenia
- Mapa zależności: co musi być prawdą, żeby produkt się sprzedał (rynek→waluta→cena→
  kanał→publikacja→dostępność→stan magazynowy→tłumaczenie). Narysuj to i wskaż
  najbardziej kruche ogniwa.
- Czy podział na 3 deploye (backend/storefront/admin) ma spójne kontrakty API
  (typy generowane z serializerów — czy są aktualne?).

### C. Obsługa błędów i obserwowalność
- Czy backend loguje sensownie (Sentry jest w Gemfile — czy skonfigurowany?).
- Czy frontend i admin pokazują błędy użytkownikowi zamiast wisieć.
- Health checki, cold start (Render free tier), zaobserwowany crash OOM (>512MB).

### D. Deployment i konfiguracja
- `bin/render-build.sh` i `render.yaml` — krytyczna analiza (klonowanie `server/`
  co build, `BUNDLE_PATH`, brak workera Sidekiq, migracje w buildzie).
- Zmienne środowiskowe wymagane vs udokumentowane (`CDN_HOST`, `CLOUDFLARE_*`,
  `DATABASE_URL`, `REDIS_URL`, klucze API).
- Konfiguracja cache Vercel + Next.js.

### E. Testy
- Pokrycie testami krytycznych ścieżek (checkout, zmiana rynku/waluty, widoczność
  katalogu). Czego brakuje? Zaproponuj minimalny zestaw e2e, który złapałby awarie
  z ostatniej sesji.

### F. Gotowość produkcyjna (blokery przed startem)
- Płatności (Stripe/Adyen/PayPal są w Gemfile, brak skonfigurowanych kluczy).
- Strony prawne wymagane w PL (regulamin, polityka prywatności, prawo odstąpienia — RODO/Omnibus).
- Domena, plan hostingu, backup bazy.

## Format raportu (wymagany)

1. **Streszczenie wykonawcze** (5–10 zdań): czy to jest gotowe do produkcji? Główne ryzyka.
2. **Tabela findings** posortowana wg priorytetu: `[Krytyczny/Wysoki/Średni/Niski]` |
   Obszar | Plik:linia | Opis problemu | Konkretny scenariusz awarii | Rekomendacja.
3. **Mapa sprzężeń danych** (pkt B) — diagram/opis co-zależności produkt↔rynek↔waluta↔widoczność.
4. **Top 5 rzeczy do naprawy przed startem** z uzasadnieniem.
5. **Załącznik: użyte komendy/pliki** — dokładnie co przejrzałeś, żeby wnioski były weryfikowalne.

Bądź konkretny — cytuj pliki i linie. Nie pisz ogólników typu "popraw obsługę błędów";
wskaż plik, funkcję i zaproponuj zmianę. Jeśli coś jest dobrze zrobione, też to napisz.
