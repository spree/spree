# System-wide production readiness audit — 2026-07-08

## Executive summary

- **Overall readiness verdict: `Not production-ready`.** System ma działające elementy fundamentu, ale statyczny audyt repo `sklepik` potwierdza blokery dla realnej sprzedaży: brak panelowej/API konfiguracji shipping/tax rates/zones, brak skonfigurowanej produkcyjnej metody płatności Stripe, wyłączony worker Sidekiq, brak pełnego potwierdzenia storefrontu `sklepikFront` w workspace oraz braki prawno-operacyjne.
- **Top 5 blockerów:**
  1. Checkout nie ma potwierdzonej konfiguracji wysyłki/stref/stawek podatkowych w Admin API v3/panelu, a F13 znalazł brak tych powierzchni (`docs/audit-playbook.md`, sekcja F13 prompt 2).
  2. Produkcyjny Stripe nie jest skonfigurowany statycznie: seed tworzy tylko `Spree::PaymentMethod::StoreCredit`, a `render.yaml` nie deklaruje kluczy Stripe/webhook secret.
  3. Storefront `sklepikFront` nie jest obecny w workspace, więc katalog/PDP/koszyk/checkout/SEO/revalidation mogą być ocenione tylko z dokumentów, nie z kodu źródłowego.
  4. Worker Sidekiq jest zakomentowany w `render.yaml`; zadania async, webhooki/eksporty/media warianty i retry nie mają potwierdzonego procesu produkcyjnego.
  5. Brakuje stron prawnych/operacyjnych wymaganych przed sprzedażą w PL: regulamin, polityka prywatności, odstąpienie/zwroty, faktury/VAT i polityka danych klienta.
- **Top 5 ryzyk nieblokujących, ale ważnych:**
  1. `ResourceTable` nie renderuje `isError/error`; lista może wyglądać jak pusta albo wiecznie ładująca się przy awarii API.
  2. Migracje nadal zawierają wiele DDL bez `if_not_exists`/`if_exists`; przy efemerycznym `server/` na Renderze to powtarzalne ryzyko release'u.
  3. Rotacja sekretu webhook endpointu, admin `data_feeds` i per-wierszowe błędy tłumaczeń nadal są otwarte po F13.
  4. Role/uprawnienia mają bazę CanCanCan/permission sets, ale brak pełnej macierzy e2e UI→API i brak guardu self/last-admin.
  5. Observability jest fragmentaryczne: webhook deliveries istnieją, ale brakuje runbooków i dashboardów dla checkout/payment/images/jobs/empty catalog.
- **Obszary, których nie dało się zweryfikować statycznie:**
  - Kod `sklepikFront` nie istnieje w `/workspace` ani w pobliżu (`find / -maxdepth 3 -iname '*sklepik*'` znalazł tylko `/workspace/sklepik`). Do pełnego audytu trzeba dostarczyć checkout/SEO/cache source repo albo staging access.
  - Sekrety produkcyjne (Stripe, R2, Vercel env, webhook secret, SMTP) nie są w repo i słusznie nie powinny być. Trzeba je sprawdzić w Render/Vercel/Stripe dashboards.
  - Runtime DB nie była uruchamiana; nie potwierdzono realnych rekordów shipping methods, tax rates, payment methods, policies, stores/markets ani R2 bucket policy.

## Scope and method

- **Repozytoria skontrolowane:** `/workspace/sklepik` — backend Rails/Spree, Store API, Admin API, dashboard React, SDK, deploy Render/Vercel dashboard.
- **Repozytoria niedostępne:** `sklepikFront` — nie znaleziono sibling repo w `/workspace`; audyt storefrontu opiera się tylko na dokumentacji w `docs/stan-projektu.md`, `docs/roadmap.md`, `docs/architektura.md`.
- **Ważne pliki przeczytane:** `CLAUDE.md`, `docs/kierunek-projektu.md`, `docs/stan-projektu.md`, `docs/roadmap.md`, `docs/audit-playbook.md`, `docs/architektura.md`, `docs/deployment-render.md`, `render.yaml`, `packages/dashboard/vercel.json`, `spree/api/config/routes.rb`, kontrolery Store API cart/payment/fulfillment, `packages/dashboard-core/src/components/resource-table.tsx`, migracje `spree/core/db/migrate/*`.
- **Komendy/searches:** `git status --short`, `find /workspace -maxdepth 2`, `find / -maxdepth 3 -iname '*sklepik*'`, `rg --files`, `rg -n "Stripe|stripe|PaymentMethod|payment_sessions|shipping_rates|Rack::Attack|rate limit|active_storage|R2|create_table|add_column|add_index"`, selektywne `sed -n` kontrolerów i configów.
- **Czego nie uruchamiano:** pełnego Rails servera, e2e storefrontu, realnych checkoutów, Stripe sandbox, Sidekiq, R2 uploadów. To audyt statyczny z wysoką pewnością dla braków w kodzie/configu i z oznaczeniem `unknown-needs-runtime-verification` tam, gdzie potrzebny jest staging.
- **Założenia F12/F13 użyte jako prior context:** F12/F13 pokryły głównie read/write symmetry, martwe endpointy i ciche mutacje w Admin API/dashboardzie; nie traktuję ich jako dowodu produkcyjnej gotowości checkoutu/storefrontu/infra.

## Severity model

- **P0** — blocker produkcji / security-critical / money-critical.
- **P1** — powinno być naprawione przed startem sprzedaży.
- **P2** — ważne, może wejść po starcie przy świadomej mitygacji.
- **P3** — cleanup / hardening / dokumentacja.

## Findings

### SYS-001 — Storefront `sklepikFront` nie był dostępny do audytu kodowego

Severity: P0  
Area: storefront  
Status: unknown-needs-runtime-verification

Evidence:

- `find / -maxdepth 3 -type d -iname '*sklepik*'` zwrócił tylko `/workspace/sklepik`; brak checkoutu repo `sklepikFront` w workspace.
- Dokumentacja mówi, że storefront jest osobnym repo `pawelekbyra/sklepikFront` i konsumuje Store API (`docs/kierunek-projektu.md`, `docs/stan-projektu.md`).
- `docs/stan-projektu.md` twierdzi, że katalog i PDP działają oraz że testy storefrontu były zielone w momencie rebrandingu, ale to nie zastępuje aktualnego audytu kodu.

Impact:

- Nie można potwierdzić katalogu, PDP, koszyka, checkout entry, SEO metadata, canonicali, JSON-LD, image handling, empty/error states, cache/revalidation ani zachowania przy niedostępnym backendzie.
- Ryzyko fałszywego poczucia gotowości: backend może być poprawny, a storefront nadal może blokować zakup albo ukrywać błędy konfiguracji.

Recommended fix:

- Dodać `sklepikFront` do workspace audytowego albo uruchomić równoległy audyt w tamtym repo tym samym szablonem.
- Wymagać w CI/staging smoke testu: home → PLP → PDP → add to cart → checkout entry → error state dla wyłączonego backendu.

Verification:

- Uruchomić `pnpm build`, `pnpm test`, e2e checkout smoke w `sklepikFront` oraz statycznie sprawdzić App Router routes, metadata, JSON-LD, webhook/revalidation handlers i env validation.

### SYS-002 — Realny checkout jest money-critical zablokowany przez brak konfiguracji shipping/tax w Admin API v3/panelu

Severity: P0  
Area: checkout  
Status: confirmed missing feature

Evidence:

- Store API ma kompletne cart endpoints: `/api/v3/store/carts`, items, fulfillments, payments, payment_sessions i `complete` w `spree/api/config/routes.rb`.
- `CartsController#show` i `#update` auto-advance'ują checkout state machine, a `FulfillmentsController#update` wybiera `selected_delivery_rate_id` i próbuje przejść do payment (`spree/api/app/controllers/spree/api/v3/store/carts_controller.rb`, `spree/api/app/controllers/spree/api/v3/store/carts/fulfillments_controller.rb`).
- F13 prompt 2 potwierdził brak Admin API v3/dashboard dla shipping methods, shipping categories, zones i tax rates; w repo nie znaleziono adminowych kontrolerów tych zasobów.

Impact:

- Kupujący może dojść do koszyka, ale jeśli produkcyjna baza nie ma poprawnie zseedowanych metod wysyłki/stref/stawek, checkout zatrzyma się na delivery albo naliczy błędne koszty/podatki.
- Merchant nie ma panelowej ścieżki naprawy; będzie zależny od konsoli/seeda/ręcznej migracji danych.

Recommended fix:

- Przed sprzedażą dodać albo pełny Admin API/UI dla shipping methods/categories/zones/tax rates, albo udokumentowany i testowany seed produkcyjny z ręcznym runbookiem.
- Dodać health check staging: produkt fizyczny w PL → adres PL → shipping rates > 0 → tax adjustment zgodny z oczekiwaniem → complete possible.

Verification:

- E2E Store API: create cart, add item, set address, assert shipments and rates, select rate, create payment/session, complete order.
- Dashboard/admin smoke: merchant potrafi zmienić koszt dostawy/VAT bez Rails console.

### SYS-003 — Stripe/live payment readiness nie jest potwierdzona; seed tworzy tylko StoreCredit

Severity: P0  
Area: payments  
Status: confirmed configuration risk

Evidence:

- `spree/core/app/services/spree/seeds/payment_methods.rb` tworzy tylko `Spree::PaymentMethod::StoreCredit` dla każdego sklepu.
- Store API ma payment sessions (`spree/api/app/controllers/spree/api/v3/store/carts/payment_sessions_controller.rb`) i zwykłe payments (`spree/api/app/controllers/spree/api/v3/store/carts/payments_controller.rb`), ale statyczny config Render nie zawiera `STRIPE_*` ani webhook secret (`render.yaml`).
- Roadmap/stan projektu mówią wprost: „Płatności (Stripe — gem `spree_stripe` jest w starterze, brak konfiguracji i kluczy)”.

Impact:

- Realny klient nie zapłaci kartą/Stripe w produkcji, nawet jeśli API payment sessions istnieje.
- Brak live/test separation i webhook verification może skutkować fałszywie opłaconymi zamówieniami albo brakiem księgowania płatności.

Recommended fix:

- Skonfigurować Stripe jako aktywną metodę płatności per store/market: publishable key, secret key, webhook signing secret, test/live mode, auto_capture policy.
- Dodać webhook endpoint Stripe i testować idempotentne eventy `payment_intent.succeeded/failed`, refundy, dispute/cancel jeśli obsługiwane.
- Zbudować dashboard/runbook płatności: failed authorizations, payments in checkout/pending, reconciliation by `response_code`/Stripe intent id.

Verification:

- Stripe test mode: successful card, declined card, 3DS required, duplicate webhook delivery, refund, void/capture z Admin API/dashboardu.
- Sprawdzić, czy order `payment_state` i Stripe dashboard są spójne po każdym scenariuszu.

### SYS-004 — Store API ma checkout endpoints, ale pierwszy blokujący punkt flow to shipping/payment runtime configuration

Severity: P0  
Area: checkout  
Status: likely

Evidence:

- `CartsController#complete` odmawia ukończenia przy `guest_checkout_disallowed?`, woła `Spree::Dependencies.carts_complete_service` i zwraca błąd `cart_cannot_complete` przy niepowodzeniu.
- `Spree::Carts::Complete` procesuje płatności tylko jeśli `payment_required?`; jeżeli payment session wcześniej oznaczyła płatność jako completed, pomija re-process (`spree/core/app/services/spree/carts/complete.rb`).
- Brak potwierdzonej metody Stripe i brak panelowych shipping/tax configs oznacza, że state machine może dojść do payment tylko przy specjalnych danych demo albo StoreCredit, nie przy realnym flow kupującego.

Impact:

- Produkcyjna ścieżka „klient płaci kartą za fizyczny produkt z wysyłką” nie jest statycznie dowiedziona jako możliwa.
- Najbardziej prawdopodobny failure mode: brak shipping rates albo brak dostępnej metody płatności, a storefront może to pokazać jako pusty/niejasny checkout.

Recommended fix:

- Zdefiniować jeden canonical happy path MVP: Polska/PLN/pl, produkt fizyczny, adres PL, jedna metoda wysyłki, VAT, Stripe card, guest checkout lub login — i utrzymywać go jako e2e smoke.

Verification:

- Test staging z realnym Store API i test Stripe: catalog → PDP → cart → address → shipping rate → Stripe payment → complete → order visible in dashboard → fulfillment create/ship.

### SYS-005 — Store API contract dla storefrontu ma ryzyka market/currency/publication/cache edge cases

Severity: P1  
Area: Store API  
Status: confirmed production-readiness risk

Evidence:

- Store routes obejmują products, categories, markets, currencies, locales i `products/filters` (`spree/api/config/routes.rb`).
- `docs/stan-projektu.md` dokumentuje wcześniejszy incydent: brak `SPREE_API_URL`/`SPREE_PUBLISHABLE_KEY` na Vercel powodował cichy pusty katalog.
- `docs/stan-projektu.md` dokumentuje ryzyko produktów bez `product_publications` oraz niezweryfikowaną inwalidację cache przy edycji samej ceny/rynku.

Impact:

- Storefront może pokazać pusty katalog bez jasnego błędu albo nie odświeżyć ceny/rynku po zmianie w adminie.
- Merchant może uznać, że produkt jest aktywny, a klient go nie widzi przez brak publication/channel/currency/price.

Recommended fix:

- Dodać kontraktowe testy Store API konsumowane przez storefront: produkty aktywne/nieaktywne, brak publication, brak ceny PLN, brak stock, deleted/unpublished, locale fallback, market resolve.
- Storefront powinien rozróżniać „backend misconfigured/unavailable” od prawdziwie pustego katalogu.

Verification:

- Fixture-driven Store API tests + storefront e2e z mockami: empty catalog, API 500/timeout, missing publishable key, product without price/publication.

### SYS-006 — Performance: listy admina, katalog i serializers wymagają testów z większym wolumenem; część kodu już stosuje includes, ale brak budżetów i smoke load

Severity: P1  
Area: performance  
Status: unknown-needs-runtime-verification

Evidence:

- Store products controller używa `scope.includes(collection_includes).preload_associations_lazily.accessible_by(...)` według wyników `rg` w `spree/api/app/controllers/spree/api/v3/store/products_controller.rb`.
- `ResourceTable` paginuje i filtruje przez queryFn, ale każdy ekran listy zależy od konkretnego endpointu/serializerów (`packages/dashboard-core/src/components/resource-table.tsx`).
- Webhook endpoint serializer liczy delivery totals przez zapytania `endpoint.webhook_deliveries.count/where/maximum` (F13 evidence), co przy listach wielu endpointów może mnożyć zapytania.

Impact:

- Na 6 produktach demo wszystko może działać, ale przy setkach produktów/zamówień/webhook deliveries pojawią się N+1, wolne listy i timeouty Render/Vercel.

Recommended fix:

- Dodać performance smoke z seedem 500 produktów/50 zamówień/1000 webhook deliveries i thresholdami dla PLP, PDP, admin products/orders, webhook detail, exports.
- Dla serializerów z licznikami dodać counter caches albo preload/aggregate queries.

Verification:

- `rack-mini-profiler`/Bullet w dev/test, request specs z `assert_queries` dla wybranych endpoints, k6/Artillery smoke na staging.

### SYS-007 — Permission matrix nadal nie jest zamknięta e2e; self/last-admin guard pozostaje security blockerem przed launch

Severity: P1  
Area: security  
Status: confirmed production-readiness risk

Evidence:

- Permission sets istnieją w `spree/core/app/models/spree/permission_sets/*`, a `spree/core/app/models/spree/ability.rb` buduje CanCanCan ability.
- Admin controllers konsekwentnie używają `authorize!`/`accessible_by` w wielu miejscach.
- F13 znalazł brak twardego guardu self/last-admin w `AdminUsersController#destroy/#update` i tylko guardy przed eskalacją roli/API key scope amplification.

Impact:

- Administrator może doprowadzić do lockoutu sklepu; mniej uprzywilejowane role mogą mieć niesprawdzone rozbieżności UI/API.
- Ukrycie akcji w UI nie wystarcza, bo Admin API pozostaje dostępne przez JWT/secret keys.

Recommended fix:

- Zbudować testowaną macierz: role (`admin`, `owner`, `customer_service`, `warehouse`, `marketing`, read-only) × endpoint × action × UI capability.
- Backendowo zablokować usuwanie ostatniego admina i odebranie sobie ostatniej roli administracyjnej.

Verification:

- Controller/request specs dla matrixy + Playwright dla dashboard UI: ukryte/przyciski disabled oraz API 403/422 dla niedozwolonych akcji.

### SYS-008 — Brak widocznego rate limit/brute-force hardening dla auth/password reset

Severity: P1  
Area: security  
Status: likely

Evidence:

- Search `rg "Rack::Attack|rate limit|throttle"` w repo nie pokazał konfiguracji rate limitera.
- Store routes wystawiają publiczne `auth/login`, `auth/refresh`, `password_resets#create/update`, `customers#create`, newsletter subscribe/verify (`spree/api/config/routes.rb`).
- Dashboard działa przez same-origin proxy `/api/*` do Render (`packages/dashboard/vercel.json`).

Impact:

- Login/password reset/newsletter/customer create mogą być podatne na brute force, credential stuffing, enumeration albo abuse bez warstwy WAF/rate limiting.

Recommended fix:

- Dodać Rack::Attack albo edge/WAF rate limits per IP+email dla login/reset/newsletter/customer create oraz limit globalny dla Store API write endpoints.
- Ujednolicić odpowiedzi login/reset pod kątem enumeration.

Verification:

- Request specs dla limitów; staging test: 20 prób login/reset i oczekiwane 429 z bezpiecznym komunikatem.

### SYS-009 — Worker Sidekiq jest wyłączony, a Redis free/ipAllowList empty zwiększa ryzyko async/runtime

Severity: P1  
Area: jobs  
Status: confirmed configuration risk

Evidence:

- `render.yaml` ma tylko web service; worker Sidekiq jest w komentarzu „Uncomment when you move to a paid plan”.
- Redis w `render.yaml` ma `plan: free` i `ipAllowList: []`.
- `docs/stan-projektu.md` i `docs/roadmap.md` dokumentują już obserwowany skutek: warianty Active Storage generują się leniwie, zimny wariant potrafił przekroczyć timeout Vercel Image Optimization.

Impact:

- Eksporty, webhooks, email retries, Active Storage variants i inne async zadania mogą wykonywać się synchronicznie, nie wykonywać się wcale albo nie mieć niezawodnych retry/dead jobs.
- Brak worker process utrudnia odzyskanie po awarii i obserwowalność jobów.

Recommended fix:

- Przed launch: uruchomić Sidekiq worker na płatnym planie, zdefiniować queue priorities, retry policy, dead job handling i dashboard chroniony adminem/VPN.
- Upewnić się, że Redis jest persistent/odpowiedni dla jobów i idempotencji.

Verification:

- Staging: enqueue webhook delivery/export/variant generation/email; zabić worker; sprawdzić retry po restarcie i widoczność failed/dead jobs.

### SYS-010 — Webhook delivery i storefront e-mail idempotencja nie są produkcyjnie zamknięte

Severity: P1  
Area: jobs  
Status: confirmed production-readiness risk

Evidence:

- F4/F6 w roadmapie dokumentują webhook storefrontu i idempotencję e-maili opartą o `Set` w pamięci procesu w `sklepikFront`.
- Admin API/dashboard mają webhook deliveries i redelivery, ale F13 zostawił brak rotacji sekretu webhook endpointu.

Impact:

- Restart instancji może pozwolić na duplikaty e-maili. Brak rotacji sekretu utrudnia reakcję po wycieku.
- Operator może widzieć delivery, ale nadal nie mieć trwałej gwarancji exactly-once/at-least-once z idempotentnym consumerem.

Recommended fix:

- Przenieść idempotency keys do Redis/Postgres z TTL i unique constraint; dodać webhook secret rotation.
- Dla każdego webhook consumer dodać runbook: jak redeliver, jak sprawdzić payload/event_id, jak zablokować duplikaty.

Verification:

- Wysłać ten sam webhook dwa razy przed i po restarcie storefrontu; tylko jeden e-mail/skutek biznesowy.

### SYS-011 — Post-sale operations są niekompletne: refunds istnieją punktowo, ale brak lifecycle returns/reimbursements

Severity: P1  
Area: post-sale  
Status: confirmed missing feature

Evidence:

- F13 prompt 4 potwierdził tylko order-level refunds i brak pełnego Admin API/UI dla reimbursement types, refund reasons, return authorization reasons, customer returns.
- Legacy admin ma widoki returns/refunds (`spree/admin/app/views/spree/admin/shared/_returns_and_refunds_nav.html.erb`), ale custom dashboard jest docelowym panelem.

Impact:

- Merchant nie obsłuży profesjonalnie zwrotu, wymiany, częściowego reimbursement, powodów zwrotu i spójności inventory/accounting w docelowym panelu.
- Ryzyko ręcznych obejść w konsoli i niespójności danych po sprzedaży.

Recommended fix:

- Zaprojektować „post-sale operations” jako osobny vertical: return authorization → customer return → reimbursement/refund → inventory restock → customer notification → accounting notes.

Verification:

- E2E po zamówieniu: partial return, full refund, failed refund, restock/no restock, notification, admin order timeline.

### SYS-012 — Migracje nie są systematycznie idempotentne mimo efemerycznego `server/` na Renderze

Severity: P1  
Area: data  
Status: confirmed production-readiness risk

Evidence:

- `docs/deployment-render.md` wyjaśnia, że `server/` jest klonowany świeżo i migracje silnika dostają nowe timestampy, więc nowe migracje muszą być idempotentne.
- Search DDL wykazał nadal migracje bez `if_not_exists`/`if_exists`, np. `20260213000000_create_spree_payment_sessions.rb`, `20260218000000_create_spree_payment_setup_sessions.rb`, `20260123000000_create_spree_api_keys.rb`, `20260317000000_create_spree_refresh_tokens.rb`, `20260326000001_improve_spree_webhooks.rb`, część starszych metadata migrations.

Impact:

- Kolejny deploy/release może paść na duplicate table/column/index, blokując produkcję.
- Rollback/second deploy jest ryzykowny, szczególnie dla świeżych funkcji checkout/payment/auth.

Recommended fix:

- Audyt migracji z checklistą: każdy `create_table/add_column/add_index/remove_*` idempotentny albo uzasadniony jako upstream/stara migracja już obsłużona.
- Dodać CI script statyczny wykrywający DDL bez guardów w nowych migracjach.

Verification:

- W testowej bazie uruchomić release/migrations dwukrotnie z efemerycznym host-app copy i potwierdzić zero duplicate errors.

### SYS-013 — Demo/production data readiness nie ma kompletnego, testowanego seeda sprzedażowego

Severity: P1  
Area: data  
Status: likely

Evidence:

- `docs/stan-projektu.md` mówi o jednym rynku Polska/PLN/pl i 6 produktach kakao, ale braki przed sprzedażą obejmują shipping/tax/payment/policies.
- Seed payment methods tworzy tylko StoreCredit, nie Stripe.
- Brak `.env.example` w wynikach `rg --files -g '.env*' -g '*env*example*'`.

Impact:

- Fresh production deploy może mieć katalog, ale nie mieć realnego checkoutu, płatności, polityk i legalnych treści.
- Nowy operator nie wie, jakie env/seedy są minimalnie wymagane.

Recommended fix:

- Dodać `docs/production-seed-checklist.md` albo sekcję w deploy docs: market, channel, product_publications, prices, stock, shipping, tax, Stripe, policies, webhook endpoints, R2.
- Dodać `.env.example` bez sekretów dla backendu/dashboardu/storefrontu.

Verification:

- Fresh DB staging: jeden command seed/check prowadzi do zielonego checkout smoke.

### SYS-014 — Observability i incident response są niewystarczające dla typowych awarii sprzedaży

Severity: P1  
Area: observability  
Status: confirmed missing feature

Evidence:

- `render.yaml` ustawia `RAILS_LOG_LEVEL=info`, ale nie wskazuje structured logging, error monitoring, alerting ani metrics.
- `docs/stan-projektu.md` dokumentuje problemy rozpoznawane ad hoc: pusty katalog przez brak Vercel env, missing images przez cold variants, OOM Render, webhook Vercel quirk.
- Brak dedykowanego runbooka dla „checkout has no shipping rates”, „payment failed but order exists”, „missing images”, „empty catalog”.

Impact:

- Przy awarii produkcyjnej operator może stracić godziny na diagnozę i mylić cache/env/data/API, co już wydarzyło się przy pustym katalogu.

Recommended fix:

- Dodać runbooki i dashboardy: Render health/OOM, Sidekiq queues, Stripe payments, webhook deliveries, Store API catalog health, R2 image variants, Vercel env smoke.
- Dodać `/health/checkout` albo skrypt operatorski wykonujący read-only checks danych checkoutu.

Verification:

- Game-day staging: zasymulować brak env, brak shipping rate, Stripe decline, R2 timeout, backend 500 listy admina i sprawdzić, czy operator ma jednoznaczny alarm/runbook.

### SYS-015 — GDPR/legal/operational readiness nie jest domknięta

Severity: P0  
Area: legal  
Status: confirmed missing feature

Evidence:

- Store routes mają `resources :policies` w Store API, więc backend przewiduje publiczne polityki.
- `docs/stan-projektu.md` nadal wymienia brak regulaminu, polityki prywatności i prawa odstąpienia przed startem sprzedaży.
- Brak potwierdzonych mechanizmów customer data export/deletion/anonymization w custom dashboard audytach; `exports` istnieją głównie dla CSV list, nie jako GDPR workflow.

Impact:

- Sklep nie powinien startować sprzedaży w PL bez treści prawnych, polityki zwrotów, prywatności/cookies i procesu obsługi danych osobowych.
- Ryzyko regulacyjne i operacyjne niezależne od poprawności kodu.

Recommended fix:

- Przygotować i opublikować policies w Store API/storefroncie: regulamin, prywatność, cookies, odstąpienie/zwroty, kontakt.
- Zaprojektować procedurę: eksport danych klienta, anonimizacja/usunięcie, retencja logów, rozdzielenie marketing/transactional consent.

Verification:

- Manual legal QA: publiczne URLs polityk, checkboxy zgód, customer request runbook, test anonimizacji na staging.

### SYS-016 — Dashboard accessibility/responsiveness nie było objęte F12/F13; komponenty mają podstawy, ale brak audytu WCAG

Severity: P2  
Area: accessibility  
Status: unknown-needs-runtime-verification

Evidence:

- Dashboard używa Base UI/shadcn-like komponentów z labelami/aria w wielu miejscach, np. `packages/dashboard-ui/src/ui/dialog.tsx`, `sheet.tsx`, `select.tsx`, `field.tsx`.
- F12/F13 skupiały się na API/UI wiring i błędach mutacji, nie na keyboard navigation, focus trap, responsive tables, screen-reader labels, mobile/tablet.

Impact:

- Admin może być trudny lub niemożliwy do użycia klawiaturą/czytnikiem; mobile/tablet merchant operations mogą mieć ukryte akcje albo overflow.

Recommended fix:

- Przeprowadzić axe/Playwright accessibility audit dla: login, products list/edit, orders detail, checkout-ish order ops, settings webhooks/api keys, ResourceTable filters/pagination.
- Dodać standard destructive confirmations, focus return po dialogs/sheets, aria-label dla icon-only actions.

Verification:

- `@axe-core/playwright` w e2e + manual keyboard-only smoke na najważniejszych ekranach.

### SYS-017 — SDK/OpenAPI/type generation drift jest ryzykiem procesu, nie tylko kodu

Severity: P2  
Area: SDK  
Status: likely

Evidence:

- CLAUDE.md wymaga po zmianach serializerów: typelizer, Zod generation, rswag swaggerize, SDK tests.
- Ostatnie audyty i poprawki dokumentacyjne nie wykonywały pełnej pipeline typów; lokalny `tsc -b` w poprzednim przebiegu padał na workspace/type resolution zanim dotarł do realnej weryfikacji.
- Storefront używa osobnego repo i może mieć własne typy/cached SDK version.

Impact:

- Backend może zwrócić pola, których SDK/storefront nie zna, albo frontend może oczekiwać pól już zmienionych/usuniętych.
- Szczególnie ryzykowne dla Store API products/cart/payment_sessions/markets.

Recommended fix:

- W CI wymusić kontrakt: typelizer + Zod + OpenAPI + SDK tests po zmianach serializerów/kontrolerów.
- Dla `sklepikFront` pinować wersję SDK i dodać contract tests na najważniejsze payloady.

Verification:

- Pull request changing serializer fails if generated types/OpenAPI drift; storefront CI consumes generated fixture snapshots.

### SYS-018 — Media/R2/Active Storage pipeline ma potwierdzone ryzyko cold variants i brak pełnego audytu upload/security/cleanup

Severity: P1  
Area: media  
Status: confirmed production-readiness risk

Evidence:

- `docs/architektura.md` opisuje media produktów: Admin API → Active Storage → R2, public URLs przez `CDN_HOST`.
- `render.yaml` ma `CDN_HOST`, ale R2 credentials są tylko w dashboardzie Render; brak env example/checklisty.
- `docs/stan-projektu.md` opisuje zimne warianty `xlarge` generowane leniwie, timeout Vercel Image Optimization i brak workera.

Impact:

- Klient może zobaczyć brak zdjęcia lub wolny PDP/PLP; upload failures/oversized files/niebezpieczne typy plików mogą przejść niezauważone bez runtime testów.
- Brak cleanup unattached blobs może zwiększać koszty R2.

Recommended fix:

- Uruchomić worker do pre-generowania wariantów po uploadzie, dodać limity rozmiaru/typów, cleanup unattached blobs, R2 bucket policy review, cache headers/CDN validation.

Verification:

- Staging upload dużego zdjęcia i złego typu pliku; sprawdzić warianty, cache headers, czas pierwszego renderu, cleanup po porzuconym direct upload.

### SYS-019 — Admin list loading failure scenarios są potwierdzonym debt w `ResourceTable`

Severity: P1  
Area: admin UX  
Status: confirmed bug

Evidence:

- `ResourceTable` destrukturyzuje tylko `{ data, isLoading } = useQuery(...)`, nie `isError/error` (`packages/dashboard-core/src/components/resource-table.tsx`).
- Render table body rozróżnia loading vs empty, ale nie error; przy błędzie `data` jest `undefined`, więc `rows` staje się `[]` i użytkownik może zobaczyć empty state albo retry z query cache nie jest dostępne.
- `rg "<ResourceTable"` pokazuje użycie na kluczowych listach: orders, products, customers, markets, payment methods, webhooks, gift cards, stock locations/transfers, tax categories.

Impact:

- Awaria API/listy może wyglądać jak brak danych, co jest krytyczne operacyjnie: merchant nie wie, czy nie ma zamówień, czy API padło.

Recommended fix:

- W `ResourceTable` obsłużyć `isError/error/refetch`: ErrorState z retry, rozróżnienie empty vs error, zachowanie filtrów/paginacji.
- Dodać test component/unit i e2e mocking 500 dla listy orders/products.

Verification:

- MSW/Playwright: `/orders` zwraca 500 → użytkownik widzi błąd + retry, nie pustą tabelę.

### SYS-020 — Admin dashboard deploy jest single-origin proxy do backendu, ale brak env/config guardów i runbooka Vercel

Severity: P2  
Area: infrastructure  
Status: confirmed configuration risk

Evidence:

- `packages/dashboard/vercel.json` przepina `/api/:path*` i `/rails/:path*` na `https://kakaowy-sklepik.onrender.com`, a resztę na SPA `index.html`.
- `docs/stan-projektu.md` dokumentuje Vercel webhook quirk oraz wcześniejszy problem z brakującymi env dla storefrontu.
- Brak `.env.example` i brak jawnej listy wymaganych Vercel env dla storefront/dashboard w repo `sklepik`.

Impact:

- Przeniesienie domeny/backendu albo zmiana Render host wymaga ręcznej edycji configu; brak guardów może skutkować cichymi błędami w produkcji.

Recommended fix:

- Dodać deploy checklistę Vercel: required envs, rewrite target, smoke URLs, manual redeploy workaround, custom domain plan.
- Rozważyć env-driven backend URL w build/deploy lub test sprawdzający rewrite target.

Verification:

- CI/lint config: sprawdź czy production rewrite host zgadza się z dokumentacją; manual smoke po deployu dashboardu: login, `/api/v3/admin/store`, media `/rails/active_storage`.

## Flow audit: customer checkout

**Czy realny klient może dziś potwierdzonym flow przejść catalog → PDP → cart → checkout → shipping → tax → payment → order confirmation → e-mail/webhook → fulfillment?**  
**Niepotwierdzone i w obecnym stanie `Not production-ready`.**

- **Catalog/PDP:** dokumentacja mówi, że storefront renderuje katalog i PDP z Store API, ale kod `sklepikFront` nie był dostępny. Pierwszy etap wymaga osobnej weryfikacji w repo storefrontu.
- **Cart:** Store API ma cart create/update/items routes i kontrolery. Statycznie wygląda, że cart API istnieje.
- **Shipping/tax:** pierwszy twardy blocker po stronie tego repo. Brak Admin API/UI dla shipping methods/categories/zones/tax rates oznacza brak bezpiecznej konfiguracji merchant-facing.
- **Payment:** drugi twardy blocker. Store API ma payment sessions, ale produkcyjny Stripe/live config nie jest potwierdzony, a seed tworzy tylko StoreCredit.
- **Order confirmation/e-mail/webhooks:** webhooki są częściowo skonfigurowane, ale storefront e-mail idempotencja jest nietrwała, a worker Sidekiq jest wyłączony.
- **Fulfillment:** admin order/fulfillment istnieje częściowo, ale F12 wykazał `fulfillments#resume/#split` bez UI, a pełny post-sale lifecycle nie jest domknięty.

## Permission matrix summary

| Obszar / akcja      | Backend/API evidence                                    | UI evidence                     | Gaps                                                      |
| ------------------- | ------------------------------------------------------- | ------------------------------- | --------------------------------------------------------- |
| Super admin / owner | `Spree::PermissionSets::SuperUser`, CanCanCan `Ability` | Staff/API keys/settings screens | Brak self/last-admin guardu                               |
| Staff management    | `AdminUsersController` + `RoleGrantGuard`               | `settings/staff`                | Potrzebne testy matrixy per rola i store                  |
| API keys            | `ApiKeysController`, scope guard                        | `settings/api-keys`             | Scope matrix i rotation/revoke e2e do testów              |
| Orders/payments     | Order/payment controllers + permission sets             | Orders detail                   | Stripe/live/refund matrix niezweryfikowana                |
| Products/catalog    | Product permission sets                                 | Products screens                | Hidden UI fields są decyzją produktową                    |
| Config/webhooks     | Webhook controllers                                     | Settings webhooks               | Brak rotacji sekretu                                      |
| Cross-store access  | Wiele scope używa `current_store` i `accessible_by`     | Brak pełnego UI testu           | Wymaga request specs multi-store dla kluczowych endpoints |

## Store API contract risks

- Store API ma bogate routes dla products/categories/carts/markets/policies/customer, ale storefront repo nie zostało zweryfikowane przeciw aktualnemu payloadowi.
- Największe ryzyka driftu: products availability (`product_publications`, stock, price PLN), market/currency/locale fallback, cache/revalidation po cenie/rynku, payment_sessions shape, cart completion errors.
- Potrzebne są fixture snapshots i consumer tests po stronie `sklepikFront`.

## Production operations checklist

- **Payment dashboard:** Stripe test/live keys, webhook signature, failed payments, refund/void/capture runbook.
- **Sidekiq dashboard:** worker running, queues, retry/dead jobs, Redis health.
- **Logs/errors:** Render logs, structured request IDs, error monitoring, OOM/cold start alerting.
- **Webhooks:** endpoint health, secret rotation, redelivery, idempotent consumers, event subscription runbook.
- **E-mails:** transactional provider, retry/idempotency, templates, duplicate prevention after restart.
- **Catalog/images:** Store API health, publication/price/stock readiness, R2/Active Storage variants, cache headers.
- **Checkout health:** daily smoke: product → cart → address → shipping rate → Stripe test payment → complete.
- **Backups/data:** Postgres backup/restore test, migration double-run test, seed checklist.
- **Incident runbook:** empty catalog, missing images, no shipping rates, payment failed/order exists, dashboard list 500.

## Recommended roadmap

### Must fix before production

- Shipping/tax/zones/payment production configuration and verified checkout smoke.
- Stripe live/test setup with webhook verification and payment failure/refund/capture/void scenarios.
- Legal pages/policies and GDPR/customer data procedures.
- Sidekiq worker + async reliability for webhooks/e-mails/media/exports.
- `ResourceTable` error states for admin list failures.

### Should fix before production

- Self/last-admin guard and permission matrix tests.
- Store API/storefront contract tests, especially product availability and market/currency/locale.
- Migration idempotency audit and CI guard.
- Observability/runbooks for checkout/payments/catalog/images.
- Media/R2 pipeline hardening and variant pre-generation.

### Can fix after launch

- Advanced performance budgets for large catalogs, webhook delivery aggregate optimizations, export memory profiling.
- Full accessibility audit remediation beyond blockers.
- More granular role UI polish once backend guards are complete.

### Needs product/legal decision

- Czy store credit categories są seedowane czy edytowalne.
- Czy wishlist/digital downloads mają panel administracyjny.
- Zwroty/wymiany/reimbursements docelowy proces biznesowy.
- Polityki prawne, fakturowanie/VAT, retention/anonymization.
- Multi-market/multi-currency launch scope.

## Appendix

### Useful grep/search notes

- Storefront repo search: `find / -maxdepth 3 -type d -iname '*sklepik*'` → only `/workspace/sklepik`.
- Checkout/payment routes: `sed -n '1,120p' spree/api/config/routes.rb`.
- Cart/payment code: `spree/api/app/controllers/spree/api/v3/store/carts_controller.rb`, `carts/payments_controller.rb`, `carts/payment_sessions_controller.rb`, `carts/fulfillments_controller.rb`.
- Stripe/payment evidence: `rg -n "Stripe|stripe|PaymentMethod|payment_sessions" Gemfile spree packages docs render.yaml`.
- ResourceTable error handling: `rg -n "useQuery|isLoading|isError|error" packages/dashboard-core/src/components/resource-table.tsx`.
- Migration risk: `rg -n "create_table|add_column|add_index|remove_index|remove_column" spree/core/db/migrate`.
- Infra evidence: `render.yaml`, `packages/dashboard/vercel.json`, `docs/deployment-render.md`, `docs/architektura.md`.

### Important uncertainties

- Nie potwierdzono runtime secrets/config: Stripe, R2, SMTP, Vercel env, webhook secrets.
- Nie potwierdzono realnych rekordów DB dla shipping/tax/payment/policies.
- Nie potwierdzono storefront code paths, bo repo `sklepikFront` nie było dostępne.
- Nie uruchomiono testów obciążeniowych ani staging checkout.
