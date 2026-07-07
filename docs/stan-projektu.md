# Stan projektu

**Żywy dokument.** Każdy agent po zakończeniu zadania aktualizuje ten plik tak, żeby odzwierciedlał rzeczywisty, bieżący stan systemu — nie dopisuje kolejnych wpisów dziennika, tylko poprawia treść. Historia jest w gicie.

Ostatnia aktualizacja: 2026-07-07 (F4: webhook produktowy skonfigurowany i aktywny na produkcji — 7 eventów `product.*` rewalidują cache storefrontu).

## Co działa

- **Backend na Render** (`kakaowy-sklepik.onrender.com`) buduje się i działa: gemy z tego forka (`SPREE_PATH`), migracje silnika przeniesione do `preDeployCommand`, wszystkie idempotentne (`if_not_exists`), baza zseedowana.
- **Panel admina** (`sklepik-gamma.vercel.app`) działa end-to-end: logowanie JWT przez single-origin proxy, zarządzanie produktami. Wpisy cen kanoniczny format `"1234.56"` niezależnie od locale.
- **Storefront** (`sklepikkk.vercel.app`) działa: rebranding "Kakałowy Sklepik", polski domyślny locale bez prefiksu URL, katalog i strony produktów renderują się z danych Store API. Wymaga `SPREE_API_URL` + `SPREE_PUBLISHABLE_KEY` ustawionych jako zmienne środowiskowe Vercel produkcyjnie — bez nich `isSpreeConfigured()` po cichu zwraca puste odpowiedzi (żadnego błędu, katalog wygląda po prostu na pusty; to właśnie się stało i kosztowało długie dochodzenie, zanim się okazało że przyczyną nie był cache).
- **Dane:** jeden rynek Polska/PLN/pl (7 demo-rynków usuniętych), 6 produktów kakao zseedowanych przez Admin API, ceny w PLN, media na R2.
- **Walidacja produktu:** endpoint `/api/v3/admin/products/:id/readiness` sprawdza status, publikację, ceny, stock, tłumaczenia; dashboard może pokazać ostrzeżenia.
- Testy storefrontu zielone (build + 89 testów vitest na moment rebrandingu).

## Znane problemy (aktualne)

Uporządkowane wg wagi — szczegóły i plan naprawy w [`roadmap.md`](roadmap.md):

1. **Dashboard nie pokazuje błędów API (P1):** 500 z backendu = wieczne skeletony zamiast komunikatu (`resource-table.tsx` ignoruje `error`/`isError`).
2. **Cache storefrontu — inwalidacja produktów działa przez webhook, cena/rynek nie zweryfikowane (P1, częściowo zamknięte, F4):** `Spree::Product` publikuje `product.created`/`updated`/`deleted`/`activated`/`archived`/`out_of_stock`/`back_in_stock` (nie wymagało zmian w backendzie), `sklepikFront`'s `/api/webhooks/spree` obsługuje wszystkie siedem jednym handlerem i busuje cache w sekundach. **Skonfigurowane i aktywne na produkcji** — w adminie (Ustawienia → Webhooks) endpoint na `{storefront}/api/webhooks/spree` ma te siedem eventów w subskrypcji. Nie zweryfikowano, czy edycja samej ceny (`Spree::Price`, bez zmiany innego pola produktu) niezawodnie odpala `product.updated` przez łańcuch `touch: true` (Price → Variant → Product). Ręczny wentyl nadal istnieje: `POST /api/revalidate` (sklepikFront) z `Authorization: Bearer $REVALIDATE_SECRET`. **Uwaga diagnostyczna:** pusty katalog na storefroncie bywa mylony z tym problemem, ale częściej to zupełnie inna przyczyna — patrz punkt 8.
3. **Idempotencja webhooków e-mail w pamięci procesu (P1):** `Set` w `handlers.ts` — restart instancji = możliwy duplikat e-maila.
4. **Worker Sidekiq wyłączony (P2):** zakomentowany w `render.yaml` — jeden proces web dźwiga wszystko; wymaga płatnego planu. Konkretny skutek: warianty zdjęć (Active Storage) generują się leniwie na pierwsze żądanie zamiast w tle przy uploadzie — zmierzone 12.5s na zimnym cache dla wariantu `xlarge` (2000×2000), 1.3s scache'owane; potrafiło to przekroczyć timeout Vercel Image Optimization i zostawić brak zdjęcia na stronie produktu (mitygacja frontowa: `sklepikFront` woli teraz `large` 720×720 jako główne zdjęcie galerii, `sklepikFront/docs/technical-debt.md` 2026-07-07).
5. **Render free/starter (P2):** cold start ~18 s po bezczynności; OOM (>512 MB) zaobserwowany **dwukrotnie** przy ciężkim ruchu API (drugi raz: 2026-07-07 15:03, ~14 min po zielonym deployu — instancja padła, Render sam podniósł nową ("Service recovered"), żadnych danych nie stracono). Starter ($7/mo) ma ten sam limit 512 MB co free — nie rozwiązuje OOM, tylko cold start. **Świadomie odłożone** (F8): zostajemy na obecnym planie do startu realnej sprzedaży, wtedy przejście na Render Standard (2 GB, ~$25/mo) jest natychmiastowe.
6. **Vercel `sklepik_back` quirk (P2):** webhook potrafi nie łapać pushy; pomaga ręczny Redeploy w UI.
7. **Store name bez tłumaczenia `pl` (P1, przyczyna crasha panelu po loginie — kod naprawiony, dane nie):** `Spree::Store#name` jest tłumaczone przez Mobility, ale wpisane tylko pod `en` ("Shop"). Panel pyta API bez jawnego `locale`, więc dostaje `name: null` pod domyślnym `pl` — `StoreSwitcher` się na tym wywalał (`store.name.split(...)` bez zabezpieczenia), zabierając cały panel do `RouteErrorBoundary`. Kod naprawiony (`getInitials`, PR #15, zmergowany), ale **dane wciąż nie są uzupełnione** — pasek boczny pokazuje fallback (ID sklepu) zamiast prawdziwej nazwy, dopóki ktoś nie ustawi `name` sklepu pod `pl` (przez Admin API: `PATCH /api/v3/admin/store?locale=pl`, analogicznie jak zrobiono to dla 5 z 6 produktów kakao).
8. **`SPREE_API_URL`/`SPREE_PUBLISHABLE_KEY` brakowały na Vercel dla `sklepik_front` (naprawione, ustawione ręcznie):** storefront nigdy się nie łączył z backendem — `isSpreeConfigured()` po cichu zwracał puste odpowiedzi (żaden błąd w logach), co wielokrotnie mylono z problemem cache'a (punkt 2) lub z niepowiązanymi zmianami rynku/waluty/publikacji. **Wniosek na przyszłość:** przy "sklep pokazuje pustkę bez błędu" najpierw sprawdzić te dwie zmienne na Vercelu, zanim zacznie się podejrzewać cache czy dane.
9. **Produkty bez `product_publications` = niewidoczne (P1, ryzyko powtórki):** produkt utworzony przez Admin API bez jawnego powiązania z kanałem (`product_publications`) jest niewidoczny na Store API mimo `status: active`, `available_on` w przeszłości i towaru na stanie. `Spree::Products::ReadinessCheck` (F3) to teraz wykrywa, ale nic go automatycznie nie wywołuje przy tworzeniu produktu przez API — łatwo to przeoczyć przy każdym kolejnym ręcznym seedowaniu danych.
10. **Przełącznik waluty/kraju w dashboardzie panelu pusty (P2, zgłoszone, niezbadane):** po usunięciu 6 z 7 demo-rynków (patrz "Co działa") lista krajów/walut do wyboru w UI panelu jest pusta lub niekompletna (widać PLN/USD, ale nie da się wybrać). Prawdopodobnie UI zakłada wiele Marketów/krajów i nie ma dobrej ścieżki dla store z jednym rynkiem — wymaga sprawdzenia komponentu przełącznika kraju/waluty w `packages/dashboard`.
11. **Logo sklepu bez UI i bez konsumenta (P2, F10):** `Store#logo`/`logo_url` istnieje w API, ale panel nie ma pola do wgrania (tylko `mailer_logo` w Ustawieniach → E-maile ma gotowy upload) i storefront go nie renderuje — nagłówek pokazuje samą nazwę tekstową, a SEO/JSON-LD bierze logo ze statycznego env `STORE_LOGO_URL`.
12. **Przełącznik kraju/waluty w storefroncie zepsuty (P1, F11):** `CountrySwitcher.tsx` miesza język i walutę w jednym dropdownie i buduje linki wg usuniętego schematu URL `/{country}/{locale}/...` → wybór innego kraju daje 404, plus wizualny duplikat "PL PL | PLN" (flaga-emoji nie renderuje się na części systemów). Plan pełnego rozdzielenia (Market vs Język, dwie niezależne osie): [`docs/plans/market-language-switcher.md`](plans/market-language-switcher.md).

## Czego jeszcze nie ma (przed startem sprzedaży)

- Weryfikacja, czy inwalidacja cache przy edycji samej ceny/rynku (bez zmiany pola produktu) działa niezawodnie (F4, reszta).
- Jawne stany błędów w dashboardzie (F5 — ResourceTable error handling).
- Trwała idempotencja webhooków e-mail (F6 — Redis lub Postgres trwały magazyn).
- Worker Sidekiq w tle (F7 — wymaga płatnego planu Render).
- Płatności (Stripe — gem `spree_stripe` jest w starterze, brak konfiguracji i kluczy).
- Strony prawne: regulamin, polityka prywatności, prawo odstąpienia (wymagane w PL).
- Własna domena (wszystko na `*.vercel.app` / `*.onrender.com`).
- Testy e2e łańcucha rynek → waluta → publikacja → cache (F9 — comprehensive integration tests).

## Dostępy

- Admin: `sklepik-gamma.vercel.app`, konto seedowe wg `spree/core/app/services/spree/seeds/admin_user.rb` (hasła nie trzymamy w repo). Granice admin/API/storefront: [`admin-access.md`](admin-access.md).
