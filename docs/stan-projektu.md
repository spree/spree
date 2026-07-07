# Stan projektu

**Żywy dokument.** Każdy agent po zakończeniu zadania aktualizuje ten plik tak, żeby odzwierciedlał rzeczywisty, bieżący stan systemu — nie dopisuje kolejnych wpisów dziennika, tylko poprawia treść. Historia jest w gicie.

Ostatnia aktualizacja: 2026-07-07 (F1, F2, F3 — rozdzielenie builda od migracji, canonical number parsing, product readiness).

## Co działa

- **Backend na Render** (`kakaowy-sklepik.onrender.com`) buduje się i działa: gemy z tego forka (`SPREE_PATH`), migracje silnika przeniesione do `preDeployCommand`, wszystkie idempotentne (`if_not_exists`), baza zseedowana.
- **Panel admina** (`sklepik-gamma.vercel.app`) działa end-to-end: logowanie JWT przez single-origin proxy, zarządzanie produktami. Wpisy cen kanoniczny format `"1234.56"` niezależnie od locale.
- **Storefront** (`sklepikkk.vercel.app`) działa: rebranding "Kakałowy Sklepik", polski domyślny locale bez prefiksu URL, katalog i strony produktów renderują się z danych Store API.
- **Dane:** jeden rynek Polska/PLN/pl (7 demo-rynków usuniętych), 6 produktów kakao zseedowanych przez Admin API, ceny w PLN, media na R2.
- **Walidacja produktu:** endpoint `/api/v3/admin/products/:id/readiness` sprawdza status, publikację, ceny, stock, tłumaczenia; dashboard może pokazać ostrzeżenia.
- Testy storefrontu zielone (build + 89 testów vitest na moment rebrandingu).

## Znane problemy (aktualne)

Uporządkowane wg wagi — szczegóły i plan naprawy w [`roadmap.md`](roadmap.md):

1. **Dashboard nie pokazuje błędów API (P1):** 500 z backendu = wieczne skeletony zamiast komunikatu (`resource-table.tsx` ignoruje `error`/`isError`).
2. **Cache storefrontu bez automatycznej inwalidacji (P1):** zmiany z admina widać po 10–15 min (TTL `use cache` + edge Vercela). Jest ręczny wentyl: `POST /api/revalidate` (sklepikFront) z `Authorization: Bearer $REVALIDATE_SECRET` czyści tagi `products`/`product-filters` na żądanie — ale to obejście, docelowo powinien to wywoływać webhook z backendu przy zmianie produktu (F4).
3. **Idempotencja webhooków e-mail w pamięci procesu (P1):** `Set` w `handlers.ts` — restart instancji = możliwy duplikat e-maila.
4. **Worker Sidekiq wyłączony (P2):** zakomentowany w `render.yaml` — jeden proces web dźwiga wszystko; wymaga płatnego planu.
5. **Render free/starter (P2):** cold start ~18 s po bezczynności; raz zaobserwowany OOM (>512 MB) przy ciężkim ruchu API.
6. **Vercel `sklepik_back` quirk (P2):** webhook potrafi nie łapać pushy; pomaga ręczny Redeploy w UI.
7. **Store name bez tłumaczenia `pl` (P1, przyczyna crasha panelu po loginie — kod naprawiony, dane nie):** `Spree::Store#name` jest tłumaczone przez Mobility, ale wpisane tylko pod `en` ("Shop"). Panel pyta API bez jawnego `locale`, więc dostaje `name: null` pod domyślnym `pl` — `StoreSwitcher` się na tym wywalał (`store.name.split(...)` bez zabezpieczenia), zabierając cały panel do `RouteErrorBoundary`. Kod naprawiony (`getInitials`, PR #15, zmergowany), ale **dane wciąż nie są uzupełnione** — pasek boczny pokazuje fallback (ID sklepu) zamiast prawdziwej nazwy, dopóki ktoś nie ustawi `name` sklepu pod `pl` (przez Admin API: `PATCH /api/v3/admin/store?locale=pl`, analogicznie jak zrobiono to dla 5 z 6 produktów kakao).

## Czego jeszcze nie ma (przed startem sprzedaży)

- Czyszczenie cache w storefroncie na żądanie z backendu (F4 — webhook rewalidacyjny).
- Jawne stany błędów w dashboardzie (F5 — ResourceTable error handling).
- Trwała idempotencja webhooków e-mail (F6 — Redis lub Postgres trwały magazyn).
- Worker Sidekiq w tle (F7 — wymaga płatnego planu Render).
- Płatności (Stripe — gem `spree_stripe` jest w starterze, brak konfiguracji i kluczy).
- Strony prawne: regulamin, polityka prywatności, prawo odstąpienia (wymagane w PL).
- Własna domena (wszystko na `*.vercel.app` / `*.onrender.com`).
- Testy e2e łańcucha rynek → waluta → publikacja → cache (F9 — comprehensive integration tests).

## Dostępy

- Admin: `sklepik-gamma.vercel.app`, konto seedowe wg `spree/core/app/services/spree/seeds/admin_user.rb` (hasła nie trzymamy w repo). Granice admin/API/storefront: [`admin-access.md`](admin-access.md).
