import { expect, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import { categorizationCard, PRODUCTS_PATH, seedOptionType, variantsCard } from './products-helpers'

const PRODUCT_TYPES_PATH = (storeId: string) => `/${storeId}/settings/product-types`

test.describe('product type option types', () => {
  // The type's option types are copied onto the product on create, before any
  // variant uses them, so the Variants card has to show them from the product.
  test('shows the option types a product got from its type', async ({ page }) => {
    test.setTimeout(120_000)
    const creds = await login(page)
    const stamp = Date.now()
    const typeName = `E2E Option Type ${stamp}`
    const productName = `E2E Typed Product ${stamp}`
    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red'])

    await gotoIndex(page, PRODUCT_TYPES_PATH(creds.store_id), /add product type/i)
    await page.getByRole('button', { name: /add product type/i }).click()
    await expect(page.getByRole('heading', { name: /new product type/i })).toBeVisible()
    await page.locator('#name').fill(typeName)
    await page
      .getByRole('dialog')
      .getByRole('combobox', { name: /search option types/i })
      .fill(colorLabel)
    await page.getByRole('option', { name: colorLabel, exact: true }).first().click()
    await page.getByRole('button', { name: /create product type/i }).click()
    await expect(page.getByText(typeName)).toBeVisible({ timeout: 15_000 })

    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), /add product/i)
    await page.getByRole('button', { name: /add product/i }).click()
    await expect(page.getByRole('heading', { name: /^new product$/i })).toBeVisible()
    await page.getByLabel(/^name$/i).fill(productName)
    await categorizationCard(page).getByRole('combobox').first().click()
    await page.getByRole('option', { name: typeName, exact: true }).click()

    await page.getByRole('button', { name: /^create product$/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 15_000,
    })

    await page.reload()
    await expect(variantsCard(page).getByText(colorLabel).first()).toBeVisible({
      timeout: 15_000,
    })
  })
})
