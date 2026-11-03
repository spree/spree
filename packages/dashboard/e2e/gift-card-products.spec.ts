import { expect, type Page, test } from '@playwright/test'
import { login, waitForToastsToClear } from './helpers'
import { card, categorizationCard, createProduct, inventoryCard } from './products-helpers'

const STORE_PATH = (storeId: string) => `/${storeId}/settings/store`

const giftCardSwitch = (page: Page) =>
  page.getByRole('switch', { name: /this product is a gift card/i })

async function saveProduct(page: Page) {
  await page.getByRole('button', { name: /save product/i }).click()
  await expect(page.getByText(/product saved/i)).toBeVisible({ timeout: 30_000 })
  await waitForToastsToClear(page)
}

test.describe('gift card products', () => {
  test('selling a product as a gift card hides stock, tax and shipping', async ({ page }) => {
    const creds = await login(page)
    await createProduct(page, creds.store_id, `E2E Gift Card ${Date.now()}`)

    await expect(inventoryCard(page)).toBeVisible()
    await expect(card(page, /^Tax$/)).toBeVisible()
    await expect(categorizationCard(page).getByText(/shipping profile/i)).toBeVisible()

    await giftCardSwitch(page).click()

    await expect(inventoryCard(page)).toHaveCount(0)
    await expect(card(page, /^Tax$/)).toHaveCount(0)
    await expect(categorizationCard(page).getByText(/shipping profile/i)).toHaveCount(0)

    await saveProduct(page)
    await page.reload()

    await expect(giftCardSwitch(page)).toBeChecked({ timeout: 15_000 })
    await expect(inventoryCard(page)).toHaveCount(0)
    await expect(card(page, /^Tax$/)).toHaveCount(0)
  })

  test('the store sets how long a bought gift card stays spendable', async ({ page }) => {
    const creds = await login(page)
    await page.goto(STORE_PATH(creds.store_id))

    const validity = page.getByLabel(/gift card validity/i)
    await expect(validity).toBeVisible({ timeout: 15_000 })

    await validity.fill('365')
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByRole('button', { name: /^save$/i })).toBeDisabled({ timeout: 15_000 })

    await page.reload()
    await expect(page.getByLabel(/gift card validity/i)).toHaveValue('365', { timeout: 15_000 })

    // Cleared, a bought card never expires — and the next run starts clean.
    await page.getByLabel(/gift card validity/i).fill('')
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByRole('button', { name: /^save$/i })).toBeDisabled({ timeout: 15_000 })
    await page.reload()
    await expect(page.getByLabel(/gift card validity/i)).toHaveValue('', { timeout: 15_000 })
  })
})
