# Dokumentacja — sklepik

Zwięzły komplet żywych dokumentów. Zasada: aktualizujemy istniejące pliki, nie tworzymy nowych notatek-sierot. Historia jest w gicie.

| Dokument | Rola |
|---|---|
| [`kierunek-projektu.md`](kierunek-projektu.md) | **Kanon systemu** — cel, podział repo, hierarchia decyzji, zasady architektury. Obowiązuje oba repozytoria. |
| [`architektura.md`](architektura.md) | Jedyna mapa systemu: aplikacje, hosting, przepływy danych, zmienne środowiskowe. |
| [`stan-projektu.md`](stan-projektu.md) | Żywy stan: co działa, znane problemy, czego brakuje. **Aktualizowany po każdym zadaniu.** |
| [`roadmap.md`](roadmap.md) | Backlog F1–F9 (fundament) + Faza 2 (Kakao MVP) + Faza 3. Statusy zadań. |
| [`deployment-render.md`](deployment-render.md) | Jak realnie działa deploy backendu na Render. |
| [`engine-decisions.md`](engine-decisions.md) | Rejestr świadomych zmian w core silnika commerce. |
| [`admin-access.md`](admin-access.md) | Granica admin / API / storefront i gdzie loguje się administrator. |
| `plans/` | Szablon (`_template.md`) na przyszłe własne plany architektoniczne. |

Dokumentacja storefrontu żyje w repo `sklepikFront` (`docs/`); generowana specyfikacja OpenAPI odtwarza się do `docs/api-reference/` przez `bundle exec rake rswag:specs:swaggerize` (nie edytować ręcznie, nie commitować bez potrzeby).
