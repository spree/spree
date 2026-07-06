# Roadmapa

Kolejność prac dla całego systemu (oba repozytoria). Agent bierze zadania od góry: P0 przed P1, P1 przed P2. Zadania w tej samej grupie mogą iść równolegle, jeśli dotyczą różnych repo/plików. Po zamknięciu zadania: zaktualizuj jego status tutaj i stan w [`stan-projektu.md`](stan-projektu.md).

Jeśli któryś opis okaże się nieaktualny w chwili pracy — sprawdź kod, nie ufaj samemu opisowi.

## Faza 1 — Fundament techniczny

Cel fazy: cały łańcuch działa niezawodnie — produkt dodany w adminie jest widoczny i kupowalny w storefroncie, deploy nie jest ruletką, a błędy są widoczne zamiast ciche.

### P0 — blokery produkcyjne

**F1. Rozdziel build od migracji bazy** — `sklepik` — `[otwarte]`
`bin/render-build.sh` odpala `db:prepare`/`db:migrate` w `buildCommand` na świeżo klonowanym `server/`; migracje silnika są kopiowane pod nowymi timestampami przy każdym buildzie i nie wszystkie są idempotentne. Do zrobienia: (a) wydzielić migracje do osobnej fazy (Render pre-deploy/release, nie build), (b) zdecydować czy `server/` zostaje efemeryczny czy commitowany, (c) audyt idempotentności migracji dodanych w tym forku, (d) zaktualizować `docs/deployment-render.md`.
*Zamknięte gdy:* deploy produkcyjny nie wykonuje `db:migrate` w `buildCommand`, a dokument deploymentu opisuje realne zachowanie.

**F2. Domknij kontrakt pieniędzy w Admin API** — `sklepik` — `[otwarte]`
`Spree::Price#amount=` / `#compare_at_amount=` parsują przez `LocalizedNumber.parse` (heurystyka locale) — stąd korupcja `24.99` → `2499`/`1999`. Dashboard wysyła już kanoniczny string `"1234.56"`, backend musi go tak samo kanonicznie przyjmować (`BigDecimal` z walidacją formatu) w ścieżce zapisu Admin API v3. Lokalne parsowanie zostaje tylko tam, gdzie człowiek wpisuje dane w legacy admin. Dodać test: `"24.99"` i `"24,99"` nigdy nie lądują w bazie jako `2499`/`1999` po cichu.
*Zamknięte gdy:* żadna ścieżka zapisu ceny w Admin API v3 nie zależy od locale requestu.

### P1 — realne ryzyka biznesowe i UX

**F3. Serwerowa walidacja gotowości produktu do sprzedaży** — `sklepik` — `[otwarte]`
Produkt "sprzedawalny" = `status: active` + publikacja kanałowa z poprawnym oknem + cena w walucie rynku + tłumaczenie w locale + stock. Żadna warstwa nie mówi "niekompletny". Dodać serwis zwracający checklistę gotowości, wystawić w Admin API, w dashboardzie pokazać ostrzeżenie (nie blokować zapisu).
*Zamknięte gdy:* niekompletny produkt jest widocznie oznaczony w adminie, zanim klient zgłosi pusty katalog.

**F4. Cache invalidation on-demand w storefroncie** — `sklepikFront` + `sklepik` — `[otwarte]`
Endpoint webhookowy w storefroncie (autoryzowany współdzielonym sekretem) wywołujący `revalidateTag(...)`; backend wysyła event po zmianie produktu/ceny/rynku.
*Zamknięte gdy:* edycja w adminie jest widoczna w storefroncie w sekundach, nie po TTL 10–15 min.

**F5. Jawne stany błędów w dashboardzie** — `sklepik` (`packages/dashboard*`) — `[otwarte]`
`ResourceTable` ma destrukturyzować i renderować `error`/`isError` (wspólny `ErrorState` z retry — ten sam, który mają już widoki szczegółów).
*Zamknięte gdy:* każda lista zasobów pokazuje jawny stan błędu zamiast wiecznych skeletonów.

**F6. Trwała idempotencja webhooków e-mail** — `sklepikFront` — `[otwarte]`
Ochrona przed duplikatami zdarzeń przenosi się z `Set` w pamięci do trwałego magazynu (Redis / Postgres z unique constraint + TTL).
*Zamknięte gdy:* restart instancji nie resetuje ochrony przed duplikatami.

### P2 — porządek operacyjny

**F7. Worker w tle** — `sklepik` — `[otwarte]`
Odkomentować workera Sidekiq w `render.yaml` przy przejściu na płatny plan; do tego czasu ograniczenia funkcji async są opisane w `stan-projektu.md`.

**F8. Decyzja o planie Render** — infra — `[otwarte]`
Starter ($7/mo) zdejmuje cold start, ale ma te same 512 MB co free (ryzyko OOM bez zmian). Obserwować zużycie pod realnym ruchem, ewentualnie Standard (2 GB).

### P3 — siatka bezpieczeństwa

**F9. Testy e2e łańcucha rynek → waluta → publikacja → cache** — oba repo — `[otwarte]`
Minimalny pakiet: (1) produkt aktywny + publikacja + cena PLN → widoczny w Store API; (2) usunięcie publikacji/ceny → admin pokazuje "niegotowy" (F3), nie cichy sukces; (3) `24,99`/`24.99` → w bazie zawsze `24.99` (F2); (4) edycja ceny → webhook → storefront pokazuje nową wartość bez TTL (F4); (5) zmiana domyślnego locale/currency rynku nie ukrywa produktów bez jawnego komunikatu.
*Zamknięte gdy:* te scenariusze przechodzą w CI przed merge do main.

## Faza 2 — Kakao MVP

Start dopiero po zamknięciu P0 i P1 z Fazy 1.

Zakres:
- Realne produkty kakao (na start ~5: kakao ceremonialne klasyczne i intensywne, zestaw degustacyjny, kakao z przyprawami, akcesoria) — mogą być fikcyjne, ale mają wyglądać realistycznie.
- Kategorie produktów.
- Branding premium storefrontu (strona główna, strona produktu) — ton marki opisany w `sklepikFront/docs/kierunek-frontu.md`.
- Strony informacyjne: O nas, Dostawa, Zwroty, Kontakt.
- Strony prawne: regulamin, polityka prywatności, prawo odstąpienia.
- Konfiguracja płatności (Stripe przez `spree_stripe`).
- Własna domena (storefront + admin + backend; docelowo admin pod `/admin/*` tej samej domeny przez rewrite Vercela).
- Weryfikacja pełnego flow zakupowego end-to-end.

Poza zakresem MVP (świadomie później): gry, VOD, subskrypcje, program lojalnościowy, AI, rozbudowany CMS.

## Faza 3 — moduły premium

Storytelling, edukacja produktowa, quizy, subskrypcje, lojalność, integracje AI — jako osobne moduły nad stabilnym corem, nigdy w krytycznej ścieżce checkoutu.

---

## Zamknięte

- **F0. Wielkie porządki repo i dokumentacji** — oba repo — `[zamknięte 2026-07-06]`
  Usunięta upstreamowa dokumentacja Spree (~1100 plików), README-y przepisane pod projekt, jedno źródło prawdy governance (`kierunek-projektu.md`), nowy komplet żywych dokumentów (`architektura`, `stan-projektu`, `roadmap`), protokół aktualizacji dokumentacji przez agentów w CLAUDE.md obu repo. Kierunek "Vercel Commerce" formalnie odrzucony.
