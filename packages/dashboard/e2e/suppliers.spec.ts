import { expect, type Page, test } from '@playwright/test'
import { FIXTURE_SUPPLIER, gotoIndex, login, openRowMenu, rowButton, section } from './helpers'

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

  test('adds a supplier and edits their contact on its page', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SUPPLIERS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const name = `E2E Mill ${suffix}`
    await createSupplier(page, { name, email: `orders-${suffix}@mill.test` })

    // Creating opens the new supplier's page.
    await expect(page.getByRole('heading', { name, level: 1 })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#supplier-email')).toHaveValue(`orders-${suffix}@mill.test`)
    await expect(
      section(page, /^purchase orders/i).getByText(/no purchase orders from this supplier yet/i),
    ).toBeVisible()

    // Details and Address are separate cards, each saving its own fields.
    await page.locator('#supplier-contact').fill('Alex Buyer')
    await page
      .locator('[data-slot="card"]')
      .filter({ has: page.locator('#supplier-contact') })
      .getByRole('button', { name: /^save$/i })
      .click()
    await expect(page.getByText(/supplier saved/i)).toBeVisible({ timeout: 15_000 })

    await page.goto(SUPPLIERS_PATH(creds.store_id))
    const row = page.getByRole('row').filter({ has: rowButton(page, name) })
    await expect(row.getByText('Alex Buyer')).toBeVisible({ timeout: 15_000 })
  })

  test("a supplier's page lists its purchase orders and raises a new one", async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SUPPLIERS_PATH(creds.store_id), CTA)

    await rowButton(page, FIXTURE_SUPPLIER).click()
    await expect(page.getByRole('heading', { name: FIXTURE_SUPPLIER, level: 1 })).toBeVisible({
      timeout: 15_000,
    })

    const orders = section(page, /^purchase orders/i)
    await orders.getByRole('link', { name: /new purchase order/i }).click()
    // The supplier arrives already picked.
    await expect(page.locator('#supplier')).toHaveValue(FIXTURE_SUPPLIER, { timeout: 15_000 })
  })

  test('deletes a supplier with no purchasing history', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SUPPLIERS_PATH(creds.store_id), CTA)

    const name = `E2E Former Supplier ${Date.now()}`
    await createSupplier(page, { name })
    await expect(page.getByRole('heading', { name, level: 1 })).toBeVisible({ timeout: 15_000 })
    await page.goto(SUPPLIERS_PATH(creds.store_id))
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
