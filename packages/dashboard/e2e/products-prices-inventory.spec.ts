import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { expect, type Locator, type Page, test } from '@playwright/test'
import { getCredentials, gotoIndex, login } from './helpers'
import { E2E_DIR } from './paths'
import {
  addOptionToVariants,
  card,
  createProduct,
  inventoryCard,
  pricesCard,
  seedOptionType,
  variantsCard,
} from './products-helpers'

const STOCK_LOCATIONS_PATH = (storeId: string) => `/${storeId}/settings/stock-locations`

async function createStockLocation(page: Page, storeId: string, name: string): Promise<void> {
  await gotoIndex(page, STOCK_LOCATIONS_PATH(storeId), /add stock location/i)
  await page.getByRole('button', { name: /add stock location/i }).click()
  await expect(page.getByRole('heading', { name: /add stock location/i })).toBeVisible()
  await page.locator('#name').fill(name)
  await page.getByRole('button', { name: /create stock location/i }).click()
  await expect(page.getByRole('heading', { name: /add stock location/i })).toBeHidden({
    timeout: 15_000,
  })
}

/**
 * DataGrid `<MoneyCell>` and `<NumberCell>` render `<input readonly>` until
 * the cell is in edit mode — `dblclick` triggers `setEditing(coords)` which
 * focuses the input and clears `readOnly`. After that, `fill()` works as
 * usual. Blur commits.
 */
async function fillGridCell(cell: Locator, value: string): Promise<void> {
  await cell.dblclick()
  await cell.fill(value)
  await cell.blur()
}

/**
 * `<SwitchCell>` is a focusable `<div role="switch">` wrapping a `<Switch>`.
 * Click the wrapper to focus, then press Space to toggle — the keyboard path
 * is the one the cell handles directly (the inner Switch is `tabIndex={-1}`).
 */
async function toggleGridSwitch(cell: Locator): Promise<void> {
  await cell.focus()
  await cell.press(' ')
}

// ---------------------------------------------------------------------------
// Bulk price editor — product scope, multi-variant
// ---------------------------------------------------------------------------

test.describe('product prices — multi-variant', () => {
  test('sets prices on unsaved variants and round-trips after save', async ({ page }) => {
    const creds = await login(page)

    // Generate options for a multi-variant product.
    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red', 'blue'])

    const productName = `E2E Prices Multi ${Date.now()}`
    await createProduct(page, creds.store_id, productName)
    await addOptionToVariants(page, colorLabel, ['Red', 'Blue'])

    // The Prices card is inline — no dialog. Fill the two cells via their
    // aria-labels. The cell ariaLabel is `Price for ${variant.label}`, where
    // `label` comes from `composeOptionsText` ("<Type>: <Value>"), so we
    // anchor on the trailing value label.
    const prices = pricesCard(page)
    await fillGridCell(prices.getByRole('textbox', { name: /^price for .*\bred$/i }), '19.99')
    await fillGridCell(prices.getByRole('textbox', { name: /^price for .*\bblue$/i }), '29.99')

    // Save the product via the page-level Save button — prices ride the same
    // PATCH as everything else.
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    // Reload and re-check the inline cells — both prices must round-trip.
    await page.reload()
    await expect(
      pricesCard(page).getByRole('textbox', { name: /^price for .*\bred$/i }),
    ).toHaveValue(/^19[.,]99$/)
    await expect(
      pricesCard(page).getByRole('textbox', { name: /^price for .*\bblue$/i }),
    ).toHaveValue(/^29[.,]99$/)
  })
})

// ---------------------------------------------------------------------------
// Bulk price editor — product scope, single-variant (no options)
// ---------------------------------------------------------------------------

test.describe('product prices — single variant', () => {
  test('sets and persists a price on a simple (no-options) product', async ({ page }) => {
    const creds = await login(page)

    const productName = `E2E Prices Single ${Date.now()}`
    await createProduct(page, creds.store_id, productName)

    // No options added — the variants section shows a single "Default variant"
    // row backed by the auto-created default variant from product creation.
    // The inline Prices card's single cell ariaLabel falls back to the
    // variant-default label ("Default variant") since the variant has no
    // options_text.
    const prices = pricesCard(page)
    await fillGridCell(prices.getByRole('textbox', { name: /^price for default$/i }), '12.50')

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()
    await expect(
      pricesCard(page).getByRole('textbox', { name: /^price for default$/i }),
    ).toHaveValue(/^12[.,]50?$/)
  })

  // `fillGridCell` leaves a cell with a scripted `blur()`. A merchant leaves it
  // by clicking somewhere else, which the browser dispatches differently — and
  // that path used to drop the value the cell was showing.
  test('keeps price and stock edits left by clicking elsewhere', async ({ page }) => {
    const creds = await login(page)

    const productName = `E2E Click Away ${Date.now()}`
    await createProduct(page, creds.store_id, productName)

    const price = pricesCard(page).getByRole('textbox', { name: /^price for default$/i })
    await price.dblclick()
    await price.fill('19.99')
    await page.getByLabel(/^name$/i).click()
    await expect(price).toHaveValue(/^19[.,]99$/)

    const onHand = inventoryCard(page)
      .getByRole('textbox', { name: /^on hand at /i })
      .first()
    await onHand.dblclick()
    await onHand.fill('12')
    // Still in edit mode when Save is clicked.
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()
    await expect(
      pricesCard(page).getByRole('textbox', { name: /^price for default$/i }),
    ).toHaveValue(/^19[.,]99$/)
    await expect(
      inventoryCard(page)
        .getByRole('textbox', { name: /^on hand at /i })
        .first(),
    ).toHaveValue('12')
  })

  // Multi-currency. The inline Prices card switches currency via its header
  // selector; each currency's prices ride the SAME product PATCH. A USD price
  // with a period and a EUR price with a comma (`34,56`, a comma before two
  // digits being read as the decimal) both round-trip from one save.
  test('sets prices in two currencies (USD period + EUR comma) in one save', async ({ page }) => {
    const creds = await login(page)

    const productName = `E2E Prices Multi-Cur ${Date.now()}`
    await createProduct(page, creds.store_id, productName)

    const card = pricesCard(page)
    // USD default — period decimal.
    await fillGridCell(card.getByRole('textbox', { name: /^price for default$/i }), '12.50')

    // Switch the Prices card to EUR. Enter `34,56` → must persist as 34.56.
    await card.getByRole('combobox').first().click()
    await page.getByRole('option', { name: 'EUR' }).click()
    await fillGridCell(card.getByRole('textbox', { name: /^price for default$/i }), '34,56')

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()
    const reloaded = pricesCard(page)
    // EUR cell is shown after reload (card defaults back to USD); switch to EUR
    // and confirm the comma-typed value persisted as 34.56 (not 3456).
    await reloaded.getByRole('combobox').first().click()
    await page.getByRole('option', { name: 'EUR' }).click()
    await expect(reloaded.getByRole('textbox', { name: /^price for default$/i })).toHaveValue(
      /^34[.,]56$/,
    )
    // Back to USD — independent value.
    await reloaded.getByRole('combobox').first().click()
    await page.getByRole('option', { name: 'USD' }).click()
    await expect(reloaded.getByRole('textbox', { name: /^price for default$/i })).toHaveValue(
      /^12[.,]5/,
    )
  })

  // Regression: a save that includes an UNTOUCHED EUR price must not re-parse
  // it. Form state holds the canonical API value (`34.56`); re-normalizing it
  // on save under a comma-decimal format would mangle it to `3456`. Editing a
  // non-price field must leave the EUR price intact.
  test('preserves an untouched EUR price when saving an unrelated field', async ({ page }) => {
    const creds = await login(page)

    const productName = `E2E Untouched EUR ${Date.now()}`
    await createProduct(page, creds.store_id, productName)

    // Set a EUR price comma-decimal and save.
    const card = pricesCard(page)
    await card.getByRole('combobox').first().click()
    await page.getByRole('option', { name: 'EUR' }).click()
    await fillGridCell(card.getByRole('textbox', { name: /^price for default$/i }), '34,56')
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()

    // Touch ONLY the name — do not open/edit the EUR price cell.
    await page.getByLabel(/^name$/i).fill(`${productName} (edited)`)
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()
    const reloaded = pricesCard(page)
    await reloaded.getByRole('combobox').first().click()
    await page.getByRole('option', { name: 'EUR' }).click()
    // Still 34,56 — NOT 3.456 / 3456 (which a re-normalize on save would yield).
    await expect(reloaded.getByRole('textbox', { name: /^price for default$/i })).toHaveValue(
      /^34[.,]56$/,
    )
  })
})

// ---------------------------------------------------------------------------
// Money entry — the person's own number format, any currency, any market
// ---------------------------------------------------------------------------

// Prices are shown and typed in the number format of the person using the
// dashboard, whatever the currency or market, and saving the product again must
// leave them as they are. The API returns "49.5" for 49.50 until amounts are
// written to the currency's decimals, so the expectations allow the trailing
// zero to be missing; what they rule out is a separator read the wrong way.
test.describe('product prices — number format', () => {
  // The German labels the product page shows, read from the dashboard's own
  // translations so the spec follows them.
  const germanLocale = JSON.parse(
    readFileSync(resolve(E2E_DIR, '../../dashboard-core/src/locales/de.json'), 'utf-8'),
  ) as Record<string, unknown>
  const inGerman = (key: string): string =>
    key
      .split('.')
      .reduce<unknown>(
        (node, part) => (node as Record<string, unknown>)[part],
        germanLocale,
      ) as string
  const german = {
    prices: inGerman('admin.common.prices'),
    priceForDefault: new RegExp(
      `^${inGerman('admin.pages.products.price_lists.edit_prices.price_aria').replace(
        '{{label}}',
        inGerman('admin.pages.products.price_lists.edit_prices.variant_default'),
      )}$`,
    ),
    save: inGerman('admin.products.save_label'),
  }

  function priceCell(card: Locator, name: string | RegExp = /^price for default$/i): Locator {
    return card.getByRole('textbox', { name })
  }

  async function showCurrency(page: Page, card: Locator, currency: string): Promise<void> {
    await card.getByRole('combobox').first().click()
    await page.getByRole('option', { name: currency }).click()
  }

  async function saveProduct(page: Page, label: string | RegExp = /save product/i): Promise<void> {
    await page.getByRole('button', { name: label }).click()
    await expect(page.getByRole('button', { name: label })).toBeDisabled({ timeout: 30_000 })
  }

  // Saves the product with only its name changed, the way a merchant saves it
  // again without opening the prices.
  async function saveAgainUntouched(page: Page, name: string): Promise<void> {
    await page.reload()
    await page.getByLabel(/^name$/i).fill(name)
    await saveProduct(page)
  }

  test('an English-speaking admin types every currency with a period, and repeated saves keep it', async ({
    page,
  }) => {
    const creds = await login(page)
    const productName = `E2E Period ${Date.now()}`
    await createProduct(page, creds.store_id, productName)

    const card = pricesCard(page)
    await fillGridCell(priceCell(card), '1,234.56')
    // EUR's market writes German, but the person typing writes English.
    await showCurrency(page, card, 'EUR')
    await fillGridCell(priceCell(card), '49.50')
    await saveProduct(page)

    await saveAgainUntouched(page, `${productName} (2)`)
    await saveAgainUntouched(page, `${productName} (3)`)

    await page.reload()
    const reloaded = pricesCard(page)
    await expect(priceCell(reloaded)).toHaveValue('1234.56')
    await showCurrency(page, reloaded, 'EUR')
    await expect(priceCell(reloaded)).toHaveValue(/^49\.50?$/)
  })

  test.describe('in German', () => {
    let savedLocale: string | null = null

    async function authHeaders(page: Page) {
      const creds = getCredentials()
      const res = await page.request.post('/api/v3/admin/auth/login', {
        data: { email: creds.admin_email, password: creds.admin_password },
      })
      const { token } = (await res.json()) as { token: string }
      return { Authorization: `Bearer ${token}` }
    }

    // Switch the shared account and the browser together: when they disagree
    // the dashboard reloads mid-boot (see validation-messages.spec.ts).
    async function speakGerman(page: Page): Promise<void> {
      await page.addInitScript(() => localStorage.setItem('spree-admin-locale', 'de'))
      const headers = await authHeaders(page)
      const me = await page.request.get('/api/v3/admin/me', { headers })
      savedLocale = ((await me.json()) as { user: { selected_locale: string | null } }).user
        .selected_locale
      await page.request.patch('/api/v3/admin/me', { headers, data: { selected_locale: 'de' } })
    }

    test.afterEach(async ({ page }) => {
      const headers = await authHeaders(page)
      await page.request.patch('/api/v3/admin/me', {
        headers,
        data: { selected_locale: savedLocale },
      })
    })

    test('a German-speaking admin types every currency with a comma, and repeated saves keep it', async ({
      page,
    }) => {
      const creds = await login(page)
      const productName = `E2E Comma ${Date.now()}`
      await createProduct(page, creds.store_id, productName)
      await speakGerman(page)
      await page.reload()

      const prices = germanPricesCard(page)
      // USD's market writes English, but the person typing writes German.
      await fillGridCell(priceCell(prices, german.priceForDefault), '1.234,56')
      await showCurrency(page, prices, 'EUR')
      await fillGridCell(priceCell(prices, german.priceForDefault), '49,50')
      await saveProduct(page, german.save)

      for (const round of [2, 3]) {
        await page.reload()
        await page.getByLabel(/^name$/i).fill(`${productName} (${round})`)
        await saveProduct(page, german.save)
      }

      await page.reload()
      const reloaded = germanPricesCard(page)
      await expect(priceCell(reloaded, german.priceForDefault)).toHaveValue('1234,56')
      await showCurrency(page, reloaded, 'EUR')
      await expect(priceCell(reloaded, german.priceForDefault)).toHaveValue(/^49,50?$/)
    })

    function germanPricesCard(page: Page): Locator {
      return card(page, new RegExp(`^${german.prices}$`))
    }
  })

  // The reported bug: in a store whose default market writes a comma decimal,
  // the server read "49.50" as 4950, and every save of an unchanged 99 added a
  // zero. The store also sells in USD through a second market.
  for (const [typed, shown] of [
    ['49.50', /^49\.50?$/],
    ['99', /^99(\.0+)?$/],
    ['1,234.56', /^1234\.56$/],
  ] as const) {
    test(`a store whose market writes a comma decimal saves ${typed} exactly`, async ({ page }) => {
      const creds = await login(page)
      const productName = `E2E Dutch ${typed} ${Date.now()}`
      await createProduct(page, creds.comma_store_id, productName)
      const card = pricesCard(page)
      await fillGridCell(priceCell(card), typed)
      await showCurrency(page, card, 'USD')
      await fillGridCell(priceCell(card), typed)
      await saveProduct(page)

      await saveAgainUntouched(page, `${productName} (2)`)
      await saveAgainUntouched(page, `${productName} (3)`)

      await page.reload()
      const reloaded = pricesCard(page)
      await expect(priceCell(reloaded)).toHaveValue(shown)
      await showCurrency(page, reloaded, 'USD')
      await expect(priceCell(reloaded)).toHaveValue(shown)
    })
  }
})

// ---------------------------------------------------------------------------
// Inventory grid — multi-variant: every (variant × location) editable
// ---------------------------------------------------------------------------

test.describe('product inventory — multi-variant', () => {
  test('renders a row for every (variant × location), even ones added later', async ({ page }) => {
    const creds = await login(page)

    // Create a second stock location first — the test then verifies the
    // inventory grid renders editable cells for it on a fresh product
    // (previously it only rendered rows for locations with a persisted
    // stock_level, so the new location showed up without inputs).
    const locationName = `E2E Warehouse ${Date.now()}`
    await createStockLocation(page, creds.store_id, locationName)

    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red', 'blue'])

    const productName = `E2E Inventory Multi ${Date.now()}`
    await createProduct(page, creds.store_id, productName)
    await addOptionToVariants(page, colorLabel, ['Red', 'Blue'])

    const grid = inventoryCard(page)

    // The grid must show "On hand at <locationName>" cells for the new
    // location, for BOTH variants, BEFORE the product is saved.
    const onHandAtNewLoc = grid.getByRole('textbox', {
      name: new RegExp(`^on hand at ${locationName}$`, 'i'),
    })
    await expect(onHandAtNewLoc).toHaveCount(2, { timeout: 15_000 })

    // Set a value at the new location for the first variant (Red).
    await fillGridCell(onHandAtNewLoc.first(), '42')

    // Toggle backorder on for that same row.
    const backorderAtNewLoc = grid.getByRole('switch', {
      name: new RegExp(`^allow backorder at ${locationName}$`, 'i'),
    })
    await toggleGridSwitch(backorderAtNewLoc.first())

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    // Reload — both values must round-trip on the first variant's row.
    await page.reload()
    const grid2 = inventoryCard(page)
    await expect(
      grid2.getByRole('textbox', { name: new RegExp(`^on hand at ${locationName}$`, 'i') }).first(),
    ).toHaveValue('42')
    await expect(
      grid2
        .getByRole('switch', { name: new RegExp(`^allow backorder at ${locationName}$`, 'i') })
        .first(),
    ).toBeChecked()
  })

  test('groups inventory rows by variant header when there are multiple variants', async ({
    page,
  }) => {
    const creds = await login(page)
    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red', 'blue', 'green'])

    const productName = `E2E Inventory Headers ${Date.now()}`
    await createProduct(page, creds.store_id, productName)
    await addOptionToVariants(page, colorLabel, ['Red', 'Blue', 'Green'])

    // Each variant gets a header section. `renderSectionHeader` outputs a
    // `<div class="truncate font-medium">`, which is unique to inventory
    // section headers (other font-medium uses on the page don't add
    // `truncate`). Scope to the inventory card to avoid the matrix's
    // identically-named variant rows above.
    const grid = inventoryCard(page)
    const headers = grid.locator('div.truncate.font-medium')
    await expect(headers).toHaveCount(3, { timeout: 15_000 })
    await expect(headers.nth(0)).toHaveText(/\bRed$/)
    await expect(headers.nth(1)).toHaveText(/\bBlue$/)
    await expect(headers.nth(2)).toHaveText(/\bGreen$/)
  })
})

// ---------------------------------------------------------------------------
// Inventory grid — single variant (no options)
// ---------------------------------------------------------------------------

test.describe('product inventory — single variant', () => {
  test('shows one row per stock location for the default variant', async ({ page }) => {
    const creds = await login(page)

    const productName = `E2E Inventory Single ${Date.now()}`
    await createProduct(page, creds.store_id, productName)

    // No options added — single default variant, but still one row per stock
    // location. The default location's row is editable on a fresh product.
    const grid = inventoryCard(page)
    const onHand = grid.getByRole('textbox', { name: /^on hand at /i })
    await expect(onHand.first()).toBeVisible({ timeout: 15_000 })

    await fillGridCell(onHand.first(), '7')

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()
    await expect(
      inventoryCard(page)
        .getByRole('textbox', { name: /^on hand at /i })
        .first(),
    ).toHaveValue('7')
  })
})

// ---------------------------------------------------------------------------
// Cross-feature: full configuration in one save
// ---------------------------------------------------------------------------

test.describe('product variants × prices × inventory', () => {
  test('configures everything for a multi-variant product in one save', async ({ page }) => {
    const creds = await login(page)
    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red', 'blue'])

    const productName = `E2E Full Cycle ${Date.now()}`
    await createProduct(page, creds.store_id, productName)

    // 1. Generate variants from options.
    await addOptionToVariants(page, colorLabel, ['Red', 'Blue'])

    // 2. Fill SKUs inline in the variants matrix.
    const card = variantsCard(page)
    const skuInputs = card.getByRole('textbox', { name: /^sku$/i })
    await skuInputs.nth(0).fill('FULL-RED')
    await skuInputs.nth(1).fill('FULL-BLUE')

    // 3. Set inventory at the FIRST stock location for both variants. The
    //    DataGrid emits one header row per variant (`div.truncate.font-medium`)
    //    and one input row per (variant × location). Stock locations may
    //    accumulate across the suite, so we pick the first location's first
    //    on-hand input per variant by indexing into the per-variant slice.
    const grid = inventoryCard(page)
    const onHand = grid.getByRole('textbox', { name: /^on hand at /i })
    // 2 variants × N locations. First per-variant slot = first overall, then
    // we jump N to reach the second variant's first location. Compute N from
    // the on-hand field count divided by variant count (2).
    const totalCells = await onHand.count()
    expect(totalCells).toBeGreaterThanOrEqual(2)
    const cellsPerVariant = Math.floor(totalCells / 2)
    await fillGridCell(onHand.nth(0), '5')
    await fillGridCell(onHand.nth(cellsPerVariant), '10')

    // 4. Set prices for both variants via the inline Prices card. The
    //    product-level Save persists everything (SKUs, inventory, prices)
    //    in one PATCH.
    const prices = pricesCard(page)
    await fillGridCell(prices.getByRole('textbox', { name: /^price for .*\bred$/i }), '15.00')
    await fillGridCell(prices.getByRole('textbox', { name: /^price for .*\bblue$/i }), '17.50')
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    // 5. Reload and assert everything round-trips.
    await page.reload()
    await expect(skuInputs.nth(0)).toHaveValue('FULL-RED')
    await expect(skuInputs.nth(1)).toHaveValue('FULL-BLUE')
    const reloadedOnHand = inventoryCard(page).getByRole('textbox', { name: /^on hand at /i })
    await expect(reloadedOnHand.nth(0)).toHaveValue('5')
    await expect(reloadedOnHand.nth(cellsPerVariant)).toHaveValue('10')

    await expect(
      pricesCard(page).getByRole('textbox', { name: /^price for .*\bred$/i }),
    ).toHaveValue(/^15([.,]0+)?$/)
    await expect(
      pricesCard(page).getByRole('textbox', { name: /^price for .*\bblue$/i }),
    ).toHaveValue(/^17[.,]50?$/)
  })
})
