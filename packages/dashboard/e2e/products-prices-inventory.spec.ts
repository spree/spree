import { expect, type Locator, type Page, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import {
  addOptionToVariants,
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

  // Multi-currency + localized. The inline Prices card switches currency via
  // its header selector; each currency's prices ride the SAME product PATCH.
  // Enter a USD price (period) and a EUR price comma-decimal (`34,56`), save
  // once, and confirm each round-trips in its own currency/locale — proving the
  // per-currency client-side normalization in the batched product update.
  test('sets prices in two currencies (USD period + EUR comma) in one save', async ({ page }) => {
    const creds = await login(page)

    const productName = `E2E Prices Multi-Cur ${Date.now()}`
    await createProduct(page, creds.store_id, productName)

    const card = pricesCard(page)
    // USD default — period decimal.
    await fillGridCell(card.getByRole('textbox', { name: /^price for default$/i }), '12.50')

    // Switch the Prices card to EUR; the grid formats in the EUR market locale
    // (de: comma decimal). Enter `34,56` → must persist as 34.56.
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
    // and confirm the comma-decimal value persisted as 34,56 (not 3456).
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
  // it. Form state holds the canonical API value (`34.56`); under the EUR
  // market locale `.` is a thousands separator, so re-normalizing on save would
  // mangle `34.56` → `3456`. Editing a non-price field must leave the EUR price
  // intact.
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
// Inventory grid — multi-variant: every (variant × location) editable
// ---------------------------------------------------------------------------

test.describe('product inventory — multi-variant', () => {
  test('renders a row for every (variant × location), even ones added later', async ({ page }) => {
    const creds = await login(page)

    // Create a second stock location first — the test then verifies the
    // inventory grid renders editable cells for it on a fresh product
    // (previously it only rendered rows for locations with a persisted
    // stock_item, so the new location showed up without inputs).
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
