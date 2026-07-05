# Codex prompt 001: Rozpoznaj strukturę storefrontu

## Kontekst

Pracujemy w repozytorium `sklepik`.

To jest własna platforma commerce budowana na fundamencie Spree Commerce i Next.js. Nadrzędne zasady projektu są w `AGENTS.md`, `docs/kierunek-projektu.md`, `docs/mvp-kakao-sklepik.md` i `docs/engine-decisions.md`.

Użytkownik nie pracuje lokalnie. Cały workflow ma działać przez agentów kodowania i commity/PR-y w repozytorium.

## Cel zadania

Rozpoznać strukturę projektu i znaleźć miejsca odpowiedzialne za storefront oraz branding sklepu.

Nie wprowadzaj jeszcze dużych zmian wizualnych. To zadanie ma być diagnostyczne i dokumentacyjne.

## Co zrobić

1. Przejrzyj strukturę repozytorium.
2. Znajdź, gdzie znajduje się storefront / aplikacja Next.js, jeśli jest obecna w repo.
3. Znajdź pliki odpowiedzialne za:
   - nazwę sklepu,
   - homepage,
   - layout,
   - header,
   - footer,
   - listę produktów,
   - stronę produktu,
   - konfigurację połączenia ze Spree API.
4. Jeśli storefront nie jest jeszcze obecny w repo, opisz to jasno i wskaż, co trzeba dodać lub wygenerować.
5. Utwórz dokument `docs/storefront-map.md` z mapą znalezionych plików.

## Oczekiwany wynik

Dodaj lub zaktualizuj plik:

```text
 docs/storefront-map.md
```

Dokument ma zawierać:

- krótkie podsumowanie, czy storefront istnieje w repo,
- listę najważniejszych katalogów,
- listę plików do pierwszych zmian brandingowych,
- rekomendowany pierwszy mały commit brandingowy,
- ostrzeżenia, jeśli czegoś brakuje.

## Zasady

- Nie zmieniaj core Spree.
- Nie zmieniaj checkoutu.
- Nie rób redesignu w tym kroku.
- Nie dodawaj nowych zależności.
- Jeśli coś jest niejasne, opisz to w `docs/storefront-map.md` zamiast zgadywać.
- Traktuj projekt `sklepik` jako nadrzędny wobec upstreamowego Spree.

## Commit message

```text
Document storefront structure for Kakao Sklepik MVP
```
