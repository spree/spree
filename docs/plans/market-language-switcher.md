# Rozdzielenie języka od rynku/waluty (Market/Language Switcher)

**Status:** Draft
**Target:** Faza 1 dokończenie (kroki 1-2 poniżej) teraz; krok 4 zależny od konfiguracji Stripe (Faza 2)
**Depends on:** Konfiguracja Stripe pod multi-currency settlement (Faza 2 roadmapy) — tylko dla realnego checkoutu w EUR, nie blokuje wcześniejszych kroków
**Author:** Claude (sesja 2026-07-07, na żądanie użytkownika po zgłoszeniu zepsutego `CountrySwitcher`)
**Last updated:** 2026-07-07

## Summary

Obecny przełącznik w storefroncie (`CountrySwitcher.tsx`) miesza dwie różne rzeczy w jednym dropdownie: język UI i walutę/rynek. Efekt: wizualny duplikat ("PL PL | PLN" — flaga nie renderuje się jako emoji na części systemów i pada z powrotem na tekst obok już istniejącego tekstu kraju), oraz twardy 404 przy wyborze innego kraju (komponent wciąż buduje link wg starego schematu `/{country}/{locale}/...`, usuniętego z routingu przy przejściu na jeden rynek).

Duże portale (Amazon, ASOS, Shopify Markets) rozdzielają to na dwie niezależne osie: **Market** (kraj wysyłki + waluta + domyślny locale, bo to determinuje podatek/wysyłkę/płatność) i **Język** (czysto UI, niezależny od tego gdzie wysyłasz). Ten plan opisuje jak dociągnąć tę architekturę tutaj — i dobra wiadomość: większość klocków już istnieje, to głównie problem połączenia, nie budowy od zera:

- `Spree::Market` (backend) już modeluje dokładnie ten bundel: `currency` + `default_locale` + `countries` (many-to-many przez `market_countries`).
- Panel admina (`packages/dashboard/.../settings/markets.tsx`) już ma pełny CRUD rynków — tworzenie nowego rynku to praca w UI, nie w kodzie.
- `messages/{pl,en,de,es,fr}.json` — 5 kompletnych (strukturalnie) plików tłumaczeń już istnieje, nieużywanych jako realny przełącznik.
- Cron `sync-eur-prices` już codziennie zapisuje ceny EUR (kurs NBP) jako zwykłe `Spree::Price` — dane multi-walutowe już płyną.
- `resolveCurrency()` już jest Suspense-safe (fix z dzisiaj) — łatwo rozszerzyć o odczyt z cookie zamiast tylko env-defaultu.
- `updateCartMarket` w `useCountrySwitch.ts` już synchronizuje walutę/locale koszyka przy zmianie rynku.

## Key Decisions (do not deviate without discussion)

- **Język i Market to dwa oddzielne, oddzielnie prezentowane kontrolki** — nigdy więcej jednego dropdownu łączącego oba.
- **Market nie wraca do URL-a.** Segment `[country]` został świadomie usunięty wcześniej (sklep jednorynkowy) — zostaje usunięty. Wybór rynku żyje w cookie, analogicznie do tego jak `resolveCurrency` już dziś rozwiązuje walutę server-side, tylko teraz z override'em od użytkownika zamiast sztywnego env-defaultu.
- **Wyświetlana waluta ≠ gwarantowana waluta rozliczenia**, dopóki Stripe nie obsługuje realnego rozliczenia w danej walucie. Rynek z tylko orientacyjnymi cenami (dzisiejszy EUR z NBP) musi mieć jawny disclaimer w UI, że płatność i tak nastąpi w PLN.
- **Przełącznik rynku pokazuje się dopiero gdy istnieją ≥2 realne rynki.** Przy jednym rynku (stan dzisiejszy) — nie pokazuj dropdownu z jedną sensowną opcją.
- **Przełącznik języka pokazuje tylko zweryfikowane jakościowo locale'e.** Kompletność strukturalna (528 linii, 22 klucze w każdym pliku) nie jest tym samym co jakość tłumaczenia — de/es/fr wymagają przeczytania przed wystawieniem w UI, nie tylko sprawdzenia że plik istnieje.

## Design Details

### Oś Język (tylko frontend, zero zmian backendu)

- Nowy komponent `LanguageSwitcher` (client), lista locale'i next-intl — start: tylko `pl`/`en` (jedyne dziś realnie routowalne wg `NEXT_PUBLIC_PREFIXED_LOCALES`).
- Zmiana języka przepisuje wyłącznie segment `/{locale}` w URL-u, zachowuje resztę ścieżki, nie rusza cookies/waluty/koszyka.
- Żyje w Headerze obok (nie wewnątrz) przełącznika rynku.

### Oś Market (waluta + wysyłka + strefa podatkowa)

- Przemianowanie/przebudowa `CountrySwitcher` → `MarketSwitcher`. Lista prawdziwych rekordów `Market` (przez istniejący `GET /api/v3/store/markets`), jedna pozycja na rynek (nie spłaszczone per-kraj jak dziś) — np. "Polska — PLN", "Eurozone — EUR".
- Wybór rynku ustawia cookie (np. `spree_market_id` lub walutę bezpośrednio) — bez zmiany URL-a, bez segmentu `/{country}/`.
- `resolveCurrency()` (już Suspense-safe) czyta najpierw cookie, dopiero potem fallback na `getDefaultCountry()` z env — dla pierwszej wizyty.
- Przy zmianie rynku z aktywnym koszykiem — reużycie `updateCartMarket` (już zaimplementowane w `useCountrySwitch.ts`).
- Przy jednym realnym rynku — przełącznik ukryty (stan dzisiejszy, patrz Migration Path krok 0).

### Gotowość cenowa nowego rynku

- Przed publicznym wystawieniem nowego rynku — przegonić `Spree::Products::ReadinessCheck` (F3) po nim; panel powinien pokazać które produkty NIE są gotowe dla danego rynku (brak tłumaczenia/ceny) zanim rynek pójdzie live. Mechanizm już istnieje dla pojedynczego rynku, tu tylko trzeba go uruchomić po nowym.

### Waluta wyświetlana vs waluta rozliczenia

Dwuetapowa rzeczywistość, dopóki Stripe nie obsłuży multi-currency:

- **Etap 1 (dostępny już dziś):** przełącznik rynku zmienia tylko WYŚWIETLANĄ walutę (ceny EUR już synchronizowane codziennie przez cron NBP); jawny badge/disclaimer informuje że realna płatność nastąpi w PLN.
- **Etap 2 (po konfiguracji Stripe pod multi-currency, Faza 2):** realne rozliczenie w EUR, disclaimer znika, `updateCartMarket` już wiąże prawdziwą walutę zamówienia.

## Migration Path

1. **Teraz (bez długu, do wdrożenia od razu):** ukryć/usunąć zepsuty `CountrySwitcher` z Headera — zatrzymuje 404 i wizualny bug natychmiast, niezależnie od reszty planu.
2. **Krok 1 — Language switcher:** zbudować `LanguageSwitcher` (pl/en), wdrożyć niezależnie, zero zależności od backendu.
3. **Krok 2 — Prawdziwy drugi rynek w adminie:** właściciel sklepu tworzy realny rynek "Eurozone" przez już istniejące UI (`settings/markets.tsx`) — waluta EUR, default_locale (prawdopodobnie `en` lub `de`), przypięte odpowiednie kraje.
4. **Krok 3 — Przebudowa MarketSwitcher:** oparty o cookie, bez segmentu URL, czyta prawdziwą listę `Market`, pokazuje disclaimer Etapu 1.
5. **Krok 4 (Faza 2, po Stripe):** konfiguracja Stripe pod rozliczenie EUR, usunięcie disclaimera, weryfikacja że `updateCartMarket` prowadzi prawdziwe zamówienie przez checkout w EUR.

## Constraints on Current Work

- Żaden nowy komponent dotykający locale/waluty nie może na powrót wprowadzić połączonego segmentu URL kraj+waluta — URL zostaje `/{locale}/...` i tylko to.
- Nie wystawiać w UI języków de/es/fr zanim ktoś faktycznie przeczyta te pliki tłumaczeń pod kątem jakości — dziś są tylko strukturalnie kompletne, niezweryfikowane merytorycznie.

## Open Questions

- Cookie czy preferencja przypięta do zalogowanego konta klienta? (Rekomendacja: na start wystarczy cookie — sklep na razie głównie gości.)
- Czy rynek ma być sugerowany automatycznie po IP/geolokalizacji, czy zawsze wymaga jawnego wyboru użytkownika? (Rekomendacja: na razie tylko jawny wybór — geo-IP dodaje złożoność i pytania o prywatność nieuzasadnione przy obecnej skali.)
- Dokładna treść i miejsce disclaimera Etapu 1 ("cena orientacyjna, płatność w PLN") — to decyzja copy/UX, nie inżynierska.

## References

- `sklepik/docs/roadmap.md` — Faza 2 (Stripe, ekspansja globalna)
- `sklepikFront/docs/technical-debt.md` — dzisiejszy fix `resolveCurrency`/Suspense, fix wariantów zdjęć
- Istniejące elementy do reużycia: `Spree::Market`, `packages/dashboard/.../settings/markets.tsx`, `sklepikFront/src/hooks/useCountrySwitch.ts` (`updateCartMarket`), `sklepikFront/src/app/api/cron/sync-eur-prices/route.ts`, `Spree::Products::ReadinessCheck` (F3)
