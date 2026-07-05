import { expect, type Page, test } from '@playwright/test'
import {
  clickBulkAction,
  FIXTURE_BULK_CHANNEL_NAME,
  FIXTURE_BULK_PRODUCT_K,
  FIXTURE_BULK_PRODUCT_L,
  FIXTURE_BULK_PRODUCT_M,
  FIXTURE_BULK_PRODUCT_N,
  gotoIndex,
  login,
} from './helpers'

const PRODUCTS_PATH = (storeId: string) => `/${storeId}/products`
const CTA = /add product/i

async function selectRow(page: Page, productName: string) {
  await page
    .locator('tr')
    .filter({ hasText: productName })
    .getByRole('checkbox', { name: /select row/i })
    .check()
}

test.describe('products channels bulk operations', () => {
  test('lists selected products on a channel via Add to sales channels…', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), CTA)

    await selectRow(page, FIXTURE_BULK_PRODUCT_K)
    await selectRow(page, FIXTURE_BULK_PRODUCT_L)
    await expect(page.getByText(/^2 selected$/)).toBeVisible()

    await clickBulkAction(page, /add to sales channels/i)
    await expect(page.getByRole('heading', { name: /^add to sales channels$/i })).toBeVisible()

    await page
      .getByRole('dialog')
      .getByPlaceholder(/search sales channels/i)
      .fill(FIXTURE_BULK_CHANNEL_NAME)
    await page
      .getByRole('option', { name: new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i') })
      .first()
      .click()
    await page.getByRole('dialog').getByRole('button', { name: /^add$/i }).click()

    await expect(page.getByText(/listed 2 products on sales channels/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  test('unlists selected products from a channel via Remove from sales channels…', async ({
    page,
  }) => {
    const creds = await login(page)
    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), CTA)

    await selectRow(page, FIXTURE_BULK_PRODUCT_M)
    await selectRow(page, FIXTURE_BULK_PRODUCT_N)
    await expect(page.getByText(/^2 selected$/)).toBeVisible()

    await clickBulkAction(page, /remove from sales channels/i)
    await expect(page.getByRole('heading', { name: /^remove from sales channels$/i })).toBeVisible()

    await page
      .getByRole('dialog')
      .getByPlaceholder(/search sales channels/i)
      .fill(FIXTURE_BULK_CHANNEL_NAME)
    await page
      .getByRole('option', { name: new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i') })
      .first()
      .click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^remove$/i })
      .click()

    await expect(page.getByText(/unlisted 2 products from sales channels/i)).toBeVisible({
      timeout: 15_000,
    })
  })
})
