import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import {
  addProductCategory,
  categorizationCard,
  PRODUCTS_PATH,
  removeProductCategory,
} from './products-helpers'

const CATEGORIES_PATH = (storeId: string) => `/${storeId}/products/categories`
const PRODUCT_TYPES_PATH = (storeId: string) => `/${storeId}/settings/product-types`

async function createTopLevelCategory(page: Page, name: string) {
  await page.getByRole('button', { name: /new category/i }).click()
  await expect(page.getByRole('heading', { name: /new category/i })).toBeVisible({
    timeout: 15_000,
  })
  await page.locator('#category-name').fill(name)
  await page.getByRole('button', { name: /^save$/i }).click()
  await expect(page).toHaveURL(/\/products\/categories\/(?!new(?:\?|$))/, { timeout: 15_000 })
  await page.getByRole('button', { name: /^back$/i }).click()
  await expect(page).toHaveURL(/\/products\/categories(?:\?|$)/, { timeout: 15_000 })
}

async function pickCategoryInSheet(page: Page, categoryName: string) {
  await page
    .getByRole('dialog')
    .getByRole('combobox', { name: /search categories/i })
    .fill(categoryName)
  await page
    .getByRole('option', { name: new RegExp(`^${categoryName}$`, 'i') })
    .first()
    .click()
}

test.describe('product type default categories', () => {
  test('does not re-add a removed type category after reload', async ({ page }) => {
    test.setTimeout(120_000)
    const creds = await login(page)
    const stamp = Date.now()
    const parentCategory = `E2E Type Parent ${stamp}`
    const otherCategory = `E2E Type Other ${stamp}`
    const typeName = `E2E Type ${stamp}`
    const productName = `E2E Type Category Product ${stamp}`

    await gotoIndex(page, CATEGORIES_PATH(creds.store_id), /new category/i)
    await createTopLevelCategory(page, parentCategory)
    await createTopLevelCategory(page, otherCategory)

    await gotoIndex(page, PRODUCT_TYPES_PATH(creds.store_id), /add product type/i)
    await page.getByRole('button', { name: /add product type/i }).click()
    await expect(page.getByRole('heading', { name: /new product type/i })).toBeVisible()
    await page.locator('#name').fill(typeName)
    await pickCategoryInSheet(page, parentCategory)
    await page.getByRole('button', { name: /create product type/i }).click()
    await expect(page.getByText(typeName)).toBeVisible({ timeout: 15_000 })

    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), /add product/i)
    await page.getByRole('button', { name: /add product/i }).click()
    await expect(page.getByRole('heading', { name: /^new product$/i })).toBeVisible()
    await page.getByLabel(/^name$/i).fill(productName)

    const categorization = categorizationCard(page)
    await categorization.getByRole('combobox').first().click()
    await page.getByRole('option', { name: typeName, exact: true }).click()
    await addProductCategory(page, otherCategory)

    await page.getByRole('button', { name: /^create product$/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 15_000,
    })

    await expect(
      categorization.locator('[data-slot="combobox-chip"]', { hasText: parentCategory }),
    ).toBeVisible()
    await expect(
      categorization.locator('[data-slot="combobox-chip"]', { hasText: otherCategory }),
    ).toBeVisible()

    await removeProductCategory(page, parentCategory)
    await expect(
      categorization.locator('[data-slot="combobox-chip"]', { hasText: parentCategory }),
    ).toHaveCount(0)

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 15_000,
    })

    await page.reload()

    await expect(
      categorization.locator('[data-slot="combobox-chip"]', { hasText: parentCategory }),
    ).toHaveCount(0)
    await expect(
      categorization.locator('[data-slot="combobox-chip"]', { hasText: otherCategory }),
    ).toHaveCount(1)
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled()
  })
})
