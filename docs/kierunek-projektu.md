# Kierunek projektu: Sklepik

## Cel projektu

To repozytorium jest fundamentem pod własną platformę e-commerce opartą o Spree Commerce i Next.js.

Celem jest zbudowanie elastycznego sklepu internetowego dla produktów kakao, z możliwością dalszej rozbudowy o moduły premium: interaktywne doświadczenia, gry, filmy, edukację produktową, subskrypcje, program lojalnościowy, storytelling i inne niestandardowe funkcje.

Projekt nie ma być tylko zwykłym sklepem. Ma być bazą pod własny system commerce, który można rozwijać bez ograniczeń typowych dla zamkniętych platform typu Shopify.

## Główna zasada

Stabilny core commerce ma pozostać możliwie nudny, przewidywalny i niezawodny.

Magia projektu powinna powstawać nad corem: w storefrontcie, modułach doświadczenia użytkownika, treściach, integracjach i funkcjach dodatkowych.

Domyślnie należy rozszerzać Spree zamiast modyfikować jego core.

Modyfikacja core jest dopuszczalna, ale tylko wtedy, gdy:

1. istnieje jasny powód biznesowy lub techniczny,
2. nie da się tego sensownie zrobić przez konfigurację, extension point lub osobny moduł,
3. decyzja zostanie opisana w `docs/engine-decisions.md`.

## Priorytety architektoniczne

1. Utrzymać stabilny silnik sklepu.
2. Budować własne funkcje jako rozszerzenia lub osobne moduły.
3. Trzymać wyraźny podział między backendem, adminem i storefrontem.
4. Nie mieszać logiki checkoutu z eksperymentalnymi funkcjami typu gra, VOD lub AI.
5. Nie hardcodować danych demo w kodzie produkcyjnym.
6. Dbać o możliwość aktualizacji względem upstreamowego Spree.
7. Każda większa decyzja techniczna ma mieć krótkie uzasadnienie w dokumentacji.

## Docelowy kierunek technologiczny

- Spree Commerce jako backend, admin, API, produkty, zamówienia, płatności i wysyłka.
- Next.js jako warstwa storefrontu i doświadczenia klienta.
- TypeScript tam, gdzie projekt tego używa.
- Tailwind CSS do interfejsu.
- Stripe jako domyślny kierunek płatności, chyba że później zostanie podjęta inna decyzja.
- Moduły typu gra, VOD, quizy, AI, landing pages i edukacja produktowa jako oddzielne warstwy, niezależne od krytycznego checkoutu.

## Zasady pracy z agentami kodowania

Przed zmianą kodu agent powinien ustalić, gdzie należy wprowadzić zmianę:

- storefront,
- admin,
- API,
- backend,
- core commerce,
- dokumentacja,
- konfiguracja/deployment.

Preferowana kolejność działania:

1. konfiguracja,
2. istniejące extension points,
3. osobny moduł lub rozszerzenie,
4. dopiero na końcu modyfikacja core.

Agent nie powinien wprowadzać nowych usług, frameworków ani dużych zależności bez uzasadnienia w dokumentacji.

Agent nie powinien usuwać kompatybilności z upstreamowym Spree bez wyraźnej decyzji.

Commity powinny być małe, logiczne i skupione na jednym celu.

## Aktualna faza projektu

Faza 1: potwierdzenie, że fundament działa lokalnie.

Warunki ukończenia fazy 1:

- backend działa lokalnie,
- admin działa lokalnie,
- storefront działa lokalnie,
- przykładowe produkty się ładują,
- koszyk działa,
- podstawowy checkout flow jest możliwy do przejścia w środowisku testowym.

Dopiero po tym należy zaczynać większy redesign i personalizację pod markę kakao.

## Faza 2: Kakao MVP

Zakres pierwszego MVP:

- zmiana nazwy/opisu projektu z generycznego Spree na sklep kakao,
- dodanie pierwszych produktów kakao,
- ustawienie kategorii produktów,
- dostosowanie strony głównej,
- dostosowanie strony produktu,
- podstawowe strony informacyjne: O nas, Dostawa, Zwroty, Kontakt,
- sprawdzenie koszyka i checkoutu,
- przygotowanie podstaw pod płatności i wysyłkę.

## Filozofia projektu

Ten projekt ma być własnym systemem operacyjnym pod markę commerce, a nie tylko szablonowym sklepem.

Core sklepu ma być betonem. Na nim można budować storytelling, media, gry, katalogi, edukację, społeczność i inne przewagi, które nie mieszczą się w klasycznych kreatorach e-commerce.
