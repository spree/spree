# Kierunek projektu: Kakałowy Sklepik

**Ten dokument jest kanonem całego systemu.** Obowiązuje w obu repozytoriach (`sklepik` i `sklepikFront`). Inne dokumenty i instrukcje agentów odsyłają tutaj — nie duplikują tych sekcji.

## Cel projektu

Budujemy własną platformę e-commerce — sklep internetowy dla produktów kakao (robocza marka: **Kakałowy Sklepik**) — z pełną kontrolą nad kodem, bez ograniczeń zamkniętych platform typu Shopify czy WooCommerce.

Silnikiem commerce jest fork Spree Commerce (Rails + REST API), storefrontem fork oficjalnego Spree Next.js Storefront. Od momentu forka oba repozytoria są rozwijane jako **własny projekt**: Spree pozostaje fundamentem technicznym, ale nie wyznacza celu, brandingu ani roadmapy.

Projekt ma umożliwiać dalszą rozbudowę o moduły premium: storytelling marki, edukację produktową, filmy, quizy, gry, subskrypcje, program lojalnościowy, integracje AI — wszystko czego nie da się sensownie zrobić w klasycznych kreatorach e-commerce.

## Podział repozytoriów

System składa się z dwóch repozytoriów, które działają razem:

```text
pawelekbyra/sklepik
→ silnik commerce, backend Rails, Admin API + Store API, panel administracyjny (React SPA),
  SDK TypeScript, deployment backendu (Render)

pawelekbyra/sklepikFront
→ storefront Next.js, doświadczenie klienta, branding, UX, SEO, deployment na Vercel
```

Zasada: `sklepik` jest źródłem prawdy dla commerce (produkty, ceny, koszyk, zamówienia, płatności). `sklepikFront` konsumuje Store API i nie zawiera logiki biznesowej commerce. Jeśli zmiana wymaga backendu, API albo admina — robi się ją w `sklepik`.

Pełna mapa systemu i hostingu: [`architektura.md`](architektura.md).

## Hierarchia decyzji

W razie konfliktu priorytetów obowiązuje kolejność:

1. Cel projektu Kakałowy Sklepik.
2. Decyzje właściciela projektu.
3. Dokumentacja projektu (`docs/` w obu repo, z tym plikiem jako kanonem).
4. Stabilność zakupów: checkout, koszyk, zamówienia, płatności, produkty, admin.
5. Kompatybilność ze Spree upstream (ułatwia aktualizacje, ale nie jest celem samym w sobie).
6. Oryginalne konwencje Spree.

Jeżeli konwencja upstreamowego Spree przeszkadza w realizacji celu projektu, agent najpierw proponuje bezpieczny wariant rozszerzenia. Jeśli konieczna jest zmiana core silnika, opisuje ją w [`engine-decisions.md`](engine-decisions.md).

## Główna zasada architektoniczna

**Core commerce ma być betonem** — nudny, przewidywalny, niezawodny. Magia projektu powstaje nad corem: w storefroncie, treściach, modułach doświadczenia klienta.

Domyślnie rozszerzamy Spree zamiast modyfikować jego core. Modyfikacja core jest dopuszczalna (docelowo to własna platforma), ale tylko gdy:

1. istnieje jasny powód biznesowy lub techniczny,
2. nie da się tego zrobić przez konfigurację, extension point albo osobny moduł,
3. decyzja zostanie zapisana w `docs/engine-decisions.md`,
4. wpływ na `sklepikFront` (Store API) zostanie uwzględniony.

## Priorytety architektoniczne

1. Utrzymać stabilny silnik sklepu.
2. Budować własne funkcje jako rozszerzenia lub osobne moduły.
3. Trzymać wyraźny podział: backend / admin / storefront.
4. Nie mieszać logiki checkoutu z funkcjami eksperymentalnymi (gry, VOD, AI).
5. Nie hardcodować danych demo w kodzie produkcyjnym.
6. Dbać o możliwość aktualizacji względem upstreamowego Spree.
7. Każda większa decyzja techniczna ma krótkie uzasadnienie w dokumentacji.
8. Dokumentacja w obu repo jest zgodna co do celu, nazw i podziału odpowiedzialności.

## Stack technologiczny

- **Backend:** Rails / fork Spree Commerce (monorepo: `spree/core`, `spree/api` + pakiety TS).
- **Admin:** React SPA (`packages/dashboard`), rozmawia wyłącznie z Admin API.
- **Storefront:** Next.js 16 + React 19 + Tailwind, rozmawia ze Store API przez `@spree/sdk`.
- **Płatności:** Stripe jako domyślny kierunek (jeszcze nieskonfigurowane).
- **Hosting:** Render (backend + Postgres + Redis), Vercel (storefront i admin), Cloudflare R2 (media).

## Fazy projektu

Aktualny stan i szczegółowy plan: [`stan-projektu.md`](stan-projektu.md) i [`roadmap.md`](roadmap.md).

- **Faza 1 — fundament:** oba repo uporządkowane i spójne, cały łańcuch działa: produkt dodany w adminie → widoczny i kupowalny w storefroncie. Usunięte blokery produkcyjne (deploy/migracje, kontrakt cen, walidacja gotowości produktu, cache).
- **Faza 2 — Kakao MVP:** realne produkty kakao, branding premium, strony informacyjne, płatności, strony prawne, domeny.
- **Faza 3 — moduły premium:** storytelling, edukacja, subskrypcje, lojalność i inne przewagi.

## Filozofia

Ten projekt ma być własnym systemem operacyjnym pod markę commerce, a nie szablonowym sklepem. `sklepik` daje kontrolę nad silnikiem. `sklepikFront` daje szybkość, UX i wolność w budowaniu doświadczenia klienta.
