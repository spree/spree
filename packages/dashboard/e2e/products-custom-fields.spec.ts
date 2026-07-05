import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import { customFieldsCard, PRODUCTS_PATH } from './products-helpers'

const DEFINITIONS_PATH = (storeId: string) => `/${storeId}/settings/custom-field-definitions`

async function seedProductDefinition(
  page: Page,
  storeId: string,
  attrs: { label: string; key: string },
): Promise<void> {
  await gotoIndex(page, DEFINITIONS_PATH(storeId), /add custom field/i)
  await page.getByRole('button', { name: /add custom field/i }).click()
  await expect(page.getByRole('heading', { name: /add custom field/i })).toBeVisible()
  await page.getByLabel(/^label$/i).fill(attrs.label)
  await page.getByLabel(/^key$/i).fill(attrs.key)
  // Defaults: Applies to "Products", Type "Short text". No need to override.
  await page.getByRole('button', { name: /create custom field/i }).click()
  await expect(page.getByRole('heading', { name: /add custom field/i })).toBeHidden({
    timeout: 15_000,
  })
}

test.describe('product custom fields — new product', () => {
  test('persists an inline custom field value through product creation', async ({ page }) => {
    const creds = await login(page)
    const suffix = Date.now()
    const fieldLabel = `E2E Material ${suffix}`
    const fieldKey = `material_${suffix}`

    await seedProductDefinition(page, creds.store_id, { label: fieldLabel, key: fieldKey })

    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), /add product/i)
    await page.getByRole('button', { name: /add product/i }).click()
    await expect(page.getByRole('heading', { name: /^new product$/i })).toBeVisible()
    await page.getByLabel(/^name$/i).fill(`E2E CF Product ${suffix}`)

    const cfCard = customFieldsCard(page)
    await expect(cfCard.getByText(fieldLabel)).toBeVisible({ timeout: 15_000 })
    await cfCard.getByLabel(new RegExp(`^${fieldLabel}$`, 'i')).fill('Cotton')

    await page.getByRole('button', { name: /^create product$/i }).click()

    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 30_000,
    })

    await expect(customFieldsCard(page).getByLabel(new RegExp(`^${fieldLabel}$`, 'i'))).toHaveValue(
      'Cotton',
    )
  })
})

test.describe('product custom fields — existing product', () => {
  test('persists a value on form save and round-trips through reload', async ({ page }) => {
    const creds = await login(page)
    const suffix = Date.now()
    const fieldLabel = `E2E Fit ${suffix}`
    const fieldKey = `fit_${suffix}`

    await seedProductDefinition(page, creds.store_id, { label: fieldLabel, key: fieldKey })

    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), /add product/i)
    await page.getByRole('button', { name: /add product/i }).click()
    await page.getByLabel(/^name$/i).fill(`E2E CF Edit ${suffix}`)
    await page.getByRole('button', { name: /^create product$/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 30_000,
    })

    const cfCard = customFieldsCard(page)
    const input = cfCard.getByLabel(new RegExp(`^${fieldLabel}$`, 'i'))
    await expect(input).toBeVisible({ timeout: 15_000 })
    await input.fill('Slim')

    // Form mode: custom fields persist with the product's own Save, not on blur.
    const saveButton = page.getByRole('button', { name: /save product/i })
    await saveButton.click()
    // Save re-baselines the form to a clean (non-dirty) state, disabling the
    // button — the user-visible "saved" signal, no fixed sleep required.
    await expect(saveButton).toBeDisabled({ timeout: 30_000 })

    await page.reload()

    await expect(customFieldsCard(page).getByLabel(new RegExp(`^${fieldLabel}$`, 'i'))).toHaveValue(
      'Slim',
    )
  })
})
