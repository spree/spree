# Dostęp administracyjny

Gdzie loguje się administrator Kakałowego Sklepiku i gdzie przebiega granica między panelem admina, API i storefrontem.

## Zasada główna

Panel administracyjny należy do repo `sklepik` i jest nim **React SPA** (`packages/dashboard`), dostępny pod `sklepik-gamma.vercel.app` (Vercel, projekt `sklepik_back`). Legacy panel Rails (`spree/admin`) jest wyłączony i służy tylko jako referencja zachowań.

`sklepikFront` nie jest panelem administracyjnym — to storefront dla klientów.

## Role systemu

```text
sklepikFront (Vercel: sklepikkk.vercel.app)
→ storefront dla klientów: katalog, strona produktu, koszyk, checkout
→ rozmawia ze Store API przez @spree/sdk (publishable key)

sklepik / packages/dashboard (Vercel: sklepik-gamma.vercel.app)
→ panel administracyjny: produkty, warianty, ceny, zdjęcia, dostępność,
  zamówienia, płatności, wysyłka, podatki
→ rozmawia z Admin API przez @spree/admin-sdk (JWT; proxy /api/* → Render)

sklepik / backend (Render: kakaowy-sklepik.onrender.com)
→ Store API + Admin API v3, baza, Redis, media (R2)
```

## Docelowy podział domen (po zakupie domeny)

Storefront pod domeną główną; panel admina docelowo pod `/admin/*` tej samej domeny (rewrite Vercela do deploymentu dashboardu) albo pod subdomeną `admin.`; backend pod subdomeną `api.`. Do tego czasu obowiązują adresy `*.vercel.app` / `*.onrender.com` z [`architektura.md`](architektura.md).

## Konto admina

Pierwsze konto tworzy seed backendu (`spree/core/app/services/spree/seeds/admin_user.rb`; nadpisywalne `ADMIN_EMAIL`/`ADMIN_PASSWORD` przy seedzie). Nie commitujemy do repo: loginów produkcyjnych, haseł, tokenów, kluczy API. Dane kont developerskich mogą istnieć tylko dla środowiska lokalnego i muszą być opisane jako nieprodukcyjne.

## Relacja do storefrontu

Zmiana produktu w panelu admina trafia do storefrontu wyłącznie przez Store API. Storefront nie omija backendu i nie utrzymuje własnego źródła prawdy dla produktów, cen, koszyka ani zamówień. (Uwaga: do czasu wdrożenia rewalidacji cache — roadmapa F4 — zmiany widać w storefroncie z opóźnieniem TTL do ~15 min.)

## Kiedy aktualizować ten dokument

Gdy zmienia się: sposób tworzenia konta admina, domeny, deployment, zasady dostępu do API albo rozdział odpowiedzialności admin/API/storefront.
