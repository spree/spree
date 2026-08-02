import { expect, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'

const PATH = (storeId: string) => `/${storeId}/settings/product-types`
const CTA = /add product type/i

test.describe('product types', () => {
  test('lists product types', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)
  })

  test('creates a pickup-capable product type', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)

    const name = `E2E Collectable ${Date.now()}`

    await page.getByRole('button', { name: CTA }).click()
    await expect(page.getByRole('heading', { name: /new product type/i })).toBeVisible()

    await page.locator('#name').fill(name)
    // Shipping is preselected; add pickup on top. Base UI renders the real
    // control as a button (the id lands on a visually-hidden input), so
    // drive it through its label like a user would.
    await page.getByRole('checkbox', { name: /^pickup$/i }).click()

    await page.getByRole('button', { name: /create product type/i }).click()

    await expect(page.getByText(name)).toBeVisible({ timeout: 15_000 })
  })

  test('rejects a product type with no fulfillment types', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)

    await page.getByRole('button', { name: CTA }).click()
    await page.locator('#name').fill(`E2E Invalid ${Date.now()}`)
    await page.getByRole('checkbox', { name: /^shipping$/i }).click() // uncheck the default

    await page.getByRole('button', { name: /create product type/i }).click()

    // Client-side validation keeps the sheet open with an error.
    await expect(page.getByRole('heading', { name: /new product type/i })).toBeVisible()
  })
})
