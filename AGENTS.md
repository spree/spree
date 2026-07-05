# Sklepik — nadrzędne zasady pracy agentów

Ten plik jest nadrzędną instrukcją dla agentów kodowania pracujących w tym repozytorium.

Repozytorium nie jest już traktowane wyłącznie jako kopia oryginalnego Spree. To jest projekt `sklepik`: własna platforma commerce budowana na fundamencie Spree Commerce i Next.js.

Oryginalne zasady Spree są ważne jako techniczne wskazówki dotyczące architektury silnika, ale nie są nadrzędne względem celu tego projektu.

## Hierarchia decyzji

W razie konfliktu priorytetów obowiązuje kolejność:

1. Cel projektu `sklepik`.
2. Decyzje właściciela projektu.
3. Dokumentacja lokalna w `docs/kierunek-projektu.md` i `docs/engine-decisions.md`.
4. Stabilność checkoutu, zamówień, płatności, produktów i admina.
5. Kompatybilność ze Spree upstream.
6. Oryginalne konwencje Spree.

Jeżeli reguła upstreamowego Spree przeszkadza w realizacji celu projektu, agent ma najpierw zaproponować bezpieczny wariant rozszerzenia. Jeśli konieczna jest zmiana core, trzeba ją opisać w `docs/engine-decisions.md`.

## Cel projektu

`sklepik` ma być własną platformą e-commerce, początkowo dla sklepu z produktami kakao.

Projekt ma umożliwiać dalszą rozbudowę o:

- niestandardowy storefront,
- storytelling marki,
- katalogi premium,
- filmy i edukację produktową,
- quizy zakupowe,
- gry i interaktywne doświadczenia,
- subskrypcje,
- program lojalnościowy,
- integracje AI,
- inne moduły, które wykraczają poza klasyczny sklep.

To nie jest zwykły szablon sklepu. To ma być fundament pod własny system commerce.

## Główna zasada architektoniczna

Core commerce ma być stabilny, przewidywalny i możliwy do utrzymania.

Magia projektu powinna powstawać nad corem: w storefrontcie, modułach, integracjach i warstwie doświadczenia użytkownika.

Preferowana kolejność zmian:

1. konfiguracja,
2. istniejące extension points,
3. osobny moduł lub rozszerzenie,
4. dopiero na końcu modyfikacja core.

## Zasady dla agentów

Przed każdą zmianą agent ma ustalić, gdzie ta zmiana należy:

- storefront,
- admin,
- API,
- backend,
- core commerce,
- dokumentacja,
- konfiguracja/deployment.

Agent powinien:

- preferować rozszerzanie zamiast zmiany core,
- utrzymywać małe i logiczne commity,
- nie wprowadzać nowych usług bez uzasadnienia,
- nie mieszać checkoutu z eksperymentalnymi modułami,
- nie hardcodować danych demo w kodzie produkcyjnym,
- dokumentować decyzje silnikowe w `docs/engine-decisions.md`,
- traktować `docs/kierunek-projektu.md` jako dokument opisujący kierunek biznesowo-techniczny projektu.

## Kiedy wolno zmieniać core

Zmiana core jest dopuszczalna, bo ten projekt ma być docelowo własną platformą commerce, a nie tylko cienką nakładką na Spree.

Core można zmieniać, jeśli:

1. istnieje jasny powód biznesowy lub techniczny,
2. konfiguracja albo extension point nie wystarcza,
3. zmiana nie rozwala podstawowego checkoutu i zamówień,
4. wpływ na upstream jest opisany,
5. decyzja trafia do `docs/engine-decisions.md`.

## Czego nie robić

Nie traktuj tego repo jako neutralnego upstreamowego Spree.

Nie zakładaj, że celem jest bezwzględna zgodność ze Spree kosztem wizji projektu.

Nie rozpoczynaj dużego redesignu, jeśli podstawowy flow commerce nie działa.

Nie dodawaj eksperymentalnych funkcji do krytycznej ścieżki checkoutu.

Nie usuwaj lokalnej dokumentacji projektu jako „niepotrzebnej”.

## Aktualny etap

Projekt jest w fazie budowania fundamentu.

Najpierw trzeba utrzymać działające:

- backend,
- admin,
- storefront,
- produkty,
- koszyk,
- checkout flow,
- sample data lub pierwsze produkty testowe.

Dopiero potem należy rozwijać branding kakao, treści, gry, VOD, quizy i inne przewagi.

## Ważne dokumenty lokalne

- `docs/kierunek-projektu.md` — nadrzędny kierunek projektu.
- `docs/engine-decisions.md` — decyzje dotyczące silnika.

Jeżeli agent ma wątpliwość, ma najpierw sprawdzić te dokumenty, a dopiero potem bazować na ogólnych zasadach Spree.
