import { expect, type Page, test } from '@playwright/test'
import {
  FIXTURE_LEDGER_RETURNS_LOCATION,
  FIXTURE_LEDGER_SELLER,
  FIXTURE_TRANSFER_SOURCE,
  gotoIndex,
  login,
  openRowMenu,
  rowButton,
} from './helpers'

const STOCK_LOCATIONS_PATH = (storeId: string) => `/${storeId}/settings/stock-locations`
const CTA = /add stock location/i

async function createStockLocation(page: Page, name: string) {
  await page.getByRole('button', { name: /add stock location/i }).click()
  await expect(page.getByRole('heading', { name: /add stock location/i })).toBeVisible()
  await page.locator('#name').fill(name)
  // The sheet's plugin slot, filled by src/testing/slot-probes.tsx.
  await expect(page.getByText('Slot probe: stock_location.form_fields (new)')).toBeVisible()
  await page.getByRole('button', { name: /create stock location/i }).click()
}

test.describe('stock locations', () => {
  test('lists stock locations', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, STOCK_LOCATIONS_PATH(creds.store_id), CTA)
  })

  test("splits your own locations from your sellers' into tabs", async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, STOCK_LOCATIONS_PATH(creds.store_id), CTA)
    const search = page.getByPlaceholder(/search by name/i)
    const sellerColumn = page.getByRole('columnheader', { name: /^seller$/i })

    // Your own opens first: no seller's warehouse, and no seller column.
    await expect(page.getByRole('tab', { name: /^your locations$/i })).toHaveAttribute(
      'aria-selected',
      'true',
    )
    await expect(sellerColumn).toHaveCount(0)
    await search.fill(FIXTURE_TRANSFER_SOURCE)
    await expect(rowButton(page, FIXTURE_TRANSFER_SOURCE)).toBeVisible({ timeout: 15_000 })
    await search.fill(FIXTURE_LEDGER_RETURNS_LOCATION)
    await expect(page.getByText(/no stock locations/i)).toBeVisible({ timeout: 15_000 })

    await page.getByRole('tab', { name: /^sellers' locations$/i }).click()
    await expect(page).toHaveURL(/[?&]view=sellers/)
    await expect(sellerColumn).toBeVisible()
    const sellerRow = page
      .getByRole('row')
      .filter({ has: rowButton(page, FIXTURE_LEDGER_RETURNS_LOCATION) })
    await expect(sellerRow).toContainText(FIXTURE_LEDGER_SELLER, { timeout: 15_000 })
    await search.fill(FIXTURE_TRANSFER_SOURCE)
    await expect(page.getByText(/no stock locations/i)).toBeVisible({ timeout: 15_000 })

    // The tab is in the address, so it survives a reload.
    await page.reload()
    await expect(page.getByRole('tab', { name: /^sellers' locations$/i })).toHaveAttribute(
      'aria-selected',
      'true',
      { timeout: 15_000 },
    )
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
    await expect(page.getByRole('dialog')).toContainText(
      /stock levels at this location will be deleted as well/i,
    )
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
