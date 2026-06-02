import { expect, type Locator, type Page, test } from '@playwright/test'
import { FIXTURE_BULK_CHANNEL_NAME, gotoIndex, login } from './helpers'

const PRODUCTS_PATH = (storeId: string) => `/${storeId}/products`
const ADD_CTA = /add product/i

/**
 * Drive the New Product form to create a fresh record and wait until the
 * router lands on the edit page.
 */
async function createProduct(page: Page, storeId: string, name: string, description?: string) {
  await gotoIndex(page, PRODUCTS_PATH(storeId), ADD_CTA)
  await page.getByRole('button', { name: ADD_CTA }).click()

  await expect(page.getByRole('heading', { name: /^new product$/i })).toBeVisible()
  await page.getByLabel(/^name$/i).fill(name)
  if (description) {
    await page.getByLabel(/^description$/i).fill(description)
  }
  await page.getByRole('button', { name: /^create product$/i }).click()

  // Lands on `/$storeId/products/$productId` (not `/new`).
  await expect(page).toHaveURL(new RegExp(`/${storeId}/products/prod_[^/]+$`), { timeout: 15_000 })
}

/**
 * Locator for the Publishing card on the edit page. `<CardTitle>` is a
 * `<div>` (not a heading), so we anchor on the `data-slot` shadcn emits.
 */
function publishingCard(page: Page): Locator {
  return page
    .locator('[data-slot="card"]')
    .filter({ has: page.locator('[data-slot="card-title"]', { hasText: /^Publishing$/ }) })
}

test.describe('product edit', () => {
  test('creates a product and lands on the edit page', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Product Create ${Date.now()}`

    await createProduct(page, creds.store_id, name, 'Initial description')

    // The Name input on the edit page mirrors the saved name.
    await expect(page.getByLabel(/^name$/i)).toHaveValue(name)
  })

  test('updates name on an existing product', async ({ page }) => {
    const creds = await login(page)
    const original = `E2E Product Update ${Date.now()}`
    const updated = `${original} (updated)`

    await createProduct(page, creds.store_id, original)

    await page.getByLabel(/^name$/i).fill(updated)
    await page.getByRole('button', { name: /save product/i }).click()

    // After a successful save the button disables again (RHF `isDirty`
    // resets via `reset(updatedValues)`). Asserting on disabled state avoids
    // coupling to toast strings, which aren't stable across i18n updates.
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 15_000,
    })

    await page.reload()
    await expect(page.getByLabel(/^name$/i)).toHaveValue(updated)
  })

  test('lists a product on an additional channel via the publishing card', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Product Publish ${Date.now()}`

    await createProduct(page, creds.store_id, name)

    // New products auto-publish on the store's default channel ("Online
    // Store"), so the card is non-empty from the start. Assert the bulk
    // channel isn't there yet, then add it via Manage.
    const card = publishingCard(page)
    await expect(card.getByText(new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i'))).not.toBeVisible()

    await card.getByRole('button', { name: /^manage$/i }).click()
    await expect(page.getByRole('heading', { name: /^manage sales channels$/i })).toBeVisible()

    await page
      .getByRole('dialog')
      .getByRole('button', { name: new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i') })
      .click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^done$/i })
      .click()

    await expect(card.getByText(new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i'))).toBeVisible()

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 15_000,
    })

    // After reload the publication is still attached.
    await page.reload()
    await expect(
      publishingCard(page).getByText(new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i')),
    ).toBeVisible()
  })
})
