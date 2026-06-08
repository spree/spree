import { expect, type Locator, type Page, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import {
  inventoryCard,
  PRODUCTS_PATH,
  pricesCard,
  seedOptionType,
  variantsCard,
} from './products-helpers'

async function fillGridCell(cell: Locator, value: string): Promise<void> {
  await cell.dblclick()
  await cell.fill(value)
  await cell.blur()
}

async function openNewProduct(page: Page, storeId: string): Promise<void> {
  await gotoIndex(page, PRODUCTS_PATH(storeId), /add product/i)
  await page.getByRole('button', { name: /add product/i }).click()
  await expect(page.getByRole('heading', { name: /^new product$/i })).toBeVisible()
}

// ---------------------------------------------------------------------------
// Simple "single-variant" create — name + price, that's it
// ---------------------------------------------------------------------------

test.describe('new product — simple', () => {
  test('creates a no-options product with one price in one save', async ({ page }) => {
    const creds = await login(page)
    const productName = `E2E New Simple ${Date.now()}`

    await openNewProduct(page, creds.store_id)
    await page.getByLabel(/^name$/i).fill(productName)

    // Set a price on the default variant via the inline Prices card.
    const prices = pricesCard(page)
    await fillGridCell(prices.getByRole('textbox', { name: /^price for default$/i }), '12.50')
    await page.getByRole('button', { name: /^create product$/i }).click()

    // Lands on the edit page.
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 30_000,
    })

    // The price persisted — check the inline Prices card on the edit page.
    await expect(prices.getByRole('textbox', { name: /^price for default$/i })).toHaveValue(
      /^12[.,]5/,
    )
  })
})

// ---------------------------------------------------------------------------
// Multi-variant create — options + SKUs + prices + inventory in one save
// ---------------------------------------------------------------------------

test.describe('new product — multi-variant', () => {
  test('creates with options, SKUs, inline inventory, and prices in one save', async ({ page }) => {
    const creds = await login(page)
    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red', 'blue'])
    const productName = `E2E New Multi ${Date.now()}`

    await openNewProduct(page, creds.store_id)
    await page.getByLabel(/^name$/i).fill(productName)

    // 1. Add the color option with two values via the variants card.
    const card = variantsCard(page)
    await card.getByRole('button', { name: /add option/i }).click()
    await card.getByRole('combobox').first().click()
    await page.getByRole('option', { name: colorLabel, exact: true }).click()
    await card.getByRole('button', { name: 'Red', exact: true }).click()
    await card.getByRole('button', { name: 'Blue', exact: true }).click()
    await card.getByRole('button', { name: /^done$/i }).click()

    // 2. Fill SKUs.
    const skuInputs = card.getByRole('textbox', { name: /^sku$/i })
    await expect(skuInputs).toHaveCount(2, { timeout: 15_000 })
    await skuInputs.nth(0).fill('NEW-RED')
    await skuInputs.nth(1).fill('NEW-BLUE')

    // 3. Set inventory on the first location for both variants.
    const onHand = inventoryCard(page).getByRole('textbox', { name: /^on hand at /i })
    const totalCells = await onHand.count()
    expect(totalCells).toBeGreaterThanOrEqual(2)
    const cellsPerVariant = Math.floor(totalCells / 2)
    await fillGridCell(onHand.nth(0), '3')
    await fillGridCell(onHand.nth(cellsPerVariant), '7')

    // 4. Set prices via the inline Prices card.
    const prices = pricesCard(page)
    await fillGridCell(prices.getByRole('textbox', { name: /price for .*\bred$/i }), '20.00')
    await fillGridCell(prices.getByRole('textbox', { name: /price for .*\bblue$/i }), '22.50')
    await page.getByRole('button', { name: /^create product$/i }).click()

    // Lands on the edit page.
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 30_000,
    })

    // 5. Everything round-tripped — SKUs, inventory, prices. The matrix row
    // label uses `composeOptionsText` ("<Type>: <Value>"), so match the value
    // label suffix instead of the slugged display the matrix used to render.
    await expect(card.getByText(/\bRed$/).first()).toBeVisible({
      timeout: 15_000,
    })
    const reloadedSkus = card.getByRole('textbox', { name: /^sku$/i })
    await expect(reloadedSkus.nth(0)).toHaveValue('NEW-RED')
    await expect(reloadedSkus.nth(1)).toHaveValue('NEW-BLUE')

    const reloadedOnHand = inventoryCard(page).getByRole('textbox', {
      name: /^on hand at /i,
    })
    await expect(reloadedOnHand.nth(0)).toHaveValue('3')
    await expect(reloadedOnHand.nth(cellsPerVariant)).toHaveValue('7')

    await expect(prices.getByRole('textbox', { name: /price for .*\bred$/i })).toHaveValue(
      /^20([.,]0+)?$/,
    )
    await expect(prices.getByRole('textbox', { name: /price for .*\bblue$/i })).toHaveValue(
      /^22[.,]5/,
    )
  })
})
