# Stan projektu

**Żywy dokument.** Każdy agent po zakończeniu zadania aktualizuje ten plik tak, żeby odzwierciedlał rzeczywisty, bieżący stan systemu — nie dopisuje kolejnych wpisów dziennika, tylko poprawia treść. Historia jest w gicie.

Ostatnia aktualizacja: 2026-07-06 (wielkie porządki dokumentacji i governance obu repo).

## Co działa

- **Backend na Render** (`kakaowy-sklepik.onrender.com`) buduje się i działa: gemy z tego forka (`SPREE_PATH`), migracje silnika kopiowane i aplikowane przy buildzie, baza zseedowana.
- **Panel admina** (`sklepik-gamma.vercel.app`) działa end-to-end: logowanie JWT przez single-origin proxy, zarządzanie produktami.
- **Storefront** (`sklepikkk.vercel.app`) działa: rebranding "Kakałowy Sklepik", polski domyślny locale bez prefiksu URL, katalog i strony produktów renderują się z danych Store API.
- **Dane:** jeden rynek Polska/PLN/pl (7 demo-rynków usuniętych), 6 produktów kakao zseedowanych przez Admin API, ceny w PLN, media na R2.
- Testy storefrontu zielone (build + 89 testów vitest na moment rebrandingu).

## Znane problemy (aktualne)

Uporządkowane wg wagi — szczegóły i plan naprawy w [`roadmap.md`](roadmap.md):

1. **Cicha korupcja cen (P0):** zapis ceny w adminie potrafi zamienić `24.99` na `24990`/`1999` — `Spree::Price#amount=` parsuje przez `LocalizedNumber.parse` zależnie od locale. Jedna cena została ręcznie poprawiona w danych; bug w kodzie nadal istnieje.
2. **Migracje w kroku builda (P0):** `bin/render-build.sh` odpala `db:migrate` w `buildCommand` na świeżo klonowanym `server/`, migracje kopiowane pod nowymi timestampami przy każdym deployu. Już raz wywaliło produkcyjny build (duplicate column); obecne zabezpieczenia (`if_not_exists`) są defensywą, nie rozwiązaniem.
3. **Dashboard nie pokazuje błędów API:** 500 z backendu = wieczne skeletony zamiast komunikatu (`resource-table.tsx` ignoruje `error`/`isError`).
4. **Kruche warunki widoczności produktu:** produkt wymaga jednocześnie `status: active`, `available_on` w przeszłości lub `ProductPublication` w kanale, ceny w walucie rynku i tłumaczenia w locale — żadna warstwa nie mówi "produkt niekompletny". To była przyczyna "pustego katalogu".
5. **Cache storefrontu bez inwalidacji:** zmiany z admina widać po 10–15 min (TTL `use cache` + edge Vercela); brak webhooka rewalidacyjnego.
6. **Idempotencja webhooków e-mail w pamięci procesu** (`Set` w `handlers.ts`) — restart instancji = możliwy duplikat e-maila.
7. **Worker Sidekiq wyłączony** (zakomentowany w `render.yaml`) — jeden proces web dźwiga wszystko; wymaga płatnego planu.
8. **Render free/starter:** cold start ~18 s po bezczynności; raz zaobserwowany OOM (>512 MB) przy ciężkim ruchu API.
9. **Vercel `sklepik_back` quirk:** webhook potrafi nie łapać pushy; pomaga ręczny Redeploy w UI.
10. Niezweryfikowany do końca "flicker" po zalogowaniu do admina — ślady wskazują na przyczynę poza aplikacją (DevTools/rozszerzenie); wraca tylko jeśli się odtworzy w czystej przeglądarce.

## Czego jeszcze nie ma (przed startem sprzedaży)

- Płatności (kierunek: Stripe — gem `spree_stripe` jest w starterze, brak konfiguracji i kluczy).
- Strony prawne: regulamin, polityka prywatności, prawo odstąpienia (wymagane w PL).
- Własna domena (wszystko na `*.vercel.app` / `*.onrender.com`).
- Testy e2e łańcucha rynek → waluta → publikacja → cache.
- Decyzja o płatnym planie Render.

## Dostępy

- Admin: `sklepik-gamma.vercel.app`, konto seedowe wg `spree/core/app/services/spree/seeds/admin_user.rb` (hasła nie trzymamy w repo). Granice admin/API/storefront: [`admin-access.md`](admin-access.md).
