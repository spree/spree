import { expect, test } from '@playwright/test'
import { login } from './helpers'

const MARKETPLACE_PATH = (storeId: string) => `/${storeId}/settings/marketplace`

test.describe('marketplace settings', () => {
  test('saves the payout minimum and commission tax, and they survive a reload', async ({
    page,
  }) => {
    const creds = await login(page)
    await page.goto(MARKETPLACE_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^marketplace$/i })).toBeVisible({
      timeout: 15_000,
    })

    const minimum = page.locator('#payout-minimum')
    const taxRate = page.locator('#marketplace-commission-tax-rate')
    const originalMinimum = await minimum.inputValue()
    const originalTaxRate = await taxRate.inputValue()

    await minimum.fill('25')
    await taxRate.fill('8')
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/store settings updated/i).first()).toBeVisible({
      timeout: 15_000,
    })

    await page.reload()
    await expect(minimum).toHaveValue(/^25(\.0+)?$/, { timeout: 15_000 })
    await expect(taxRate).toHaveValue(/^8(\.0+)?$/)

    // Put the store back so the sellers and payout specs read the defaults.
    await minimum.fill(originalMinimum)
    await taxRate.fill(originalTaxRate)
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByRole('button', { name: /^save$/i })).toBeDisabled({ timeout: 15_000 })
  })

  test('the old payouts settings address opens this page', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings/payouts`)

    await expect(page).toHaveURL(new RegExp(`${MARKETPLACE_PATH(creds.store_id)}$`), {
      timeout: 15_000,
    })
    await expect(page.getByRole('heading', { name: /^marketplace$/i })).toBeVisible()
  })
})
