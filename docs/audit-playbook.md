# Audyt panelu — playbook i mapa pokrycia

**Cel dokumentu:** to nie jest jednorazowa notatka ze statusem — to żywy, powtarzalny proces. Za każdym razem gdy odpalasz agenta audytującego, wraca tutaj: sprawdza mapę pokrycia (co już zbadane), bierze kolejny gotowy prompt, a po skończeniu **aktualizuje mapę pokrycia w tym pliku**, żeby następny audyt (Twój albo agenta) wiedział, gdzie zacząć.

## Skąd to się wzięło

2026-07-07: dwa niezależne znaleziska tego samego kształtu w jednej sesji — `Store#logo` istniał w API od dawna, ale panel nie miał pola do wgrania (F10); `Spree::Products::ReadinessCheck` istniał i był przetestowany, ale zero konsumentów w panelu (F3). To nie przypadek, to wzorzec: **backend robi się poprawnie, ale nikt nie sprawdza czy front faktycznie z tego korzysta**. Zlecony pierwszy systematyczny audyt (F12) potwierdził wzorzec — znalazł i naprawił realną lukę bezpieczeństwa operacyjnego (ciche błędy przy płatnościach) plus trzy martwe funkcje. Ten playbook koduje tamten proces, żeby dało się go powtarzać bez każdorazowego wymyślania promptu od zera.

## Metodologia — trzy wzorce

Każdy audyt (cały panel albo jeden obszar) sprawdza te same trzy rzeczy:

**Wzorzec 1 — asymetria odczyt/zapis.** Dla każdego pola które serializer (`spree/api/app/serializers/spree/api/v3/admin/*.rb`) zwraca przez `attribute`/`attributes` — czy istnieje droga żeby to pole zapisać? Sprawdź `permitted_params` w kontrolerze ORAZ czy panel ma faktyczny input dla tego pola. Pole które API zwraca, ale nic nie potrafi ustawić (albo odwrotnie: UI pozwala edytować coś czego API i tak zignoruje) — to dokładnie kształt buga z logo.

**Wzorzec 2 — martwe endpointy backendu.** Dla każdej akcji w kontrolerze (`spree/api/app/controllers/spree/api/v3/admin/*_controller.rb`) — czy `packages/` gdziekolwiek się do niej odwołuje (metoda SDK, hook, wywołanie w routes)? Zero trafień = funkcja istnieje i jest przetestowana, ale sprzedawca nie ma jak z niej skorzystać. Dokładnie kształt buga z readiness check.

**Wzorzec 3 — ciche błędy przy zapisie.** Dla każdego `.mutateAsync(...)` (albo podobnego wywołania mutacji) w `packages/dashboard/src/routes/**/*.tsx` — czy jest poprawnie `await`-owane w `try/catch`, czy catch faktycznie pokazuje błąd (`mapSpreeErrorsToForm` i/lub `toast.error`), czy może błąd znika po cichu i UI wygląda na sukces mimo porażki? Wzorzec referencyjny (jak to powinno wyglądać): `packages/dashboard/src/routes/_authenticated/$storeId/settings/emails.tsx` (`onSubmit`).

## Mapa pokrycia

Legenda: ✅ sprawdzone i czyste (albo naprawione) · ⚠️ sprawdzone, są znaleziska nienaprawione (patrz link) · ⬜ nietknięte.

| Obszar | Wzorzec 1 (symetria) | Wzorzec 2 (martwe endpointy) | Wzorzec 3 (ciche błędy) | Data / źródło |
|---|---|---|---|---|
| Zamówienia (orders, fulfillments, płatności, zwroty) | ✅ | ⚠️ `resume`/`split` bez UI | ✅ naprawione | 2026-07-07, F12 |
| Klienci (customers) | ✅ (martwe `avatar`/`selected_locale`, nieszkodliwe) | — | ✅ naprawione | 2026-07-07, F12 |
| Media wariantów | — | — | ✅ naprawione | 2026-07-07, F12 |
| Promocje (promotions) | ✅ | — | ✅ czyste | 2026-07-07, F12 |
| Cenniki (price lists) | — | ⚠️ `#prices` bez trasy w ogóle | — | 2026-07-07, F12 |
| Metody płatności | ✅ | — | ✅ czyste | 2026-07-07, F12 |
| Lokalizacje magazynowe | ✅ (w tym `pickup_*`) | — | ✅ czyste | 2026-07-07, F12 |
| Kanały dystrybucji (channels) | — | ⚠️ zero UI do przypisania produktów | — | 2026-07-07, F12 |
| Ustawienia sklepu — logo | ✅ naprawione (F10) | ✅ naprawione (F10) | — | 2026-07-07, F10 |
| Produkty — gotowość do sprzedaży | — | ✅ naprawione (F3, wcześniej) | — | 2026-07-07, F3 |
| Produkty, warianty, opcje, taksonomie/kategorie (pełny przegląd) | ⬜ | ⬜ | ⬜ | — |
| Wysyłka, strefy, podatki, transfery magazynowe | ⬜ | ⬜ | ⬜ | — |
| Użytkownicy admina, role, uprawnienia, klucze API, zaproszenia | ⬜ | ⬜ | ⬜ | — |
| Karty podarunkowe, kredyt sklepowy, zwroty (głębiej), listy życzeń, pobrania cyfrowe | ⬜ | ⬜ | ⬜ | — |
| Webhooks, custom fields, tłumaczenia, feedy danych, rynki (głębiej) | ⬜ | ⬜ | ⬜ | — |

**Zasada aktualizacji:** po każdym audycie — zmień ⬜/⚠️ na ✅ albo ⚠️ z linkiem do konkretnego znaleziska (numer zadania w `roadmap.md` albo numer PR-a), dopisz datę. Nie usuwaj wierszy nawet w pełni domkniętych — to jest historia pokrycia, nie tylko dzisiejszy stan.

## Jak odpalić kolejny audyt

1. Sprawdź mapę pokrycia wyżej — wybierz wiersz z ⬜ (priorytet) albo ⚠️ (dokończenie).
2. Jeśli jeden z pięciu gotowych promptów niżej pokrywa ten obszar — skopiuj go 1:1 do nowego agenta (Task/Agent tool, `run_in_background: true`, `subagent_type: general-purpose`).
3. Jeśli żaden nie pasuje (nowy obszar, którego tu nie przewidzieliśmy) — skopiuj **Szablon ogólny** poniżej i wypełnij nawiasy kwadratowe.
4. Po skończeniu audytu: zaktualizuj mapę pokrycia w tym pliku, dodaj znaleziska do `roadmap.md` (nowe zadanie F-cokolwiek albo rozszerzenie istniejącego), zaktualizuj `stan-projektu.md` jeśli zmienia obraz "co działa".

## Szablon ogólny (do nowych obszarów spoza pięciu gotowych)

```
This is the "Kakałowy Sklepik" e-commerce project — Spree Commerce backend
(spree/api, spree/core) + custom React/Vite admin dashboard
(packages/dashboard, packages/dashboard-core, packages/admin-sdk) at
/home/user/sklepik, repo pawelekbyra/sklepik, branch [BRANCH_NAME].
Read /home/user/sklepik/CLAUDE.md and /home/user/sklepik/docs/audit-playbook.md
first — the playbook explains the three audit patterns you're checking for
and has a coverage map showing what's already been audited (don't repeat it).

Your area for this audit: [OBSZAR — np. "wysyłka, strefy, podatki"].
Resources in scope: [LISTA ZASOBÓW — np. "Spree::ShippingMethod, Spree::Zone,
Spree::TaxCategory, Spree::TaxRate, stock transfers"].

Check all three patterns from the playbook for this area:
1. Read/write symmetry — serializer fields vs permitted_params vs dashboard UI.
2. Dead backend endpoints — controller actions with zero references in packages/.
3. Silent-failure mutations — every .mutateAsync in the relevant dashboard
   routes properly try/caught and surfaced via toast/mapSpreeErrorsToForm.

Fix what's small, safe, and matches an established pattern already in this
codebase. Report anything larger (needs a product/UI decision) as a finding
instead of implementing it unattended.

Constraints: run `git status` first, don't touch files already
modified/untracked that aren't yours. Commit locally with clear messages as
you go. Do NOT push or open a PR. Follow CLAUDE.md's doc protocol — update
docs/stan-projektu.md / docs/roadmap.md for anything you close, and update
the coverage table in docs/audit-playbook.md for this area.

Deliverable: structured report per pattern (findings, fixed-or-not,
recommendation), plus confirmation you updated the coverage table.
```

---

## Prompciki audytujące

Gotowe do wklejenia 1:1 w nowego agenta. Każdy pokrywa jeden wiersz z mapy pokrycia oznaczony ⬜. Podmień tylko `[BRANCH_NAME]` na aktualną nazwę brancha.

### 1. Katalog — produkty, warianty, opcje, taksonomie

```
This is the "Kakałowy Sklepik" e-commerce project — Spree Commerce backend
(spree/api, spree/core) + custom React/Vite admin dashboard
(packages/dashboard, packages/dashboard-core, packages/admin-sdk) at
/home/user/sklepik, repo pawelekbyra/sklepik, branch [BRANCH_NAME].
Read /home/user/sklepik/CLAUDE.md and /home/user/sklepik/docs/audit-playbook.md
first — the playbook explains the three audit patterns and has a coverage
map of what's already been audited today (orders, customers, promotions,
pricing, payment methods, stock locations, store logo, product readiness —
don't repeat those).

Your area: the core catalog — Spree::Product, Spree::Variant,
Spree::OptionType/OptionValue, Spree::Taxon/Taxonomy (categories),
Spree::Asset/media beyond what today's variant-media-picker fix covered.
This is the highest-traffic area of the admin panel and hasn't had a
systematic pass yet (only the narrow readiness-check gap was fixed earlier).

Check all three patterns from the playbook:
1. Read/write symmetry — every field Spree::Api::V3::Admin::ProductSerializer
   / VariantSerializer / OptionTypeSerializer / TaxonSerializer exposes: is
   it in the matching controller's permitted_params AND does the dashboard
   product/variant/taxonomy forms actually expose an input for it?
2. Dead backend endpoints — every action in products_controller.rb,
   variants_controller.rb, option_types_controller.rb, taxons_controller.rb,
   taxonomies_controller.rb: grep packages/ for any reference (SDK method,
   hook, route). Pay special attention to bulk operations, reordering
   (acts_as_list), and any product-variant relationship management endpoints.
3. Silent-failure mutations — every .mutateAsync in
   packages/dashboard/src/routes/_authenticated/$storeId/products/**/*.tsx
   and any taxonomy/category routes: properly try/caught and surfaced?

Fix what's small, safe, and matches an established pattern already in this
codebase (e.g. the useOrderMutation onError fix, or useResourceMutation
adoption, from today's audit — check `git log` for those commits if useful
context). Report anything larger as a finding instead.

Constraints: `git status` first, don't touch anything already
modified/untracked that isn't yours. Commit locally with clear messages.
Do NOT push or open a PR. Update docs/stan-projektu.md / docs/roadmap.md for
anything you close, and update the coverage table in
docs/audit-playbook.md — change the "Produkty, warianty, opcje,
taksonomie/kategorie" row from ⬜ to ✅/⚠️ with today's date and a link to
what you found/fixed.

Deliverable: structured report per pattern (findings, fixed-or-not,
recommendation), confirmation the coverage table is updated.
```

### 2. Wysyłka, podatki, strefy, transfery magazynowe

```
This is the "Kakałowy Sklepik" e-commerce project — Spree Commerce backend
(spree/api, spree/core) + custom React/Vite admin dashboard
(packages/dashboard, packages/dashboard-core, packages/admin-sdk) at
/home/user/sklepik, repo pawelekbyra/sklepik, branch [BRANCH_NAME].
Read /home/user/sklepik/CLAUDE.md and /home/user/sklepik/docs/audit-playbook.md
first — the playbook explains the three audit patterns and has a coverage
map of what's already been audited (don't repeat orders, customers,
promotions, pricing, payment methods, stock locations, store logo, product
readiness).

Your area: everything that determines how much a customer actually pays and
whether an order can physically ship — Spree::ShippingMethod, Spree::Zone,
Spree::ShippingCategory, Spree::TaxCategory, Spree::TaxRate, and stock
transfers (Spree::StockTransfer). Money-critical: a gap here means wrong
charges or undeliverable orders, not just a missing convenience feature.

Check all three patterns from the playbook:
1. Read/write symmetry — shipping method/zone/tax serializers vs
   permitted_params vs dashboard forms (settings/shipping*.tsx,
   settings/tax*.tsx or wherever they live — find them first).
2. Dead backend endpoints — every controller action for these resources:
   grep packages/ for references. Pay attention to zone-country/state
   membership management, tax rate calculator configuration, and stock
   transfer receive/ship actions.
3. Silent-failure mutations — every .mutateAsync touching these resources
   in the dashboard: properly try/caught and surfaced via toast or
   mapSpreeErrorsToForm?

Fix what's small, safe, and matches an established pattern already in this
codebase. Report anything larger (needs a product/UI decision) as a finding
instead of implementing it unattended — this area is money-sensitive, so
when in doubt, report rather than guess.

Constraints: `git status` first, don't touch anything already
modified/untracked that isn't yours. Commit locally with clear messages.
Do NOT push or open a PR. Update docs/stan-projektu.md / docs/roadmap.md for
anything you close, and update the coverage table in
docs/audit-playbook.md — change the "Wysyłka, strefy, podatki, transfery
magazynowe" row from ⬜ to ✅/⚠️ with today's date and a link to what you
found/fixed.

Deliverable: structured report per pattern (findings, fixed-or-not,
recommendation), confirmation the coverage table is updated.
```

### 3. Bezpieczeństwo panelu — użytkownicy, role, klucze API

```
This is the "Kakałowy Sklepik" e-commerce project — Spree Commerce backend
(spree/api, spree/core) + custom React/Vite admin dashboard
(packages/dashboard, packages/dashboard-core, packages/admin-sdk) at
/home/user/sklepik, repo pawelekbyra/sklepik, branch [BRANCH_NAME].
Read /home/user/sklepik/CLAUDE.md and /home/user/sklepik/docs/audit-playbook.md
first — the playbook explains the three audit patterns and has a coverage
map of what's already been audited (don't repeat orders, customers,
promotions, pricing, payment methods, stock locations, store logo, product
readiness).

Your area: everything controlling who can access what — Spree::AdminUser,
Spree::Role, Spree::RoleUser, CanCanCan ability definitions, API keys
(Spree::ApiKey / admin secret keys with scopes), and admin invitations. This
is security-critical and has had ZERO systematic review so far — treat
findings here with higher severity than a UI convenience gap.

Check all three patterns from the playbook, but weight them differently
given the security angle:
1. Read/write symmetry — admin_users/roles/invitations/api_keys serializers
   vs permitted_params vs dashboard UI. Specifically check: can the UI
   assign/revoke roles and API key scopes precisely, or is there a gap
   between what the backend allows and what an admin can actually configure
   (over- or under-provisioning risk)?
2. Dead backend endpoints — every action in admin_users_controller.rb,
   invitations_controller.rb, api_keys_controller.rb, and any
   roles-related controller: grep packages/ for references. Also check
   whether CanCanCan abilities actually gate every action they should — a
   missing `authorize!` call is worth flagging even though it's not
   literally one of the three patterns, it's the same "backend capability
   the UI doesn't fully control" shape.
3. Silent-failure mutations — invite/revoke/role-change/API-key-rotate
   flows: does a failure (e.g. inviting an already-invited email, revoking
   your own last-admin access) surface clearly, or fail silently in a way
   that could leave the store in a confusing access state?

Given the sensitivity, do NOT auto-fix anything here beyond trivial,
obviously-safe UI wiring (e.g. a missing toast). Anything touching
authorization logic, permitted_params for roles/scopes, or CanCanCan
abilities should be reported as a finding with a clear recommendation, not
implemented unattended.

Constraints: `git status` first, don't touch anything already
modified/untracked that isn't yours. Commit locally (only for the trivial
fixes described above) with clear messages. Do NOT push or open a PR.
Update docs/stan-projektu.md / docs/roadmap.md for anything you close or
flag, and update the coverage table in docs/audit-playbook.md — change the
"Użytkownicy admina, role, uprawnienia, klucze API, zaproszenia" row from ⬜
to ✅/⚠️ with today's date and a link to what you found.

Deliverable: structured report per pattern (findings, fixed-or-not,
recommendation), confirmation the coverage table is updated. Flag anything
you consider a genuine security risk clearly at the top of the report, not
buried in a list.
```

### 4. Pieniądze klienta — karty podarunkowe, kredyt sklepowy, zwroty, listy życzeń, pobrania cyfrowe

```
This is the "Kakałowy Sklepik" e-commerce project — Spree Commerce backend
(spree/api, spree/core) + custom React/Vite admin dashboard
(packages/dashboard, packages/dashboard-core, packages/admin-sdk) at
/home/user/sklepik, repo pawelekbyra/sklepik, branch [BRANCH_NAME].
Read /home/user/sklepik/CLAUDE.md and /home/user/sklepik/docs/audit-playbook.md
first — the playbook explains the three audit patterns and has a coverage
map of what's already been audited (don't repeat orders, customers,
promotions, pricing, payment methods, stock locations, store logo, product
readiness; note that basic gift-card/store-credit APPLY-to-order actions on
the order detail page were already fixed for silent failures today — this
audit is about the ADMIN-SIDE management of these resources, not their use
within an order).

Your area: Spree::GiftCard (admin issuing/management, not applying to an
order), Spree::StoreCredit (admin issuing/adjusting, not applying),
Spree::Reimbursement / refund flows beyond what was fixed today on the
order detail page (check reimbursement_type, customer_return, refund_reason
management specifically), Spree::Wishlist, and digital downloads
(Spree::Digital / Spree::DigitalLink). These are all customer-money-adjacent
areas that haven't been systematically checked.

Check all three patterns from the playbook:
1. Read/write symmetry — serializers for these resources vs
   permitted_params vs dashboard UI (if a dashboard UI exists at all for
   some of these — that itself is worth checking, e.g. does the panel even
   have a screen to manually issue a gift card or adjust store credit?).
2. Dead backend endpoints — controller actions for these resources: grep
   packages/ for references.
3. Silent-failure mutations — any .mutateAsync in the dashboard touching
   these resources: properly try/caught and surfaced?

Fix what's small, safe, and matches an established pattern already in this
codebase. Report anything larger (especially "no UI exists for X at all")
as a finding instead of building new UI unattended.

Constraints: `git status` first, don't touch anything already
modified/untracked that isn't yours. Commit locally with clear messages.
Do NOT push or open a PR. Update docs/stan-projektu.md / docs/roadmap.md for
anything you close, and update the coverage table in
docs/audit-playbook.md — change the "Karty podarunkowe, kredyt sklepowy,
zwroty (głębiej), listy życzeń, pobrania cyfrowe" row from ⬜ to ✅/⚠️ with
today's date and a link to what you found/fixed.

Deliverable: structured report per pattern (findings, fixed-or-not,
recommendation), confirmation the coverage table is updated.
```

### 5. Konfiguracja i integracje — webhooks, custom fields, tłumaczenia, feedy danych, rynki

```
This is the "Kakałowy Sklepik" e-commerce project — Spree Commerce backend
(spree/api, spree/core) + custom React/Vite admin dashboard
(packages/dashboard, packages/dashboard-core, packages/admin-sdk) at
/home/user/sklepik, repo pawelekbyra/sklepik, branch [BRANCH_NAME].
Read /home/user/sklepik/CLAUDE.md and /home/user/sklepik/docs/audit-playbook.md
first — the playbook explains the three audit patterns and has a coverage
map of what's already been audited (don't repeat orders, customers,
promotions, pricing, payment methods, stock locations, store logo, product
readiness).

Your area: operational/config surfaces — webhook endpoint configuration
(Spree::WebhookEndpoint/subscriber management — note the storefront side of
webhooks was audited separately in the sklepikFront repo, this is only the
admin-side config UI), custom fields / custom field definitions
(Spree::Metafield-related), the translations resource
(translatable_resources, translations/batches), data feeds
(Spree::DataFeed), and Spree::Market management beyond the already-known
currency-switcher-is-empty bug (docs/stan-projektu.md point 10 — verify if
still true, don't just assume; if you fix it, note that in your report
since it closes an existing known-issue line item, not just a new finding).

Check all three patterns from the playbook:
1. Read/write symmetry — serializers for these resources vs
   permitted_params vs dashboard UI.
2. Dead backend endpoints — controller actions for webhook endpoints,
   custom field definitions, translations batch endpoint, data feeds,
   markets: grep packages/ for references.
3. Silent-failure mutations — any .mutateAsync touching these resources in
   the dashboard: properly try/caught and surfaced? Pay particular
   attention to the translations/batches endpoint (it's a batch operation —
   a partial failure needs to be surfaced per-item, not just as one generic
   toast) and to webhook endpoint secret rotation (a failed rotation should
   never silently leave the old secret in an ambiguous state).

Fix what's small, safe, and matches an established pattern already in this
codebase. Report anything larger as a finding instead.

Constraints: `git status` first, don't touch anything already
modified/untracked that isn't yours. Commit locally with clear messages.
Do NOT push or open a PR. Update docs/stan-projektu.md / docs/roadmap.md for
anything you close (including point 10's currency-switcher issue if you
investigate and resolve it), and update the coverage table in
docs/audit-playbook.md — change the "Webhooks, custom fields, tłumaczenia,
feedy danych, rynki (głębiej)" row from ⬜ to ✅/⚠️ with today's date and a
link to what you found/fixed.

Deliverable: structured report per pattern (findings, fixed-or-not,
recommendation), confirmation the coverage table is updated.
```
