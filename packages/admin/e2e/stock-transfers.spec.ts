import { expect, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'

const TRANSFERS_PATH = (storeId: string) => `/${storeId}/products/transfers`
const CTA = /new transfer/i

test.describe('stock transfers', () => {
  test('lists stock transfers', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TRANSFERS_PATH(creds.store_id), CTA)
  })

  // The "new transfer" Sheet requires picking a stocked variant. We only
  // assert the sheet opens; a full create needs a product + variant with
  // stock items, which the dummy app's seed pipeline doesn't provision.
  test('opens the new transfer sheet', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TRANSFERS_PATH(creds.store_id), CTA)

    await page.getByRole('button', { name: /new transfer/i }).click()
    await expect(page.getByRole('heading', { name: /new stock transfer/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.locator('#destination')).toBeVisible()
  })
})
