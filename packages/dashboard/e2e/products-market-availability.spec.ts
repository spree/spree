import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import { PRODUCTS_PATH, publishingCard } from './products-helpers'

// The seeded store has a EUR market named "Europe" beside its default US one
// (see global-setup.ts).
const MARKET = 'Europe'

async function createProduct(page: Page, storeId: string, name: string): Promise<void> {
  await gotoIndex(page, PRODUCTS_PATH(storeId), /add product/i)
  await page.getByRole('button', { name: /add product/i }).click()
  await expect(page.getByRole('heading', { name: /^new product$/i })).toBeVisible()
  await page.getByLabel(/^name$/i).fill(name)
  await page.getByRole('button', { name: /^create product$/i }).click()
  await expect(page).toHaveURL(new RegExp(`/${storeId}/products/prod_[^/]+$`), { timeout: 30_000 })
}

async function chooseMode(page: Page, mode: RegExp): Promise<void> {
  await publishingCard(page)
    .getByRole('combobox', { name: /^sold in$/i })
    .click()
  await page.getByRole('option', { name: mode }).click()
}

test.describe('product market availability', () => {
  test('keeps a product out of a market and reads it back', async ({ page }) => {
    const creds = await login(page)
    await createProduct(page, creds.store_id, `E2E Market Exclusion ${Date.now()}`)

    const card = publishingCard(page)
    await expect(card.getByText(/customers in every market can see and buy/i)).toBeVisible()

    await chooseMode(page, /^all markets except/i)
    await card.getByPlaceholder(/choose markets/i).fill(MARKET)
    await page.getByRole('option', { name: new RegExp(`^${MARKET}$`, 'i') }).click()
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 15_000,
    })

    await page.reload()
    const reloaded = publishingCard(page)
    await expect(reloaded.getByRole('combobox', { name: /^sold in$/i })).toHaveText(
      /all markets except/i,
      { timeout: 15_000 },
    )
    await expect(reloaded.locator('[data-slot="combobox-chip"]', { hasText: MARKET })).toBeVisible()
  })

  test('refuses a restricted mode with no market named', async ({ page }) => {
    const creds = await login(page)
    await createProduct(page, creds.store_id, `E2E Market Required ${Date.now()}`)

    await chooseMode(page, /^only in/i)
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(publishingCard(page).getByText(/must name at least one market/i)).toBeVisible()

    // Nothing was saved: the product still sells everywhere.
    await page.reload()
    await expect(publishingCard(page).getByRole('combobox', { name: /^sold in$/i })).toHaveText(
      /^all markets$/i,
      { timeout: 15_000 },
    )
  })
})
