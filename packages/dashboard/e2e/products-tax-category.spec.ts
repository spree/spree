import { expect, type Page, test } from '@playwright/test'
import { login, rowButton } from './helpers'
import {
  addOptionToVariants,
  createProduct,
  seedOptionType,
  variantsCard as variantsCardLocator,
} from './products-helpers'

const TAX_CATEGORIES_PATH = (storeId: string) => `/${storeId}/settings/tax-categories`

async function createTaxCategory(page: Page, name: string) {
  await page.getByRole('button', { name: /add tax category/i }).click()
  await expect(page.getByRole('heading', { name: /add tax category/i })).toBeVisible()
  await page.locator('#name').fill(name)
  await page.getByRole('button', { name: /create tax category/i }).click()
  await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
}

function taxCard(page: Page) {
  return page.locator('[data-slot="card"]').filter({
    has: page.getByText(/^tax$/i),
  })
}

async function selectProductTaxCategory(page: Page, categoryName: string) {
  const card = taxCard(page)
  await card.scrollIntoViewIfNeeded()
  await card.getByRole('combobox').click()
  await page.getByRole('option', { name: categoryName }).click()
}

test.describe('product tax category', () => {
  test('shows guidance and clears a variant override on save', async ({ page }) => {
    const creds = await login(page)
    const suffix = Date.now()
    const variantCategory = `E2E Variant Tax ${suffix}`
    const productCategory = `E2E Product Tax ${suffix}`

    await page.goto(TAX_CATEGORIES_PATH(creds.store_id))
    await createTaxCategory(page, variantCategory)
    await createTaxCategory(page, productCategory)

    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red', 'blue'])
    const productName = `E2E Product Tax ${suffix}`
    await createProduct(page, creds.store_id, productName)
    await addOptionToVariants(page, colorLabel, ['Red', 'Blue'])

    const applyToVariantsNotice = page.getByText(
      /applies to every variant that does not have its own tax category/i,
    )
    await expect(applyToVariantsNotice).toHaveCount(0)

    const variantsCard = variantsCardLocator(page)
    await variantsCard.getByRole('button', { name: /^edit .*\bred$/i }).click()
    const sheet = page.getByRole('dialog')
    await sheet.getByLabel(/^tax category$/i).click()
    await page.getByRole('option', { name: variantCategory }).click()
    await sheet.getByRole('button', { name: /^done$/i }).click()

    await taxCard(page).scrollIntoViewIfNeeded()
    await expect(page.getByText(/variants with their own tax category/i)).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(new RegExp(variantCategory, 'i'))).toBeVisible()

    await selectProductTaxCategory(page, productCategory)
    await expect(applyToVariantsNotice).toBeVisible()
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await expect(page.getByText(/variants with their own tax category/i)).toBeVisible()
    await page.getByRole('button', { name: /use product category/i }).click()
    await expect(page.getByText(/variants with their own tax category/i)).toHaveCount(0)

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()
    await expect(variantsCard.getByRole('button', { name: /^edit .*\bred$/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(/variants with their own tax category/i)).toHaveCount(0)
    await expect(applyToVariantsNotice).toHaveCount(0)
  })
})
