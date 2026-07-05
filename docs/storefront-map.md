# Mapa storefrontu: Kakao Sklepik MVP

## Podsumowanie

Na podstawie obecnej zawartości repozytorium `pawelekbyra/sklepik` nie widać gotowej aplikacji Next.js storefront w kodzie repo.

Repozytorium wygląda obecnie bardziej jak fork/monorepo silnika Spree i narzędzi Spree niż jak gotowy sklep z osobnym storefrontem.

To nie jest błąd. To oznacza tylko, że przed rozpoczęciem zmian wizualnych i brandingowych trzeba najpierw dodać lub wygenerować warstwę storefrontu.

## Co widać w repo

### Root `package.json`

Root projektu ma nazwę `spree` i zawiera skrypty związane głównie z monorepo oraz backendiem/serverem:

- `dev` → `turbo dev`
- `build` → `turbo build`
- `server:create`
- `server:setup`
- `server:dev`
- `server:build`
- `server:restart`
- `server:stop`
- `server:console`
- `server:logs`
- `server:seed`
- `server:load_sample_data`

Ważny wniosek: obecny root nie wygląda jak root samodzielnego storefrontu Next.js.

### `pnpm-workspace.yaml`

Workspace obejmuje:

```yaml
packages:
  - "packages/*"
```

Nie widać tu wpisu typu:

```yaml
apps/*
storefront
apps/storefront
```

Ważny wniosek: jeśli storefront istnieje, nie jest obecnie jasno widoczny jako typowa aplikacja workspace.

### Wyniki wyszukiwania

Nie znaleziono typowych śladów gotowego storefrontu:

- `next.config`
- `app/layout.tsx`
- `app/page.tsx`
- `@spree/storefront`
- `NEXT_PUBLIC`
- `storefront`

Ważny wniosek: branding Kakao Sklepik nie powinien być jeszcze robiony przez edycję losowych plików, bo nie ma potwierdzonej warstwy storefrontu.

## Status storefrontu

**Status: storefront nie jest jeszcze zmapowany jako obecna aplikacja w repo.**

Najbardziej prawdopodobny stan projektu:

1. repo zawiera fundament Spree/core/CLI,
2. backend/server może być tworzony przez `server:create` i `server:setup`,
3. storefront trzeba dodać jako osobną aplikację albo wygenerować zgodnie z kierunkiem Spree.

## Rekomendowany układ docelowy

Docelowo projekt powinien mieć czytelny podział:

```text
sklepik/
├── packages/              # pakiety Spree / SDK / CLI / dashboard
├── server/                # backend/admin Spree generowany lokalnie lub w deployu
├── apps/
│   └── storefront/        # Next.js storefront Kakao Sklepik
├── docs/
└── AGENTS.md
```

Alternatywnie, jeśli projekt będzie trzymany bliżej konwencji Spree:

```text
sklepik/
├── packages/
├── server/
├── storefront/            # Next.js storefront Kakao Sklepik
├── docs/
└── AGENTS.md
```

## Pliki do pierwszych zmian brandingowych

Na razie brak potwierdzonych plików typu:

- homepage,
- layout,
- header,
- footer,
- product listing,
- product page,
- storefront config.

Te pliki powinny zostać zmapowane dopiero po dodaniu storefrontu.

## Rekomendowany pierwszy mały commit brandingowy

Jeszcze nie robić brandingu w kodzie.

Najpierw należy wykonać jeden mały techniczny krok:

**Dodać Next.js storefront jako osobną aplikację projektu.**

Po dodaniu storefrontu kolejny commit powinien dopiero zmienić:

- nazwę sklepu na `Kakao Sklepik`,
- title/meta description,
- header/logo tekstowe,
- footer,
- hero section na stronie głównej,
- przykładowe teksty produktowe.

## Rekomendowany następny prompt dla agenta

```text
Dodaj do repo osobną aplikację Next.js storefront dla Kakao Sklepik.

Założenia:
- projekt nadrzędny to `sklepik`, zgodnie z AGENTS.md,
- storefront ma być osobną aplikacją w `apps/storefront`,
- nie modyfikuj core Spree,
- nie zmieniaj checkoutu backendowego,
- dodaj minimalny Next.js storefront gotowy do dalszego podpięcia pod Spree API,
- użyj TypeScript,
- zachowaj pnpm/turbo workflow,
- zaktualizuj `pnpm-workspace.yaml`, jeśli trzeba,
- dodaj podstawową stronę główną z nazwą `Kakao Sklepik`,
- dodaj README w `apps/storefront/README.md` z opisem uruchamiania i miejsc do konfiguracji API.
```

## Ostrzeżenia

- Nie należy przerabiać plików core Spree na homepage sklepu.
- Nie należy traktować panelu admina jako storefrontu klienta.
- Nie należy deployować całego silnika na Vercel jako jednej aplikacji.
- Vercel będzie dobrym miejscem głównie dla Next.js storefrontu.
- Backend/admin Spree powinien być wdrażany osobno, np. na Render, Fly.io, Railway, VPS albo podobnej platformie.

## Decyzja

Na tym etapie projekt potrzebuje utworzenia wyraźnej warstwy storefrontu.

Dopiero po tym zaczynamy właściwy branding Kakao Sklepik.
