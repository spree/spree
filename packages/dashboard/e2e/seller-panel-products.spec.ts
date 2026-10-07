import { expect, type Page, test } from '@playwright/test'
import { clickBulkAction, FIXTURE_SELLER_WRITER_EMAIL, sellerLogin } from './helpers'

/** Lists a product from the panel's form and returns to the seller's product list. */
async function listProduct(page: Page, home: string, name: string) {
  await page.goto(`${home}/products/new`)
  await page.locator('#product-name').fill(name)
  await page.getByRole('button', { name: /^save$/i }).click()
  await expect(page).toHaveURL(/\/products\/prod_/, { timeout: 20_000 })
  await expect(page.getByRole('heading', { name })).toBeVisible()
}

function productRow(page: Page, name: string) {
  return page.getByRole('row').filter({ hasText: name })
}

async function selectProduct(page: Page, name: string) {
  await productRow(page, name)
    .getByRole('checkbox', { name: /select row/i })
    .check()
}

test.describe('seller panel — products', () => {
  test('renames a listing from its own page', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    const name = `E2E Vase ${Date.now()}`
    await listProduct(page, home, name)

    await page.locator('#product-name').fill(`${name} (large)`)
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/product saved/i)).toBeVisible({ timeout: 15_000 })

    await page.goto(`${home}/products`)
    await expect(productRow(page, `${name} (large)`)).toBeVisible({ timeout: 15_000 })
  })

  // Putting a product on sale is the marketplace's decision; the seller asks.
  test('submits a draft for review', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    const name = `E2E Bowl ${Date.now()}`
    await listProduct(page, home, name)

    await page.goto(`${home}/products`)
    await expect(productRow(page, name).getByText(/^draft$/i)).toBeVisible({ timeout: 15_000 })
    await selectProduct(page, name)
    await clickBulkAction(page, /submit for review/i)
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /submit for review/i })
      .click()

    await expect(productRow(page, name).getByText(/^in review$/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  test('deletes a listing after confirming', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    const name = `E2E Chipped Mug ${Date.now()}`
    await listProduct(page, home, name)

    await page.goto(`${home}/products`)
    await expect(productRow(page, name)).toBeVisible({ timeout: 15_000 })
    await selectProduct(page, name)
    await clickBulkAction(page, /^delete$/i)
    await expect(
      page.getByRole('heading', { name: /delete the selected products\?/i }),
    ).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(productRow(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
