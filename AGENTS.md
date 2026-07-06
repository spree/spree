# sklepik — instrukcja dla agentów kodowania

To repozytorium to **silnik commerce projektu Kakałowy Sklepik**: backend Rails (fork Spree), Store API + Admin API v3, panel administracyjny React (`packages/dashboard`) i SDK TypeScript. Storefront klienta żyje w osobnym repo `pawelekbyra/sklepikFront` — zmian frontendowych klienta nie robi się tutaj.

**Pełne zasady pracy agenta, konwencje techniczne i protokół dokumentacji: [`CLAUDE.md`](CLAUDE.md).** Ten plik jest tylko drogowskazem.

Zanim cokolwiek zmienisz, przeczytaj:

1. [`docs/kierunek-projektu.md`](docs/kierunek-projektu.md) — **kanon systemu**: cel, podział repo, hierarchia decyzji, kiedy wolno zmieniać core.
2. [`docs/stan-projektu.md`](docs/stan-projektu.md) — bieżący stan i znane problemy.
3. [`docs/roadmap.md`](docs/roadmap.md) — co jest do zrobienia i w jakiej kolejności.
4. [`docs/engine-decisions.md`](docs/engine-decisions.md) — rejestr decyzji silnikowych (każda zmiana core/API/checkout/płatności wymaga wpisu).

Żelazne minimum:

- Sprawdzaj kod, nie ufaj samym opisom w promptach i dokumentach.
- Rozszerzaj zamiast modyfikować core; zmiana core wymaga wpisu w `engine-decisions.md`.
- Nie łam kompatybilności Store API bez jawnej decyzji — konsumuje je storefront.
- Nie commituj sekretów, tokenów ani danych produkcyjnych.
- **Po każdym zadaniu zaktualizuj `docs/stan-projektu.md` i pozostałe dotknięte dokumenty** — dokumentacja ma zawsze odzwierciedlać rzeczywisty stan projektu.
