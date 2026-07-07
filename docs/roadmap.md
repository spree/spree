# Roadmapa

Kolejność prac dla całego systemu (oba repozytoria). Agent bierze zadania od góry: P0 przed P1, P1 przed P2. Zadania w tej samej grupie mogą iść równolegle, jeśli dotyczą różnych repo/plików. Po zamknięciu zadania: zaktualizuj jego status tutaj i stan w [`stan-projektu.md`](stan-projektu.md).

Jeśli któryś opis okaże się nieaktualny w chwili pracy — sprawdź kod, nie ufaj samemu opisowi.

## Faza 1 — Fundament techniczny

Cel fazy: cały łańcuch działa niezawodnie — produkt dodany w adminie jest widoczny i kupowalny w storefroncie, deploy nie jest ruletką, a błędy są widoczne zamiast ciche.

### P0 — blokery produkcyjne

**F1. Rozdziel build od migracji bazy** — `sklepik` — `[zamknięte 2026-07-07]`
Migracje przeniesione do `bin/render-release.sh` (preDeployCommand); build zadaje tylko image. Wszystkie 16 migracji w forku na `if_not_exists` — idempotentne przy re-deployu. `docs/deployment-render.md` opisuje rzeczywisty flow: Build (image) → Release (migracje) → Start (puma).

**F2. Domknij kontrakt pieniędzy w Admin API** — `sklepik` — `[zamknięte 2026-07-07]`
Dodana `Spree::CanonicalNumber` parser (format `\A-?\d+(\.\d{1,4})?\z`) + concern `CanonicalMoneyParams` w PricesController, ProductsController, VariantsController. Wszystkie wpisy cen przez Admin API v3 trafiają kanoniczny format `"1234.56"` bez zależności od locale. Testy: `24.99` i `24,99` się rejektują, `"1234.56"` przechodzi. LocalizedNumber zostaje tylko w legacy admin.

### P1 — realne ryzyka biznesowe i UX

**F3. Serwerowa walidacja gotowości produktu do sprzedaży** — `sklepik` — `[zamknięte 2026-07-07]`
Serwis `Spree::Products::ReadinessCheck` sprawdza: `status: active`, publikacja na wszystkich kanałach sklepu, ceny w walutach wszystkich rynków, purchasable variant, tłumaczenia w locale'ach rynków. Endpoint `GET /api/v3/admin/products/:id/readiness` zwraca `{ ready, checks: [{key, ready, message}] }`. Testy: 6 scenariuszy (gotowy, wrong status, unpublished channel, no price, no stock, no translation). Konsument w panelu dociągnięty: `@spree/admin-sdk` (`products.readiness`), hook `useProductReadiness` i banner ostrzegawczy `ProductReadinessBanner` na stronie edycji produktu (`packages/dashboard/src/routes/.../products/$productId.tsx`) — bez tego merchant mógł zapisać niekompletny produkt (np. bez ceny — `require_master_price` domyślnie `false`) bez żadnego ostrzeżenia w panelu.

**F4. Cache invalidation on-demand w storefroncie** — `sklepikFront` + `sklepik` — `[częściowo zamknięte 2026-07-07]`
Backend już publikował `product.created`/`updated`/`deleted`/`activated`/`archived`/`out_of_stock`/`back_in_stock` (`Spree::Product` ma `publishes_lifecycle_events` + własne `publish_event` na zmianę statusu/zapasu — nie wymagało zmian). Storefront: jeden handler `handleProductChanged` w `/api/webhooks/spree` (`sklepikFront/src/lib/webhooks/handlers.ts`) busuje `products`, `product-filters`, `product:{slug}` + `revalidatePath` dla wszystkich siedmiu. Skonfigurowane w adminie (Ustawienia → Webhooks) — endpoint na `{storefront}/api/webhooks/spree` z tymi siedmioma eventami w subskrypcji.
*Zasada na przyszłość:* nowy event produktowy dopisuje się do subskrypcji endpointu **tylko** razem z handlerem po stronie frontu — świadomie nie subskrybujemy `*` (niepotrzebny ruch webhookowy dla eventów bez handlera, patrz `sklepikFront/docs/technical-debt.md`).
*Otwarte:* edycja samej ceny (`Spree::Price`) lub przypisania do rynku bez zmiany innego pola produktu idzie przez `touch: true` (Price → Variant → Product) — nie zweryfikowano, czy to niezawodnie odpala `after_commit on: :update` i publikuje `product.updated`. Do sprawdzenia/dociągnięcia jeśli okaże się problemem w praktyce.
*Zamknięte gdy:* powyższe zweryfikowane, a edycja ceny/rynku też jest widoczna w storefroncie w sekundach.

**F5. Jawne stany błędów w dashboardzie** — `sklepik` (`packages/dashboard*`) — `[częściowo zamknięte 2026-07-07]`
`ResourceTable` ma destrukturyzować i renderować `error`/`isError` (wspólny `ErrorState` z retry — ten sam, który mają już widoki szczegółów) — **wciąż otwarte**.
*Powiązane znalezione i naprawione 2026-07-07 (audyt, patrz F12):* osobna, ale tej samej rangi klasa błędu — **ciche błędy przy mutacjach**, nie przy ładowaniu list. `useOrderMutation` nie miał `onError`, więc payment capture/void/create, fulfillment, zwroty, karty podarunkowe/kredyt sklepowy, edycja adresu, notatki, tagi — wszystko failowało bez toastu (najwyższe ryzyko: capture/void płatności, sprzedawca mógł myśleć że transakcja przeszła). Edycja adresu zamówienia dodatkowo invalidowała zły klucz cache (`['order', id]` zamiast `['orders', storeId, id]`) — udany zapis nie odświeżał widoku. Usuwanie klienta z listy łykało wszystkie błędy przez `.catch(() => undefined)`. Bulk-add w pickerze mediów wariantu nie miał żadnej obsługi błędu.
*Zamknięte gdy:* `ResourceTable` pokazuje jawny stan błędu (część list) ORAZ audyt F12 potwierdzi że nie ma więcej cichych mutacji w priorytetowych zasobach.

**F6. Trwała idempotencja webhooków e-mail** — `sklepikFront` — `[otwarte]`
Ochrona przed duplikatami zdarzeń przenosi się z `Set` w pamięci do trwałego magazynu (Redis / Postgres z unique constraint + TTL).
*Zamknięte gdy:* restart instancji nie resetuje ochrony przed duplikatami.

### P2 — porządek operacyjny

**F7. Worker w tle** — `sklepik` — `[otwarte]`
Odkomentować workera Sidekiq w `render.yaml` przy przejściu na płatny plan; do tego czasu ograniczenia funkcji async są opisane w `stan-projektu.md`. Konkretny obserwowany skutek braku workera: warianty zdjęć Active Storage (`xlarge` 2000×2000) generują się leniwie przy pierwszym żądaniu — zmierzone 12.5s na zimnym cache vs 1.3s scache'owane — co potrafiło przekroczyć timeout Vercel Image Optimization i zostawić brak zdjęcia na stronie produktu (mitygacja frontowa w `sklepikFront/docs/technical-debt.md`, 2026-07-07). Docelowe rozwiązanie: worker pre-generuje warianty w tle zaraz po uploadzie.

**F8. Decyzja o planie Render** — infra — `[otwarte, świadomie odłożone]`
Starter ($7/mo) zdejmuje cold start, ale ma te same 512 MB co free (ryzyko OOM bez zmian). OOM (>512 MB) zaobserwowany dwukrotnie pod realnym ruchem (drugi raz 2026-07-07, ~14 min po deployu, Render sam podniósł instancję) — nie jest to już jednorazowy fluke.
*Sprawdzone alternatywy (2026-07-07):* Fly.io stracił darmowy tier w 2024 — dziś pay-as-you-go, ~$8-15/mo za 1GB RAM (taniej niż Render Standard, ale nie za darmo, plus migracja configu). Oracle Cloud "Always Free" daje 4 rdzenie ARM + 24GB RAM na zawsze za $0, ale to goły VPS — trzeba samemu postawić Docker/Postgres/Redis/Nginx/SSL, brak auto-deploy z gita.
*Decyzja:* zostajemy na Render (free/starter) do startu realnej sprzedaży — wtedy przejście na **Render Standard (2 GB, ~$25/mo)** jest natychmiastowe (zero migracji, ten sam config). OOM przy niskim ruchu demo jest akceptowalny (Render auto-restartuje instancję).

**F10. Logo sklepu — brak UI i brak konsumenta** — `sklepik` + `sklepikFront` — `[zamknięte 2026-07-07]`
`Spree::Store#logo` istniał w bazie od dawna, ale nic go nie używało. Domknięte kompletnie: nowy publiczny `GET /api/v3/store/store` (`Spree::Api::V3::StoreSerializer`, `Admin::StoreSerializer` teraz go dziedziczy zamiast duplikować pola — "Admin extends Store" z CLAUDE.md), `:logo` dopuszczony w `permitted_params` Admin API (nigdy wcześniej nie akceptował zapisu), walidacja `content_type` na `Store#logo` dociągnięta (miała ją tylko `mailer_logo`). Panel: pole uploadu w Ustawienia → Sklep (`settings/store.tsx`, wzorzec `ImageUploadField` skopiowany z `settings/emails.tsx`), zapis przez `logo_signed_id`. Storefront: `Header.tsx` renderuje `logo_url` zamiast tekstowej nazwy (fallback gdy brak), max 40px wysokości bez wymuszonego cropu; JSON-LD SEO bierze logo z API z fallbackiem na statyczny env.
*Dług techniczny:* `@spree/sdk` na npm nie ma jeszcze opublikowanej `store.get()` (dodana w monorepie) — storefront obchodzi to udokumentowanym escape hatchem, patrz `sklepikFront/docs/technical-debt.md`.

**F11. Przełącznik kraju/waluty w storefroncie — zepsuty i koncepcyjnie pomieszany** — `sklepikFront` — `[częściowo zamknięte 2026-07-07]`
`CountrySwitcher.tsx` mieszał język i walutę w jednym dropdownie, budował linki wg starego schematu `/{country}/{locale}/...` usuniętego z routingu → wybór innego kraju dawał 404; flaga-emoji nie renderowała się na części systemów i dublowała się wizualnie z tekstem kodu kraju obok. Pełny plan rozdzielenia (Market vs Język, dwie niezależne osie jak w Amazon/ASOS/Shopify Markets) w [`docs/plans/market-language-switcher.md`](plans/market-language-switcher.md).
Kroki 0+1 wykonane: zepsuty dropdown usunięty, zastąpiony `LanguageSwitcher.tsx` (next-intl, niezależny od waluty).
*Zamknięte gdy:* kroki 2-4 planu zrealizowane — realny drugi `Market` (np. Eurozone/EUR) w adminie, `MarketSwitcher` oparty o cookie.

**F12. Systematyczny audyt panelu — read/write symmetry, martwe endpointy, ciche błędy** — `sklepik` (`packages/dashboard*`, `spree/api`) — `[zamknięte 2026-07-07]`
Po dwóch niezależnych znaleziskach tego samego kształtu (F10 — logo istniało w API, brak UI; F3 — readiness check istniał, zero konsumentów) zlecony systematyczny audyt wg trzech wzorców: (1) pole w serializerze bez odpowiednika w `permitted_params`/UI (i odwrotnie); (2) akcja kontrolera bez żadnego odniesienia we froncie (SDK/hook/route); (3) `.mutateAsync` bez `try/catch` + `mapSpreeErrorsToForm`/`toast.error` — cichy błąd wygląda jak sukces.
*Wzorzec 3 (ciche błędy), naprawione:* opisane w F5 powyżej — `useOrderMutation` bez `onError`, zła invalidacja cache przy adresie zamówienia, `.catch(() => undefined)` przy usuwaniu klienta, brak obsługi błędu w pickerze mediów wariantu. Reszta priorytetowych zasobów (produkty, promocje, ceny, płatności, lokalizacje magazynowe) sprawdzona — konsekwentnie korzystają z `useResourceMutation`/`mapSpreeErrorsToForm`, żadnych dodatkowych cichych błędów nie znaleziono.
*Wzorzec 2 (martwe endpointy), znaleziska nie naprawione — wymagają decyzji produktowej/UI, nie samego wpięcia:*
- `Admin::PriceListsController#prices` ("spreadsheet data feed") nie ma w ogóle trasy w `config/routes.rb` — martwy kod, nieosiągalny nawet przez API. Prawdopodobnie relikt po przejściu cen list na payload PATCH (`prices: [...]`) — do usunięcia albo faktycznego wpięcia, jeśli spreadsheet ma z niego korzystać.
- `orders/fulfillments#resume` i `#split` — w SDK (`adminClient.orders.fulfillments.resume/split`), zero użycia w `$orderId.tsx`. Panel umie fulfillment anulować, ale nie wznowić błędnie anulowanej wysyłki ani podzielić jej na dwie (częściowa wysyłka/backorder).
- `Channels#add_products` / `#remove_products` — cały mechanizm przypisywania produktów do kanału dystrybucji nie ma ŻADNEGO UI (`settings/channels.tsx`, 469 linii, zero wzmianek o produktach). Kanał da się utworzyć w panelu, ale nie da się do niego przypisać ani jednego produktu — funkcja praktycznie bezużyteczna z poziomu panelu.
*Wzorzec 1 (read/write symmetry):* przegoniony punktowo dla klientów, metod płatności, lokalizacji magazynowych, zamówień, promocji — symetryczne. Jedyna asymetria: `customers_controller#permitted_params` przyjmuje `:avatar`/`:selected_locale`, ale żaden serializer ich nie zwraca i żaden UI ich nie ustawia — martwe parametry, nie realna luka (nic ich nie używa z żadnej strony).
*Rekomendacja:* trzy znaleziska wzorca 2 wyżej to kandydaci na osobne, mniejsze zadania (każde wymaga UI/decyzji, nie tylko wpięcia) — kanały produktowe najpilniejsze biznesowo, jeśli multi-channel selling jest w planach.

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
