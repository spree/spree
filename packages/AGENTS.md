# TypeScript packages — rules

pnpm workspace + Turbo, Biome for lint and format (`pnpm lint`, `pnpm lint:fix`, `pnpm typecheck`), Vitest for tests. Libraries build with Tsup; the starters and the dashboard bundle with Vite. Follow standard React, TanStack Router/Query, React Hook Form and Zod practice; below is only what this codebase does differently.

**Dependency versions live in the `catalog:` of `pnpm-workspace.yaml`.** A third-party package that two or more workspace packages install is declared as `"catalog:"` (or, in `dashboard-ui`, the catalog's exact version). Every peer dependency also gets a matching dependency or dev dependency, so the workspace installs the catalog version. Peer ranges stay hand-written floors: they are what host apps and plugins must have, and raising one is a breaking change for them. `node scripts/check-dependency-ranges.mjs` (run in CI) enforces all of this, including that the catalog version stays inside each peer range. Separate ranges once left two copies of React Hook Form installed, and the dashboard stopped type checking.

## Packages and boundaries

- `@spree/dashboard-ui` — shadcn primitives on **Base UI (not Radix)**, plus headless composed components. Data comes through props; never import providers or hooks. Add components with the shadcn CLI after checking shadcn doesn't already have one.
- `@spree/dashboard-core` — registries (table, nav, slot, settings nav), providers (auth, permission, store, theme), shared hooks and components (`StoreDatePicker`, `CurrencySelect`, `CountryCombobox`, `CountryStateFields`, `mapSpreeErrorsToForm`, `useResourceMutation`), the admin SDK client and `defineDashboardPlugin`. This is the plugin authors' API.
- `@spree/dashboard` — routes, resource hooks, Zod schemas, locales, app shell. See `docs/plans/6.0-admin-spa.md`.
- `@spree/core` — code any client could use (code lists, enums, money helpers, filter vocabulary). No runtime dependencies. Dashboards import it directly, never through an SDK re-export.
- SDKs: resource-style clients (`client.products.list()`, `client.carts.items.create()`). Response types and Zod schemas under `src/types/generated/` and `src/zod/generated/`, and request types under `src/types/params/`, are **generated from the Ruby API** — never edit them by hand. List params other than `page`, `limit`, `expand`, `sort` and `fields` become Ransack `q[...]` filters.

## Dashboard rules

- **The Admin API is the only data source.** Missing data means adding it to `spree/api` first, then regenerating types. SDK calls are wrapped in hooks under `src/hooks/`, never called from components. Every `queryKey` includes the store id.
- The dashboard typechecks against the SDK's built `dist/`; rebuild the SDK after changing it, and check with `pnpm exec tsc -b`.
- **Translations:** every visible string goes through i18next. Keys live in `packages/dashboard/src/locales/` (app copy) or `packages/dashboard-core/src/locales/` (shared `admin.common.*`, `admin.fields.<attribute>.*`) and are added to **every** language file there. Schemas hold canonical values only; labels are mapped at render time.
- **Listing pages use `<ResourceTable>`** with a `defineTable` definition in `src/tables/`, backed by a paginated `{ data, meta }` endpoint. Reference: `routes/_authenticated/$storeId/settings/policies.tsx`. Panels inside a record use a plain table, but nested collections paginate (`<Pagination meta={meta}>`, totals from `meta.count`) — never a fixed `limit`.
- **Detail pages expose slots:** `<Slot name="<resource>.form_sidebar">` (and `.form_main` where plugin cards belong) with the record in context, documented in `docs/developer/dashboard/slots-catalog.mdx`. Seller panel slots are `seller.<page>.<area>`. A slot inside a form makes it a host form: `<FormProvider>`, `extensionFormValues(...)` in defaults and resets, `extensionSubmitValues(...)` merged into the save payload. Reference: `routes/_authenticated/$storeId/products/collections/$collectionId.tsx`.
- **Forms:** React Hook Form with explicit `register` / `<Controller>`, Zod via `zodResolver`, and `mapSpreeErrorsToForm` in the submit handler's `catch` to route 422s onto fields (`:base` goes to a banner). Labels come from `admin.fields.<resource>.<attribute>.{label,placeholder,help}`. Don't write form↔API mappers to paper over renames — fix the API. Never embed SDK entity types in form-value types (it overflows TypeScript); use an opaque record like `RuleEmbedRecord`. Schemas shared by two or more files go in `src/schemas/`.
- **Destructive actions** that fire straight from a click confirm through `useConfirm({ variant: 'destructive' })`, naming the record or the count. Actions behind a picker sheet or dialog are already confirmed. If the write is immediate inside a dirty-tracked form, the copy says so.
- **Ordering:** a model with `acts_as_list` is reordered by drag and drop (dnd-kit), never a position input. Tables pass `reorder` to `<ResourceTable>` (reference: `settings/payment-methods.tsx`); nested editors follow `products/options.tsx`.
- **Inputs:** dates use `<StoreDatePicker>` (store time zone; pass `inline` inside a Sheet), never `<input type="date">`. Currencies use `CurrencySelect`, countries `CountryCombobox`. Amounts and percentages are `type="number"` inside an `<InputGroup>` showing the currency or `%`. Show and read money in the admin's own format with `useMoneyLocale()`; never `parseFloat` or `Number()` a money string.
- **Base UI quirks:** `<SelectValue>` renders the raw value, so pass `items` to `<Select>` or a render function to `<SelectValue>`. `<Popover>` can fail to open inside a `<Sheet>`; render the panel inline instead (see `dashboard-ui/src/spree/color-picker.tsx`).
- Shell components shared with the seller panel must not require providers the seller panel doesn't mount (it has no `StoreProvider`).

## Releases

Changesets live in the root `.changeset/` (`pnpm changeset`). The API-facing packages version together with the Spree gem version; release with `pnpm version:packages`, never plain `changeset version`.

## End-to-end tests (Playwright)

Specs live in `packages/dashboard/e2e/` — `<resource>.spec.ts` for the admin, `seller-<area>.spec.ts` for the seller panel — and run with `pnpm wt:e2e`. The setup boots its own Rails and Vite and seeds the database. CI shards the suite, so every spec creates its own records and depends on no other file.

- Write them like Capybara: drive the UI by label and role, assert on what is visible. Don't wait on API responses unless there is no visible result to wait for.
- Suffix record names with `Date.now()`. Scope duplicate button names to their dialog.
- Use the `login(page)` helper; only `auth.spec.ts` drives the login form.
- Renaming visible copy or changing layout breaks specs — search `e2e/` before committing either.
