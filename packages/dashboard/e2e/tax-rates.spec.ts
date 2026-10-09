import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const TAX_RATES_PATH = (storeId: string) => `/${storeId}/settings/tax-rates`
const CTA = /add tax rate/i

async function createTaxRate(
  page: Page,
  attrs: { name: string; amount: string; country?: string },
) {
  await page.getByRole('button', { name: CTA }).click()
  await expect(page.getByRole('heading', { name: /new tax rate/i })).toBeVisible()

  await page.locator('#name').fill(attrs.name)
  await page.locator('#rate_percent').fill(attrs.amount)
  // The seeded store always carries a `Default` tax category.
  await page.locator('#tax_category_id').click()
  await page.getByRole('option', { name: /^default$/i }).click()

  if (attrs.country) {
    await page.getByRole('combobox', { name: /^country$/i }).click()
    await page.getByPlaceholder(/^search countries/i).fill(attrs.country)
    await page.getByRole('option', { name: attrs.country }).first().click()
  }

  await page.getByRole('button', { name: /create tax rate/i }).click()
}

test.describe('tax rates', () => {
  test('asks for a tax category before creating a rate', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TAX_RATES_PATH(creds.store_id), CTA)

    await page.getByRole('button', { name: CTA }).click()
    await page.locator('#name').fill(`E2E Uncategorised ${Date.now()}`)
    await page.getByRole('button', { name: /create tax rate/i }).click()

    await expect(page.locator('#tax_category_id')).toHaveAttribute('aria-invalid', 'true')
  })

  test('creates a rate for one country and shows it as a percentage', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TAX_RATES_PATH(creds.store_id), CTA)

    const name = `E2E VAT ${Date.now()}`
    await createTaxRate(page, { name, amount: '21', country: 'Spain' })

    const row = page.getByRole('row').filter({ has: rowButton(page, name) })
    await expect(row).toBeVisible({ timeout: 15_000 })
    await expect(row.getByText('21%')).toBeVisible()
    await expect(row.getByText(/spain/i)).toBeVisible()
  })

  test('edits a rate', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TAX_RATES_PATH(creds.store_id), CTA)

    const name = `E2E Edit Rate ${Date.now()}`
    await createTaxRate(page, { name, amount: '10' })
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    await expect(page.locator('#rate_percent')).toHaveValue('10', { timeout: 15_000 })
    await page.locator('#rate_percent').fill('12.5')
    await page.getByRole('button', { name: /^save$/i }).click()

    const row = page.getByRole('row').filter({ has: rowButton(page, name) })
    await expect(row.getByText('12.5%')).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a rate after confirming', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TAX_RATES_PATH(creds.store_id), CTA)

    const name = `E2E Delete Rate ${Date.now()}`
    await createTaxRate(page, { name, amount: '5' })
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete tax rate\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
