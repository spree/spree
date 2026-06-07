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
    // aria-labels ("Price for red" / "Price for blue"). The cell ariaLabel
    // uses the lowercase option-value name (e.g. "red"), because
    // variantDisplayLabel joins `options[].value` which the picker stores
    // as the canonical name, not the display label.
    const prices = pricesCard(page)
    await fillGridCell(prices.getByRole('textbox', { name: /^price for red$/i }), '19.99')
    await fillGridCell(prices.getByRole('textbox', { name: /^price for blue$/i }), '29.99')

    // Save the product via the page-level Save button — prices ride the same
    // PATCH as everything else.
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    // Reload and re-check the inline cells — both prices must round-trip.
    await page.reload()
    await expect(pricesCard(page).getByRole('textbox', { name: /^price for red$/i })).toHaveValue(
      /^19[.,]99$/,
    )
    await expect(pricesCard(page).getByRole('textbox', { name: /^price for blue$/i })).toHaveValue(
      /^29[.,]99$/,
    )
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
    ).toHaveValue(/^12[.,]5/)
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
    await expect(headers.nth(0)).toHaveText('red')
    await expect(headers.nth(1)).toHaveText('blue')
    await expect(headers.nth(2)).toHaveText('green')
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
    await fillGridCell(prices.getByRole('textbox', { name: /^price for red$/i }), '15.00')
    await fillGridCell(prices.getByRole('textbox', { name: /^price for blue$/i }), '17.50')
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

    await expect(pricesCard(page).getByRole('textbox', { name: /^price for red$/i })).toHaveValue(
      /^15([.,]0+)?$/,
    )
    await expect(pricesCard(page).getByRole('textbox', { name: /^price for blue$/i })).toHaveValue(
      /^17[.,]5/,
    )
  })
})
