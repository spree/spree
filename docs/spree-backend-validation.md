# Walidacja backendu Spree dla adaptera produktów

## Cel

Celem dokumentu jest walidacja założeń minimalnego adaptera produktowego `lib/spree` z `KakaowySklepikFront` względem realnego backendu `sklepik` dostępnego w tym repozytorium.

W tym zadaniu nie zmieniono koszyka, checkoutu, Store API ani core Spree. Walidacja dotyczy tylko produktów, wariantów, cen, obrazów, nagłówków i parametrów listowania.

## Sprawdzone źródła

Sprawdzono następujące źródła backendu:

- `AGENTS.md`,
- `docs/engine-decisions.md`,
- `README.md`,
- `spree/api/config/routes.rb`,
- `spree/api/app/controllers/spree/api/v3/store/products_controller.rb`,
- `spree/api/app/controllers/spree/api/v3/store/base_controller.rb`,
- `spree/api/app/controllers/concerns/spree/api/v3/api_key_authentication.rb`,
- `spree/api/app/controllers/concerns/spree/api/v3/resource_serializer.rb`,
- `spree/api/app/serializers/spree/api/v3/product_serializer.rb`,
- `spree/api/app/serializers/spree/api/v3/variant_serializer.rb`,
- `spree/api/app/serializers/spree/api/v3/price_serializer.rb`,
- `spree/api/app/serializers/spree/api/v3/media_serializer.rb`,
- `spree/api/app/serializers/spree/api/v3/base_serializer.rb`,
- `spree/api/spec/integration/spree/api/v3/store/products_spec.rb`,
- `spree/api/spec/controllers/spree/api/v3/store/products_controller_spec.rb`.

Próba pobrania repozytorium `pawelekbyra/KakaowySklepikFront` z GitHuba w środowisku agenta zakończyła się błędem sieciowym `CONNECT tunnel failed, response 403`, więc ta walidacja opiera się na założeniach adaptera przekazanych w zadaniu oraz na kodzie backendu `sklepik`.

## Endpointy produktów

Realny backend `sklepik` udostępnia produktowe Store API w wersji v3:

```text
GET /api/v3/store/products
GET /api/v3/store/products/{id}
```

Endpoint szczegółów przyjmuje `id` jako slug produktu albo prefiksowany identyfikator produktu. Kontroler rozpoznaje prefiksowane ID zaczynające się od `prod_`; w przeciwnym razie szuka produktu po `slug` w kontekście lokalizacji i z fallbackiem do domyślnej lokalizacji.

Założenie adaptera z zadania:

```text
GET /api/v2/storefront/products
GET /api/v2/storefront/products/{slug}
include=default_variant,variants,images,option_types
```

nie pasuje do realnego backendu. Backend nie deklaruje ścieżki `/api/v2/storefront/products` w sprawdzonej konfiguracji routes. Zamiast parametru `include` backend v3 używa parametru:

```text
expand=default_variant,variants,media,option_types
```

Dla obrazów poprawna nazwa relacji w tym backendzie to `media`, a nie `images`. Serializer produktu ma też relację `primary_media` oraz alias `media` dla galerii.

## Nagłówki Store API

Realny backend wymaga publishable API key dla Store API. Właściwy nagłówek to:

```text
X-Spree-Api-Key: <publishable key>
```

Kod backendu pobiera klucz wyłącznie z `request.headers['X-Spree-Api-Key']`. Nagłówek zakładany przez adapter z zadania:

```text
X-Spree-Storefront-Token: SPREE_PUBLISHABLE_KEY
```

nie jest obsługiwany przez sprawdzony backend v3 i skutkowałby odpowiedzią `401 invalid_token`.

Dodatkowe nagłówki kontekstowe obsługiwane przez Store API to między innymi:

```text
X-Spree-Channel
X-Spree-Locale
X-Spree-Currency
X-Spree-Country
```

Dla produktów `Content-Type` przy żądaniu GET nie jest kluczowy. Specyfikacja i testy backendu wskazują `application/json`, a nie JSON:API `application/vnd.api+json`.

## Format produktu

Backend v3 zwraca płaski obiekt JSON produktu, nie klasyczną strukturę JSON:API `data.attributes.relationships` znaną z API v2.

Potwierdzone pola produktu obejmują:

```text
id
name
slug
meta_title
meta_description
meta_keywords
variant_count
default_variant_id
thumbnail_url
available_on
preorder_ships_at
purchasable
in_stock
backorderable
available
preorder
description
description_html
tags
price
original_price
```

Różnice względem założeń adaptera:

- `id` jest prefiksowanym ID API v3, np. `prod_...`, a nie surowym ID bazy.
- `permalink` nie jest potwierdzonym polem serializera produktu v3.
- `updated_at` jest typizowane w bazowym serializerze, ale nie jest jawnie potwierdzone w serializowanym produkcie przez sprawdzone testy produktowe; adapter nie powinien krytycznie polegać na tym polu bez testu kontraktowego.
- `description` jest tekstem oczyszczonym z HTML, a `description_html` zawiera HTML.
- `price` nie jest stringiem bezpośrednio na produkcie, tylko obiektem ceny.
- `currency` nie jest top-level polem produktu; jest wewnątrz `price.currency`.

## Format wariantów

Backend zwraca warianty po rozwinięciu relacji:

```text
expand=variants,default_variant
```

Serializer wariantu potwierdza pola między innymi:

```text
id
product_id
sku
options_text
track_inventory
media_count
thumbnail_url
purchasable
in_stock
backorderable
preorder
preorder_ships_at
weight
height
width
depth
price
original_price
option_values
```

`options_text` istnieje i może być prostym źródłem tekstowej prezentacji wariantu, ale nie jest pełnym strukturalnym modelem `selectedOptions`. Lepsze mapowanie opcji dla UI powinno bazować na `option_values` oraz ewentualnie `option_types` po rozwinięciu.

`variant.id` w API v3 jest prefiksowanym identyfikatorem wariantu, np. `variant_...`. To jest właściwy kandydat na przyszłe `merchandiseId` dla line items w adapterze, ale samo dodawanie line itemów nie było częścią tej walidacji.

## Format cen

Cena w backendzie v3 jest obiektem:

```text
price: {
  amount,
  amount_in_cents,
  display_amount,
  compare_at_amount,
  compare_at_amount_in_cents,
  display_compare_at_amount,
  currency,
  price_list_id
}
```

Potwierdzone właściwości:

- `amount` jest stringiem albo `null`,
- `amount_in_cents` jest liczbą albo `null`,
- `display_amount` jest stringiem sformatowanym do prezentacji,
- `currency` jest wewnątrz obiektu ceny,
- ceny mogą być ukryte przez mechanizm gatingu storefrontu; wtedy powierzchnia cenowa może zwracać `null`.

`display_price` nie jest nazwą pola w serializerach produktów i wariantów v3. Dla adaptera produktowego właściwym polem prezentacyjnym jest `price.display_amount`, a do obliczeń bezpieczniej używać `price.amount` lub `price.amount_in_cents`.

`priceRange` liczony po wariantach ma sens tylko, jeśli adapter pobierze `expand=variants` i uwzględni brak ceny lub ukryte ceny. Fallback `PLN` nie jest potwierdzony przez backend jako bezpieczny globalny fallback; waluta powinna pochodzić z `price.currency` albo z kontekstu `X-Spree-Currency` / rynku.

## Format obrazów

Backend v3 nie potwierdza relacji `images` dla produktów. Obrazy są reprezentowane jako media:

```text
primary_media
media
```

Serializer mediów potwierdza pola:

```text
id
position
alt
product_id
variant_ids
media_type
focal_point_x
focal_point_y
external_video_url
original_url
mini_url
small_url
medium_url
large_url
xlarge_url
og_image_url
```

Dodatkowo produkt i wariant mają skrótowe pole:

```text
thumbnail_url
```

Nie potwierdzono pól `product_url`, `url`, `width` ani `height` w serializerze mediów v3. Jeśli adapter wymaga wymiarów dla `next/image`, musi mieć fallback albo dodatkowy mechanizm pozyskiwania rozmiarów.

URL-e obrazów są budowane przez helper `cdn_image_url`. To oznacza, że host obrazów może być hostem aplikacji albo skonfigurowanym hostem CDN/storage, zależnie od konfiguracji Rails/Active Storage/CDN. Adapter frontendu nie powinien zakładać, że host obrazów jest zawsze identyczny z `SPREE_API_URL`. `next.config.ts` powinien dopuszczać realny host obrazów używany przez środowisko.

## Search i sortowanie

Backend v3 używa parametrów Ransack/search provider, nie `filter[name]`.

Potwierdzony filtr nazwy w specyfikacji Store API:

```text
q[name_cont]=...
```

Potwierdzone sortowanie produktów obejmuje:

```text
sort=price
sort=-price
sort=best_selling
sort=name
sort=-name
sort=available_on
sort=-available_on
```

Założenia adaptera:

```text
filter[name]
sort=updated_at
sort=-updated_at
```

nie są potwierdzone dla produktowego Store API v3. `sort=price` i `sort=-price` są potwierdzone. Sortowanie po `updated_at` należy traktować jako niepotwierdzone i nie używać go jako krytycznej ścieżki bez testu kontraktowego lub decyzji backendowej.

## Zgodność obecnego lib/spree

Na podstawie założeń adaptera przekazanych w zadaniu odpowiedź na pytanie:

```text
Czy obecny lib/spree poprawnie komunikuje się z realnym backendem sklepik dla produktów?
```

brzmi: **nie w pełni**. Minimalny adapter produktowy jest kierunkowo zgodny z modelem Spree, ale wymaga korekt dla realnego backendu `sklepik` v3.

Potwierdzone założenia:

- backend ma Store API dla listy produktów,
- backend ma Store API dla szczegółu produktu po slugu,
- backend zwraca `default_variant` i `variants` po rozwinięciu,
- backend zwraca `options_text`,
- backend używa prefiksowanych ID wariantów, które są dobrym kandydatem na przyszłe `merchandiseId`,
- backend zwraca ceny i waluty przy produktach oraz wariantach,
- backend zwraca media/obrazy z wariantami rozmiarów,
- backend obsługuje `sort=price` i `sort=-price`.

Założenia błędne albo niepotwierdzone:

- ścieżka `/api/v2/storefront/products`,
- parametr `include` zamiast `expand`,
- relacja `images` zamiast `media` / `primary_media`,
- nagłówek `X-Spree-Storefront-Token`,
- filtr `filter[name]`,
- sortowanie `updated_at` / `-updated_at`,
- top-level `currency` na produkcie,
- stringowy `price` bezpośrednio na produkcie,
- pola obrazu `product_url`, `url`, `width`, `height`.

## Różnice i ryzyka

1. **Wersja API i ścieżki** — adapter oparty o `/api/v2/storefront` nie trafi w realne endpointy backendu v3.
2. **Autoryzacja Store API** — błędny nagłówek publishable key zablokuje wszystkie requesty produktowe statusem `401`.
3. **Format odpowiedzi** — backend v3 zwraca płaskie obiekty, a nie format JSON:API v2. Mapper musi obsługiwać realny kształt v3.
4. **Ceny** — adapter nie powinien zakładać waluty `PLN`; backend zwraca walutę w obiekcie ceny i wspiera kontekst waluty przez nagłówki.
5. **Obrazy** — frontend musi skonfigurować `next/image` pod realny host `cdn_image_url`, nie tylko pod host API.
6. **Opcje wariantów** — `options_text` wystarcza jako fallback tekstowy, ale nie jako docelowy strukturalny model opcji.
7. **Search/sort** — filtrowanie po nazwie wymaga `q[name_cont]`; sortowanie po `updated_at` nie jest potwierdzone.

## Rekomendacje przed koszykiem

Przed implementacją koszyka w `KakaowySklepikFront` należy najpierw skorygować produktowy adapter `lib/spree` do kontraktu backendu v3:

1. Zmienić bazowe endpointy produktów na `/api/v3/store/products` i `/api/v3/store/products/{id}`.
2. Zmienić nagłówek publishable key na `X-Spree-Api-Key`.
3. Zmienić `include` na `expand`.
4. Zmienić `images` na `media` / `primary_media` i obsłużyć `thumbnail_url` jako fallback.
5. Mapować ceny z obiektu `price`, szczególnie `amount`, `amount_in_cents`, `display_amount` i `currency`.
6. Usunąć albo oznaczyć jako dług techniczny fallback `PLN`, jeśli nie wynika z konfiguracji rynku.
7. Zmienić search z `filter[name]` na `q[name_cont]`.
8. Nie używać `sort=updated_at` bez potwierdzenia backendowego.
9. Dodać kontraktowy test lub fixture odpowiedzi produktów z backendu v3, zanim adapter zostanie rozszerzony o koszyk.

Jeśli frontend potrzebuje dodatkowych pól lub innego sortowania z backendu, nie należy zmieniać core Spree doraźnie pod adapter. Taka potrzeba powinna zostać opisana jako decyzja backendowa w `sklepik/docs/engine-decisions.md` przed implementacją.
