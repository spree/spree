import { expect, test } from '@playwright/test'
import { FIXTURE_SELLER_WRITER_EMAIL, sellerLogin } from './helpers'

test.describe('seller panel — view as JSON', () => {
  test("shows a listing's record and copies it as curl for the seller", async ({
    page,
    context,
  }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write'])
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    const name = `E2E JSON Lamp ${Date.now()}`
    await page.goto(`${home}/products/new`)
    await page.locator('#product-name').fill(name)
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page).toHaveURL(/\/products\/prod_/, { timeout: 20_000 })
    const productId = page.url().match(/prod_[^/?]+/)?.[0]

    await page.getByRole('button', { name: 'More actions' }).click()
    await page.getByRole('menuitem', { name: 'View as JSON' }).click()

    const drawer = page.getByRole('dialog')
    await expect(drawer.getByText(`"${name}"`).first()).toBeVisible()

    await drawer.getByRole('button', { name: 'Copy as curl' }).click()
    const curl = await page.evaluate(() => navigator.clipboard.readText())
    expect(curl).toContain(`/api/v3/seller/products/${productId}`)
    expect(curl).toContain('Bearer $SPREE_API_TOKEN')
    expect(curl).toContain('X-Spree-Seller-Id')
  })
})
