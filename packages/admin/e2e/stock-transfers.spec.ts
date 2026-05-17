import { expect, type Page, test } from '@playwright/test'
import { login } from './helpers'

async function goto(page: Page, storeId: string) {
  await page.goto(`/${storeId}/products/transfers`)
  await expect(page.getByRole('button', { name: /new transfer/i })).toBeVisible({
    timeout: 15_000,
  })
}

test.describe('stock transfers', () => {
  test('lists stock transfers', async ({ page }) => {
    const creds = await login(page)
    await goto(page, creds.store_id)
  })

  // The "new transfer" Sheet requires picking a stocked variant, which the
  // dummy app's seed pipeline doesn't provision. Opening the sheet and
  // verifying its surface is enough to lock the page-load + trigger flow;
  // a full create would need to seed a product + variant via the API first.
  test('opens the new transfer sheet', async ({ page }) => {
    const creds = await login(page)
    await goto(page, creds.store_id)

    await page.getByRole('button', { name: /new transfer/i }).click()
    await expect(page.getByRole('heading', { name: /new stock transfer/i })).toBeVisible({
      timeout: 15_000,
    })
    // Destination select is required and present in the empty form.
    await expect(page.locator('#destination')).toBeVisible()
  })
})
