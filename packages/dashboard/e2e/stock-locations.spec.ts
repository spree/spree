import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const STOCK_LOCATIONS_PATH = (storeId: string) => `/${storeId}/settings/stock-locations`
const CTA = /add stock location/i

async function createStockLocation(page: Page, name: string) {
  await page.getByRole('button', { name: /add stock location/i }).click()
  await expect(page.getByRole('heading', { name: /add stock location/i })).toBeVisible()
  await page.locator('#name').fill(name)
  await page.getByRole('button', { name: /create stock location/i }).click()
}

test.describe('stock locations', () => {
  test('lists stock locations', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, STOCK_LOCATIONS_PATH(creds.store_id), CTA)
  })

  test('creates a new stock location', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, STOCK_LOCATIONS_PATH(creds.store_id), CTA)

    const name = `E2E Warehouse ${Date.now()}`
    await createStockLocation(page, name)

    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
  })

  test('edits a stock location', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, STOCK_LOCATIONS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const original = `E2E Edit Loc ${suffix}`
    const updated = `${original} (updated)`

    await createStockLocation(page, original)
    await expect(rowButton(page, original)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, original).click()
    await expect(page.getByRole('heading', { name: original })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#name')).toHaveValue(original)

    await page.locator('#name').fill(updated)
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(rowButton(page, updated)).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a stock location', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, STOCK_LOCATIONS_PATH(creds.store_id), CTA)

    const name = `E2E Delete Loc ${Date.now()}`
    await createStockLocation(page, name)
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    // Delete now lives on the row-action kebab.
    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete stock location\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
