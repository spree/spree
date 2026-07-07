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
Serwis `Spree::Products::ReadinessCheck` sprawdza: `status: active`, publikacja na wszystkich kanałach sklepu, ceny w walutach wszystkich rynków, purchasable variant, tłumaczenia w locale'ach rynków. Endpoint `GET /api/v3/admin/products/:id/readiness` zwraca `{ ready, checks: [{key, ready, message}] }`. Testy: 6 scenariuszy (gotowy, wrong status, unpublished channel, no price, no stock, no translation).

**F4. Cache invalidation on-demand w storefroncie** — `sklepikFront` + `sklepik` — `[częściowo zamknięte 2026-07-07]`
Backend już publikował `product.created`/`updated`/`deleted`/`activated`/`archived`/`out_of_stock`/`back_in_stock` (`Spree::Product` ma `publishes_lifecycle_events` + własne `publish_event` na zmianę statusu/zapasu — nie wymagało zmian). Storefront: jeden handler `handleProductChanged` w `/api/webhooks/spree` (`sklepikFront/src/lib/webhooks/handlers.ts`) busuje `products`, `product-filters`, `product:{slug}` + `revalidatePath` dla wszystkich siedmiu. Skonfigurowane w adminie (Ustawienia → Webhooks) — endpoint na `{storefront}/api/webhooks/spree` z tymi siedmioma eventami w subskrypcji.
*Zasada na przyszłość:* nowy event produktowy dopisuje się do subskrypcji endpointu **tylko** razem z handlerem po stronie frontu — świadomie nie subskrybujemy `*` (niepotrzebny ruch webhookowy dla eventów bez handlera, patrz `sklepikFront/docs/technical-debt.md`).
*Otwarte:* edycja samej ceny (`Spree::Price`) lub przypisania do rynku bez zmiany innego pola produktu idzie przez `touch: true` (Price → Variant → Product) — nie zweryfikowano, czy to niezawodnie odpala `after_commit on: :update` i publikuje `product.updated`. Do sprawdzenia/dociągnięcia jeśli okaże się problemem w praktyce.
*Zamknięte gdy:* powyższe zweryfikowane, a edycja ceny/rynku też jest widoczna w storefroncie w sekundach.

**F5. Jawne stany błędów w dashboardzie** — `sklepik` (`packages/dashboard*`) — `[otwarte]`
`ResourceTable` ma destrukturyzować i renderować `error`/`isError` (wspólny `ErrorState` z retry — ten sam, który mają już widoki szczegółów).
*Zamknięte gdy:* każda lista zasobów pokazuje jawny stan błędu zamiast wiecznych skeletonów.

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

**F10. Logo sklepu — brak UI i brak konsumenta** — `sklepik` + `sklepikFront` — `[otwarte]`
`Spree::Store#logo` istnieje w bazie i w Admin API (`logo_url` w `store_serializer.rb`), ale nic go nie używa: panel nie ma pola do wgrania (`settings/store.tsx` — tylko `mailer_logo` w `settings/emails.tsx` ma gotowy `ImageUploadField`, wzorzec do skopiowania), a storefront w nagłówku pokazuje samą tekstową nazwę (`Header.tsx`, `getStoreName()`) i do JSON-LD SEO bierze logo ze statycznego env `STORE_LOGO_URL`, nie z API.
*Zamknięte gdy:* upload logo w panelu (Ustawienia → Sklep) działa i zapisuje się przez `logo_signed_id`, a storefront renderuje je w nagłówku (i/lub w danych SEO) z API zamiast hardkodowanego env.

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
