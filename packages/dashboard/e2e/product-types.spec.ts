import { expect, test } from '@playwright/test'
import { FIXTURE_PROMO_TAXON, gotoIndex, login } from './helpers'

const PATH = (storeId: string) => `/${storeId}/settings/product-types`
const CTA = /add product type/i

test.describe('product types', () => {
  test('lists product types', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)
  })

  test('creates a product type', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)

    const name = `E2E Collectable ${Date.now()}`

    await page.getByRole('button', { name: CTA }).click()
    await expect(page.getByRole('heading', { name: /new product type/i })).toBeVisible()

    await page.locator('#name').fill(name)
    await page.getByRole('button', { name: /create product type/i }).click()

    await expect(page.getByText(name)).toBeVisible({ timeout: 15_000 })
  })

  test('closes the sheet on Escape from a category picker holding a choice', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)

    await page.getByRole('button', { name: CTA }).click()
    const heading = page.getByRole('heading', { name: /new product type/i })
    await expect(heading).toBeVisible()

    const categoriesField = page
      .getByRole('dialog')
      .locator('[data-slot="field"]')
      .filter({ has: page.getByText('Categories', { exact: true }) })
    const search = categoriesField.getByRole('combobox')
    await search.fill(FIXTURE_PROMO_TAXON)
    await page
      .getByRole('option', { name: new RegExp(FIXTURE_PROMO_TAXON, 'i') })
      .first()
      .click()
    await expect(categoriesField.locator('[data-slot="combobox-chip"]')).toHaveCount(1)
    await expect(page.getByRole('listbox')).toBeHidden()
    await expect(search).toBeFocused()

    await page.keyboard.press('Escape')
    await expect(heading).toBeHidden()
  })

  test('rejects a product type with no name', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)

    await page.getByRole('button', { name: CTA }).click()
    await page.getByRole('button', { name: /create product type/i }).click()

    // Client-side validation keeps the sheet open with an error.
    await expect(page.getByRole('heading', { name: /new product type/i })).toBeVisible()
  })
})
