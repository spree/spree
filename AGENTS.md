# sklepik — zasady pracy agentów

## Rola repo

To jest backend Kakaowy Sklepik.

Spree jest źródłem prawdy dla commerce. Repo odpowiada za admin, API, produkty, warianty, ceny, koszyk, checkout, zamówienia i płatności.

Repozytorium nie jest traktowane wyłącznie jako kopia oryginalnego Spree. To jest projekt `sklepik`: własna platforma commerce budowana na fundamencie Spree Commerce i Next.js.

Oryginalne zasady Spree są ważne jako techniczne wskazówki dotyczące architektury silnika, ale nie są nadrzędne względem celu tego projektu.

## Relacja z frontendami

`KakaowySklepikFront` konsumuje Store API przez adapter `lib/spree`.

`sklepikFront` jest bezpiecznym storefrontem opartym o oficjalny Spree Storefront.

Backend nie może być psuty pod wygodę jednego frontendu. Zmiany API, koszyka, checkoutu i płatności muszą respektować rolę Spree jako źródła prawdy dla commerce oraz wpływ na wszystkie aktualne i przyszłe frontendowe klienty Store API.

Admin sklepu należy do tego repo i Spree Admin. `KakaowySklepikFront` nie jest panelem administracyjnym. Szczegóły granicy admin/API/storefront są opisane w `docs/admin-access.md`.

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

## Zasady zmian

Najpierw konfiguracja albo rozszerzenie Spree. Core Spree zmieniamy tylko świadomie, po sprawdzeniu, że konfiguracja, extension point lub osobny moduł nie wystarczają.

Zmiany API, cart, checkout i payment muszą być dokumentowane. Nie wolno łamać kompatybilności Store API bez jawnej decyzji w `docs/engine-decisions.md`.

Nie commitować sekretów, tokenów, kluczy API, haseł ani danych produkcyjnych. Konfiguracja produkcyjna musi być zmieniana tylko w jasno opisanym zakresie.

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

## Dokumentacja decyzji

Każda zmiana silnika, API, checkoutu albo payment ma mieć wpis w `docs/engine-decisions.md`.

Wpis musi zawierać:

- kontekst,
- decyzję,
- uzasadnienie,
- wpływ na upstream,
- notatki dla kolejnych agentów.

Jeśli zmiana dotyczy Store API konsumowanego przez `KakaowySklepikFront`, wpływ na adapter `lib/spree` musi być opisany wprost. Jeśli agent celowo wybiera konfigurację lub rozszerzenie zamiast zmiany core, też powinien zapisać dlaczego core nie był ruszany.

## Workflow agenta

Każdy agent przed zmianą ma:

1. przeczytać `AGENTS.md`,
2. przeczytać `docs/engine-decisions.md` oraz inne dokumenty z `docs/` istotne dla zadania,
3. sprawdzić aktualny kod i nie bazować wyłącznie na opisie promptu,
4. zawęzić zakres do najmniejszego sensownego kroku.

Każdy agent po zmianie ma:

1. zaktualizować dokumentację albo dopisać świadomy dług techniczny,
2. uruchomić dostępne checki adekwatne do zakresu,
3. w PR opisać, co zmieniono,
4. wskazać, czego celowo nie zmieniono,
5. opisać przyjęte założenia,
6. podać wynik checków,
7. wskazać najlepszy następny krok.

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

Nie rób szerokich zmian poza zakresem promptu.

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
- `docs/admin-access.md` — granica między Spree Admin, Store API i storefrontem.

Jeżeli agent ma wątpliwość, ma najpierw sprawdzić te dokumenty, a dopiero potem bazować na ogólnych zasadach Spree.
