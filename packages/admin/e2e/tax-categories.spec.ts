import { expect, type Page, test } from '@playwright/test'
import { login, rowButton } from './helpers'

async function goto(page: Page, storeId: string) {
  await page.goto(`/${storeId}/settings/tax-categories`)
  await expect(page.getByRole('button', { name: /add tax category/i })).toBeVisible({
    timeout: 15_000,
  })
}

async function createTaxCategory(
  page: Page,
  attrs: { name: string; taxCode?: string; description?: string },
) {
  await page.getByRole('button', { name: /add tax category/i }).click()
  await expect(page.getByRole('heading', { name: /add tax category/i })).toBeVisible()

  await page.locator('#name').fill(attrs.name)
  if (attrs.taxCode) await page.locator('#tax_code').fill(attrs.taxCode)
  if (attrs.description) await page.locator('#description').fill(attrs.description)

  await page.getByRole('button', { name: /create tax category/i }).click()
}

test.describe('tax categories', () => {
  test('lists tax categories', async ({ page }) => {
    const creds = await login(page)
    await goto(page, creds.store_id)
  })

  test('creates a new tax category', async ({ page }) => {
    const creds = await login(page)
    await goto(page, creds.store_id)

    const suffix = Date.now()
    const name = `E2E Tax ${suffix}`

    await createTaxCategory(page, { name, taxCode: `TX${suffix}`, description: 'For E2E test.' })

    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
  })

  test('edits a tax category', async ({ page }) => {
    const creds = await login(page)
    await goto(page, creds.store_id)

    const suffix = Date.now()
    const original = `E2E Edit Tax ${suffix}`
    const updated = `${original} (updated)`

    await createTaxCategory(page, { name: original })
    await expect(rowButton(page, original)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, original).click()
    await expect(page.getByRole('heading', { name: original })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#name')).toHaveValue(original)

    await page.locator('#name').fill(updated)
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(rowButton(page, updated)).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a tax category', async ({ page }) => {
    const creds = await login(page)
    await goto(page, creds.store_id)

    const suffix = Date.now()
    const name = `E2E Delete Tax ${suffix}`

    await createTaxCategory(page, { name })
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete tax category\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
