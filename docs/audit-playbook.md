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

| Obszar                                                                               | Wzorzec 1 (symetria)                                         | Wzorzec 2 (martwe endpointy)             | Wzorzec 3 (ciche błędy)               | Data / źródło   |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------ | ---------------------------------------- | ------------------------------------- | --------------- |
| Zamówienia (orders, fulfillments, płatności, zwroty)                                 | ✅                                                           | ⚠️ `resume`/`split` bez UI               | ✅ naprawione                         | 2026-07-07, F12 |
| Klienci (customers)                                                                  | ✅ (martwe `avatar`/`selected_locale`, nieszkodliwe)         | —                                        | ✅ naprawione                         | 2026-07-07, F12 |
| Media wariantów                                                                      | —                                                            | —                                        | ✅ naprawione                         | 2026-07-07, F12 |
| Promocje (promotions)                                                                | ✅                                                           | —                                        | ✅ czyste                             | 2026-07-07, F12 |
| Cenniki (price lists)                                                                | —                                                            | ⚠️ `#prices` bez trasy w ogóle           | —                                     | 2026-07-07, F12 |
| Metody płatności                                                                     | ✅                                                           | —                                        | ✅ czyste                             | 2026-07-07, F12 |
| Lokalizacje magazynowe                                                               | ✅ (w tym `pickup_*`)                                        | —                                        | ✅ czyste                             | 2026-07-07, F12 |
| Kanały dystrybucji (channels)                                                        | —                                                            | ⚠️ zero UI do przypisania produktów      | —                                     | 2026-07-07, F12 |
| Ustawienia sklepu — logo                                                             | ✅ naprawione (F10)                                          | ✅ naprawione (F10)                      | —                                     | 2026-07-07, F10 |
| Produkty — gotowość do sprzedaży                                                     | —                                                            | ✅ naprawione (F3, wcześniej)            | —                                     | 2026-07-07, F3  |
| Produkty, warianty, opcje, taksonomie/kategorie (pełny przegląd)                     | ⚠️ pola operacyjne bez UI (F13)                              | ✅ istniejące endpointy mają konsumentów | ✅ czyste                             | 2026-07-08, F13 |
| Wysyłka, strefy, podatki, transfery magazynowe                                       | ⚠️ brak API/UI dla shipping/zone/tax rates (F13)             | ✅ istniejące endpointy użyte            | ✅ czyste                             | 2026-07-08, F13 |
| Użytkownicy admina, role, uprawnienia, klucze API, zaproszenia                       | ⚠️ self/last-admin lockout risk (F13)                        | ✅ istniejące endpointy użyte            | ✅ czyste                             | 2026-07-08, F13 |
| Karty podarunkowe, kredyt sklepowy, zwroty (głębiej), listy życzeń, pobrania cyfrowe | ⚠️ refundy/zwroty/wishlisty/digital bez pełnego admina (F13) | ⚠️ wishlist/digital bez Admin API/UI     | ✅ naprawiono store-credit toast      | 2026-07-08, F13 |
| Webhooks, custom fields, tłumaczenia, feedy danych, rynki (głębiej)                  | ⚠️ brak rotacji sekretu webhooka / decyzje feedów (F13)      | ⚠️ data feeds bez Admin API/UI           | ⚠️ tłumaczenia pokazują błąd batchowo | 2026-07-08, F13 |

**Zasada aktualizacji:** po każdym audycie — zmień ⬜/⚠️ na ✅ albo ⚠️ z linkiem do konkretnego znaleziska (numer zadania w `roadmap.md` albo numer PR-a), dopisz datę. Nie usuwaj wierszy nawet w pełni domkniętych — to jest historia pokrycia, nie tylko dzisiejszy stan.

## Wyniki audytów obszarowych

### 2026-07-08 — F13, prompt 1: katalog produktów, wariantów, opcji i kategorii

**Zakres:** `Spree::Product`, `Spree::Variant`, `Spree::OptionType`/`OptionValue`, `Spree::Category`/taxony oraz media produktów/wariantów w Admin API i dashboardzie. Audyt wykonano według trzech wzorców z playbooka, bez zmian core i bez zmian kontraktu Store API.

**Wzorzec 1 — read/write symmetry.** Wynik: **⚠️ sprawdzone, są świadome luki UI/operacyjne; brak małej bezpiecznej poprawki do zrobienia bez decyzji produktowej.**

- Produkty mają poprawną ścieżkę zapisu dla głównych pól katalogowych: `name`, `description`, `slug`, `status`, SEO, `tax_category_id`, `tags`, `category_ids`, `media`, `variants`, `product_publications` i `custom_fields` są permitowane przez `ProductsController#permitted_params`, a formularz produktu posiada odpowiadające im sekcje lub wyspecjalizowane komponenty. Pola `available_on`, `promotionable`, `digital` i `meta_keywords` są permitowane/serializowane, ale panel nie wystawia ich jako inputów. To nie jest bug zapisu API, tylko brak decyzji UI: czy merchant ma ręcznie sterować datą dostępności, wyłączeniem promocji, cyfrowością produktu i słowami kluczowymi, czy te pola zostają ukryte pod MVP.
- Warianty mają kompletne API dla pól handlowych (`sku`, `barcode`, wymiary, waga, jednostki, ceny, stock, `track_inventory`, preorder, backorder, kategoria podatkowa, pozycja, media), a formularz produktu obsługuje warianty inline. Pola admin-only `cost_price`/`cost_currency` są serializowane i permitowane, ale dashboard nie ma inputów kosztu własnego. To kandydat do osobnej decyzji: marża/raportowanie vs prostszy MVP.
- `OptionType`/`OptionValue`: nazwa, label, typ/kind, `filterable`, wartości, sortowanie i media wartości opcji są obsłużone w panelu. Serializer admina eksponuje `metadata`, ale kontroler opcji nie permituje `metadata`, a UI go nie pokazuje. To nieszkodliwa asymetria techniczna, dopóki nie ma ogólnego edytora metadanych.
- Kategorie mają formularz dla nazwy, parenta, opisu, permalinku, obrazów, SEO title/description i custom fields; endpoint obsługuje też `meta_keywords` i `hide_from_nav`, których panel nie wystawia. `pretty_name`, `lft`/`rgt`, `products_count`, `children_count` i flagi drzewa są polami odczytowymi — prawidłowo bez inputów.

**Wzorzec 2 — martwe endpointy.** Wynik: **✅ istniejące endpointy katalogowe mają konsumentów.**

- `products#clone`, `products#readiness`, bulk status/kategorie/kanały/tagi/destroy, media produktów, media wariantów, CRUD opcji, CRUD/reposition kategorii i membership produktów w kategorii mają referencje w `packages/` przez `@spree/admin-sdk`, hooki i/lub trasy dashboardu.
- Top-level `Admin::VariantsController` (`/api/v3/admin/variants`) też ma realnego konsumenta: kreator transferu magazynowego wyszukuje warianty przez `adminClient.variants.list(...)`, więc endpoint nie jest martwy. Ewentualny pełny globalny widok SKU/inventory pozostaje decyzją produktową, ale nie jest blokującą luką w dostępności endpointu.

**Wzorzec 3 — ciche błędy mutacji.** Wynik: **✅ czyste w audytowanym obszarze.**

- Tworzenie/edycja produktu i kategorii używają `try/catch` z `mapSpreeErrorsToForm` oraz toastem fallbackowym.
- Mutacje bulk na liście produktów idą przez wspólny mechanizm bulk actions z komunikatami sukcesu/błędu.
- Mutacje opcji, mediów produktu/wariantu i przypisań produktów do kategorii korzystają z `useResourceMutation` albo lokalnego `try/catch` z toastem. Miejsca z `.catch(() => undefined)` w tym obszarze są owinięte hookiem, który sam wyświetla `errorMessage`, więc nie są cichym błędem w sensie F12.

**Rekomendacja:** nie naprawiano nic automatycznie, bo znalezione luki dotyczą decyzji produktowej/UI, nie oczywistej awarii. Najpilniejsze potencjalne prace następcze: (1) zdecydować, czy product form ma wystawiać `available_on`, `promotionable`, `digital`, `meta_keywords`; (2) zdecydować, czy dashboard ma pokazywać koszt własny wariantu; (3) dopiero przy potrzebie edycji surowych metadanych dodać spójny edytor `metadata`, zamiast pojedynczo odkrywać pola techniczne.

### 2026-07-08 — F13, prompt 2: wysyłka, strefy, podatki i transfery magazynowe

**Zakres:** `Spree::ShippingMethod`, `Spree::ShippingCategory`, `Spree::Zone`, `Spree::TaxCategory`, `Spree::TaxRate`, kraje/stany pomocnicze oraz `Spree::StockTransfer`. W kodzie Admin API v3 znaleziono faktyczne zasoby panelowe tylko dla `tax_categories`, `stock_transfers`, `stock_locations` (sprawdzone wcześniej w F12) oraz read-only `countries`/`states`. Nie znaleziono kontrolerów/tras/SDK/UI dla `shipping_methods`, `shipping_categories`, `zones` ani `tax_rates` w Admin API v3.

**Wzorzec 1 — read/write symmetry.** Wynik: **⚠️ money-critical luka funkcjonalna: konfiguracja wysyłki, stref i stawek podatkowych nie jest wystawiona w panelu ani w Admin API v3.**

- `TaxCategory` jest symetryczne: serializer zwraca `name`, `tax_code`, `description`, `is_default`, a dashboard ma formularz z tymi polami. To jednak tylko klasyfikacja podatkowa produktu, nie konfiguracja stawek.
- `StockTransfer` ma działającą ścieżkę tworzenia dla `source_location_id`, `destination_location_id`, `reference` i listy wariantów z ilościami; transfery są celowo niemutowalne po utworzeniu. Serializer zwraca także `metadata`, ale kontroler nie przyjmuje metadanych — techniczna asymetria bez UI, do ruszenia dopiero przy ogólnym edytorze metadanych.
- Brak panelowej/API ścieżki dla metod wysyłki, kategorii wysyłki, stref i stawek podatkowych oznacza, że merchant nie skonfiguruje z dashboardu ani realnego kosztu dostawy, ani stawek VAT/reguł podatkowych. Dla MVP kakao to ryzyko biznesowe większe niż brak wygody: może skutkować błędną kwotą checkoutu albo brakiem możliwości wysłania zamówienia.

**Wzorzec 2 — martwe endpointy.** Wynik: **✅ istniejące endpointy w tym obszarze mają konsumentów; większy problem to brak endpointów dla shipping/tax rates/zones.**

- `tax_categories` mają SDK, hooki, tabelę i route `settings/tax-categories`.
- `stock_transfers` mają SDK, hooki, tabelę i route `products/transfers`. Kreator transferu używa top-level `adminClient.variants.list(...)` do wyszukiwania SKU oraz `stock_locations` do wyboru źródła/celu.
- `countries`/`states` są read-only i używane pomocniczo przez formularze adresów/lokalizacji, ale nie zastępują brakujących `zones`.

**Wzorzec 3 — ciche błędy mutacji.** Wynik: **✅ czyste w istniejących ekranach.**

- Mutacje tax categories używają `try/catch`, `mapSpreeErrorsToForm` i hooków `useResourceMutation` z komunikatami błędów.
- Usuwanie tax category i stock transfer korzysta z hooków z `errorMessage`; lokalne `.catch(() => undefined)` nie jest ciche, bo hook sam emituje toast błędu.
- Tworzenie stock transferu nie ma lokalnego `try/catch`, ale `useCreateStockTransfer` ma `errorMessage`, więc błąd zapisu jest widoczny i arkusz nie zamyka się po odrzuconym `await`.

**Rekomendacja:** nie implementować „na ślepo” konfiguracji wysyłki/podatków. To money-critical obszar wymagający osobnego zadania projektowego: dodać Admin API v3 i UI dla metod wysyłki, kategorii wysyłki, stref oraz stawek podatkowych/kalkulatorów, albo świadomie udokumentować tymczasową konfigurację poza dashboardem przed startem sprzedaży.

### 2026-07-08 — F13, prompt 3: bezpieczeństwo panelu — użytkownicy, role, klucze API i zaproszenia

**Zakres:** `Spree::AdminUser`, `Spree::Role`, `Spree::RoleUser`, role/permission sets/CanCanCan, `Spree::ApiKey`, zaproszenia i publiczna akceptacja zaproszeń. Audyt był traktowany jako security-critical; zgodnie z promptem nie zmieniano logiki autoryzacji automatycznie.

**Najważniejsze ryzyko:** **⚠️ panel/API pozwalają spróbować usunąć siebie albo ostatniego administratora ze store przez staff management.** `AdminUsersController#destroy` usuwa store-scoped `RoleUser` targetu, a `#update` może zastąpić `role_ids`; UI pokazuje akcję remove/edit dla każdego wiersza bez widocznej ochrony self/last-admin. Błędy są toastowane, ale nie znaleziono twardej reguły domenowej „nie odbieraj ostatniego admina / nie odbieraj sobie ostatniej roli administracyjnej”. To trzeba rozwiązać świadomie w backendzie, nie tylko ukryciem przycisku.

**Wzorzec 1 — read/write symmetry.** Wynik: **⚠️ podstawowe pola są symetryczne, ale jest ryzyko lockoutu przy zarządzaniu rolami.**

- Staff: serializer zwraca `email`, `first_name`, `last_name`, `full_name`, `selected_locale`, `avatar_url`, `roles`. Endpoint pozwala edytować `first_name`, `last_name` i pełną listę `role_ids`; UI ma pola imienia/nazwiska oraz checkboxy ról. `email`, `selected_locale` i `avatar_url` są w tym ekranie odczytowe/poza zakresem staff management.
- Role: endpoint jest read-only i służy do pickerów; brak CRUD ról jest świadomym ograniczeniem, bo role są globalne i permission sets nie mają jeszcze panelowego modelu edycji.
- API keys: serializer nie ujawnia sekretu poza jednorazowym `plaintext_token` na create; UI pozwala wybrać typ i zakresy przy tworzeniu, a przy edycji zmienić tylko nazwę. To zgadza się z modelem — zakresy są create-only i zmiana uprawnień wymaga nowego klucza + revoke starego.
- Invitations: serializer i UI obsługują email, rolę, status, resend, revoke i link akceptacji. Zaproszenia są niemutowalne po utworzeniu; zmiana roli wymaga cofnięcia i wysłania nowego zaproszenia.

**Wzorzec 2 — martwe endpointy.** Wynik: **✅ istniejące endpointy bezpieczeństwa mają konsumentów w SDK i/lub panelu.**

- `admin_users` list/update/destroy, `roles` list, `invitations` list/create/destroy/resend, `api_keys` list/create/update/destroy/revoke oraz publiczne invitation lookup/accept są spięte przez `@spree/admin-sdk`, hooki i route `settings/staff`, `settings/api-keys`, `accept-invitation/$invitationId`.
- `api_keys/current` ma konsumenta SDK/CLI, nie route dashboardu; to endpoint diagnostyczny dla secret-key principal, więc brak panelowego przycisku nie jest luką UI.

**Wzorzec 3 — ciche błędy mutacji.** Wynik: **✅ czyste.**

- Invite/resend/revoke, staff update/remove, API key create/update/revoke/delete oraz invitation accept mają lokalny `try/catch`, `mapSpreeErrorsToForm` i/lub toast/root form error.
- Backend ma dodatkowe guardy przed eskalacją roli (`RoleGrantGuard`) i przed scope amplification przy tworzeniu secret key (`ApiKeysController#create`). To nie zastępuje brakującej reguły last-admin/self-lockout, ale ogranicza eskalację uprawnień.

**Rekomendacja:** utworzyć osobne security zadanie przed produkcją: backendowy guard dla staff management, który blokuje usunięcie ostatniego store-admina oraz odebranie sobie ostatniej roli dającej dostęp do staff/API-key management; UI może dodatkowo ukrywać/disabledować akcje dla current user/last admin, ale tylko jako warstwa UX.

### 2026-07-08 — F13, prompt 4: pieniądze klienta — karty podarunkowe, kredyt sklepowy, zwroty, listy życzeń i pobrania cyfrowe

**Zakres:** `Spree::GiftCard`, `Spree::GiftCardBatch`, `Spree::StoreCredit`, `Spree::StoreCreditCategory`, order-level gift cards/store credits/refunds oraz istniejące powierzchnie Store API dla wishlist i cyfrowych pobrań. Audyt nie zmieniał kontraktu Store API; jedyna mała poprawka dotyczyła widoczności błędów w panelu.

**Wzorzec 1 — read/write symmetry.** Wynik: **⚠️ gift cards i customer store credits są spięte, ale zwroty/returns, wishlisty i digital downloads nie mają pełnego admin-side modelu zarządzania.**

- Karty podarunkowe mają sensowną ścieżkę admina: top-level CRUD `gift_cards`, tworzenie batchy, widok listy, edycję/usuwanie i order-level zastosowanie/usunięcie karty. Sekret/kod karty nie jest problemem symetrii — UI traktuje go jako jawny input tylko tam, gdzie merchant faktycznie wydaje lub aplikuje kartę.
- Kredyt sklepowy klienta ma top-level ścieżkę w detalu klienta: endpoint `customers/:customer_id/store_credits` przyjmuje `amount`, `currency`, `memo`, `category_id`, `created_by_id`, `invalidated_at`, a panel pozwala dodawać, edytować i usuwać kredyty oraz wybiera kategorię. Kategorie kredytu są tylko read-only (`store_credit_categories#index/show`), więc jeśli merchant ma sam zarządzać typami kredytu, potrzebne będzie osobne CRUD/API/UI; dla seedowanych kategorii to akceptowalne ograniczenie.
- Refundy są dostępne głównie jako order-level create/list (`orders/:order_id/refunds`) i jako embed przy płatnościach/zamówieniach. Nie znaleziono pełnego Admin API/UI dla `reimbursement_types`, `refund_reasons`, `return_authorization_reasons`, `customer_returns` ani głębszego lifecycle'u zwrotu/reimbursement. To nie jest mała poprawka UI, tylko osobny obszar operacyjny przed sprzedażą.
- Wishlisty i cyfrowe pobrania istnieją po stronie Store API (`wishlists`, `wishlist_items`, tokenized `digitals/:token`), ale nie mają odpowiadających kontrolerów Admin API v3, metod SDK ani route dashboardu. Merchant nie ma więc w panelu widoczności/zarządzania listami życzeń ani plikami/linkami cyfrowymi.

**Wzorzec 2 — martwe endpointy.** Wynik: **⚠️ istniejące admin endpointy gift/store-credit mają konsumentów; luki dotyczą braku admin endpointów dla wishlist/digital oraz niepełnego panelu zwrotów.**

- `gift_cards`, `gift_card_batches`, `customers/:customer_id/store_credits`, `store_credit_categories` oraz order-level `gift_cards`, `store_credits`, `refunds` są spięte przez `@spree/admin-sdk`, hooki i/lub ekrany dashboardu.
- Store-only `wishlists` i `digitals/:token` są świadomie poza dashboardem klienta, ale dla panelu administracyjnego to martwa strefa operacyjna: brak list, wyszukiwania, podglądu i akcji moderatora/merchant-a.

**Wzorzec 3 — ciche błędy mutacji.** Wynik: **✅ jedna mała luka naprawiona; reszta audytowanego obszaru używa hooków/toastów.**

- Hooki tworzenia, aktualizacji i usuwania store credit klienta dostały jawne `errorMessage`, żeby lokalne `mutateAsync`/`mutate` nie kończyły się route-boundary albo brakiem toastu przy błędzie serwera.
- Mutacje gift cards, batchy, order-level gift cards/store credits i refundów korzystają z istniejących hooków z `errorMessage` albo lokalnego `try/catch`, więc błędy są widoczne.

**Rekomendacja:** przed startem sprzedaży zaplanować oddzielny pakiet „post-sale money operations”: pełny lifecycle zwrotów/returns/reimbursements z powodami, decyzję czy kategorie store credit są seedowane czy edytowalne, oraz decyzję czy wishlisty i cyfrowe pobrania mają mieć admin-side widoczność/zarządzanie.

### 2026-07-08 — F13, prompt 5: konfiguracja i integracje — webhooks, custom fields, tłumaczenia, feedy danych i rynki

**Zakres:** webhook endpoints/deliveries, custom field definitions i wartości custom fields, resource translations/batch translations, allowed origins, exports, markets oraz Store API data feeds.

**Wzorzec 1 — read/write symmetry.** Wynik: **⚠️ większość konfiguracji jest spięta, ale brakuje rotacji sekretu webhooka, admina dla data feeds i lepszego modelu błędów tłumaczeń.**

- Webhook endpoints mają CRUD, enable/disable, send test, deliveries list/show/redeliver oraz UI dla listy i detalu. Serializer pokazuje `secret_key` tylko w jednorazowym flow po utworzeniu, co jest poprawne, ale nie znaleziono endpointu/UI do rotacji sekretu istniejącego endpointu. Jeśli sekret wycieknie, obecna ścieżka operacyjna to stworzenie nowego endpointu i wyłączenie starego.
- Custom field definitions mają CRUD w Admin API, SDK, hookach i panelu; wartości custom fields są wystawione przez zasoby `custom_fieldable` i edytowane inline na obsługiwanych zasobach. To wygląda spójnie z obecnym modelem.
- Tłumaczenia mają read-only macierze pod zasobami translatable i atomiczny `POST /translations/batch`. Backend zwraca szczegóły walidacji per wpis (`details.translations[index]`), ale UI pokazuje błąd batchowo w jednym toaście, bez przypięcia błędu do konkretnego rekordu/wiersza. To nie jest cichy błąd, ale obniża diagnozowalność częściowej walidacji.
- Markets mają Admin API i ekran ustawień dla nazwy, waluty, locale, krajów, tax inclusive/default i pozycji. W audycie kodowym potwierdzono, że formularz rynku używa pełnego selecta walut i comboboxa krajów, ale zgłoszonego wcześniej pustego przełącznika kraju/waluty w działającym panelu nie zamykamy bez manualnej reprodukcji w przeglądarce.
- Data feeds istnieją jako Store API (`/feeds/:slug`) i model runtime, ale nie znaleziono Admin API v3/SDK/dashboard do tworzenia, aktywowania ani edycji feedów.

**Wzorzec 2 — martwe endpointy.** Wynik: **⚠️ webhooks/custom fields/markets/allowed origins/exports mają konsumentów; Store API data feeds nie mają panelowej konfiguracji.**

- Webhooks, webhook deliveries, custom field definitions, nested custom fields, translations, markets, allowed origins i exports są referencjonowane z `packages/` przez admin SDK, hooki, komponenty lub route dashboardu.
- `exports` nie mają osobnego ekranu listy, ale są używane przez `ExportButton` dla produktów, klientów i zamówień oraz przez eksport kuponów w formularzu promocji; to nie jest martwy endpoint.
- `data_feeds` po stronie Store API są użyteczne tylko wtedy, gdy rekordy feedów są tworzone/utrzymywane poza panelem. Brak adminowej konfiguracji traktujemy jako lukę funkcjonalną, nie jako martwy kod.

**Wzorzec 3 — ciche błędy mutacji.** Wynik: **⚠️ brak cichych sukcesów, ale tłumaczenia nadal potrzebują lepszej prezentacji błędów per rekord.**

- Mutacje webhooków, deliveries, custom field definitions, allowed origins i markets korzystają z `useResourceMutation` z `errorMessage` lub lokalnego `try/catch`.
- `ResourceTranslationsDialog` łapie błąd batch save i pokazuje `SpreeError.message` albo fallbackowy toast. Użytkownik wie, że zapis się nie udał, ale nie widzi od razu, który wiersz/wartość była problemem mimo że backend zwraca szczegóły.

**Rekomendacja:** trzy dalsze zadania: (1) dodać rotację sekretu webhook endpointu jako backendowy endpoint + UI z jednorazowym reveal; (2) zdecydować, czy `Spree::DataFeed` ma być konfigurowany w dashboardzie, a jeśli tak dodać Admin API/SDK/UI; (3) rozbudować editor tłumaczeń o mapowanie `details.translations[index]` na konkretne wiersze gridu.

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
