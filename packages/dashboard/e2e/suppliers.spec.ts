import { expect, type Page, test } from '@playwright/test'
import { FIXTURE_SUPPLIER, gotoIndex, login, openRowMenu, rowButton } from './helpers'

const SUPPLIERS_PATH = (storeId: string) => `/${storeId}/suppliers`
const CTA = /new supplier/i

async function createSupplier(page: Page, attrs: { name: string; email?: string }) {
  await page.getByRole('button', { name: CTA }).click()
  await expect(page.getByRole('heading', { name: /^new supplier$/i })).toBeVisible()
  await page.locator('#supplier-name').fill(attrs.name)
  if (attrs.email) await page.locator('#supplier-email').fill(attrs.email)
  await page
    .getByRole('dialog')
    .getByRole('button', { name: /^save$/i })
    .click()
}

test.describe('suppliers', () => {
  test('lists suppliers', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SUPPLIERS_PATH(creds.store_id), CTA)

    await expect(rowButton(page, FIXTURE_SUPPLIER)).toBeVisible()
  })

  test('a supplier needs a name', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SUPPLIERS_PATH(creds.store_id), CTA)

    await createSupplier(page, { name: '' })

    await expect(page.getByText(/a supplier needs a name/i)).toBeVisible()
  })

  test('adds a supplier and edits their contact', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SUPPLIERS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const name = `E2E Mill ${suffix}`
    await createSupplier(page, { name, email: `orders-${suffix}@mill.test` })

    const row = page.getByRole('row').filter({ has: rowButton(page, name) })
    await expect(row.getByText(`orders-${suffix}@mill.test`)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    await expect(page.locator('#supplier-name')).toHaveValue(name, { timeout: 15_000 })
    await page.locator('#supplier-contact').fill('Alex Buyer')
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()

    await expect(row.getByText('Alex Buyer')).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a supplier with no purchasing history', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SUPPLIERS_PATH(creds.store_id), CTA)

    const name = `E2E Former Supplier ${Date.now()}`
    await createSupplier(page, { name })
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete this supplier\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
