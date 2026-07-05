# Dostęp administracyjny

Ten dokument opisuje, gdzie należy logować się jako administrator Kakaowy Sklepik i gdzie przebiega granica między panelem admina, API i storefrontem.

## Zasada główna

Admin sklepu należy do backendu `pawelekbyra/sklepik`, czyli do Spree Admin.

`KakaowySklepikFront` nie jest panelem administracyjnym. To storefront dla klientów.

Nie budujemy osobnego panelu admina w Vercel Commerce, dopóki nie pojawi się świadoma decyzja architektoniczna. Spree Admin jest domyślnym miejscem zarządzania commerce.

## Role systemu

```text
KakaowySklepikFront
→ storefront dla klientów
→ listingi, product page, UX, SEO, koszyk i checkout po podpięciu adaptera

sklepik / Spree Admin
→ panel administracyjny
→ produkty, warianty, ceny, zdjęcia, dostępność, zamówienia, płatności, wysyłka, podatki

sklepik / Store API
→ API konsumowane przez adapter lib/spree w KakaowySklepikFront
```

## Docelowy podział domen

Docelowo system powinien być rozdzielony logicznie:

```text
www.kakaowysklepik.pl
→ storefront dla klientów

admin.kakaowysklepik.pl
→ panel administracyjny Spree

api.kakaowysklepik.pl
→ Store API / backend Spree dla frontendu
```

Na etapie prototypu dopuszczalny jest prostszy układ, np. backendowa domena techniczna z `/admin` i `/api/v2/storefront`.

## Konto admina

Pierwsze konto admina powinno być tworzone przez mechanizm backendu Spree, seed/setup task albo ręcznie w bezpiecznym środowisku administracyjnym.

Nie wolno commitować do repozytorium:

- loginów produkcyjnych,
- haseł,
- tokenów,
- kluczy API,
- prywatnych adresów administracyjnych, jeśli nie są publiczną konfiguracją deploymentu.

Jeżeli task lub seed tworzy konto developerskie, dane muszą być przeznaczone tylko dla lokalnego środowiska i jasno opisane jako nieprodukcyjne.

## Relacja do frontendów

Gdy administrator dodaje lub zmienia produkt w Spree Admin, frontend `KakaowySklepikFront` powinien odczytać te dane przez Store API i adapter `lib/spree`.

Frontend nie powinien omijać backendu ani utrzymywać własnego źródła prawdy dla produktów, wariantów, cen, dostępności, koszyka, checkoutu lub zamówień.

## Kiedy aktualizować ten dokument

Zaktualizuj ten dokument, gdy zmienia się:

- sposób tworzenia konta admina,
- docelowa domena admina,
- deployment backendu,
- ścieżka do Spree Admin,
- zasady dostępu do API,
- rozdział odpowiedzialności między adminem, API i storefrontem.
