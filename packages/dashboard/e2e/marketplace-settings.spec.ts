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

  test('opens digital files to sellers with an accepted type list, and it survives a reload', async ({
    page,
  }) => {
    const creds = await login(page)
    await page.goto(MARKETPLACE_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^marketplace$/i })).toBeVisible({
      timeout: 15_000,
    })

    const enabled = page.getByRole('switch', { name: /let sellers upload digital files/i })
    const types = page.getByLabel(/accepted file types for sellers/i)
    const review = page.getByRole('switch', { name: /review file changes on products/i })
    const chips = page.locator('[data-slot="combobox-chips"] [data-slot="combobox-chip"]')
    const wasEnabled = (await enabled.getAttribute('aria-checked')) === 'true'

    // The type list and the review rule only appear once sellers may upload.
    if (!wasEnabled) {
      await expect(types).toBeHidden()
      await expect(review).toBeHidden()
      await enabled.click()
    }
    await expect(types).toBeVisible()
    const originalTypes = await chips.allInnerTexts()

    const clearTypes = async () => {
      while ((await chips.count()) > 0) {
        await chips
          .first()
          .getByRole('button', { name: /^remove/i })
          .click()
      }
    }
    const addTypes = async (values: string[]) => {
      for (const value of values) {
        await types.fill(value)
        await types.press('Enter')
        await expect(chips.filter({ hasText: value })).toBeVisible()
      }
    }

    await clearTypes()
    // One from the dropdown, by its format name, and one typed in.
    await types.fill('FLAC')
    await page.getByRole('option', { name: /FLAC/ }).click()
    await addTypes(['application/x-custom'])
    await review.click()
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/store settings updated/i).first()).toBeVisible({
      timeout: 15_000,
    })

    await page.reload()
    await expect(enabled).toHaveAttribute('aria-checked', 'true', { timeout: 15_000 })
    await expect(chips).toHaveText(['audio/flac', 'application/x-custom'])
    await expect(review).toHaveAttribute('aria-checked', 'false')

    // Put the store back so the seller panel specs read the defaults.
    await clearTypes()
    await addTypes(originalTypes)
    await review.click()
    if (!wasEnabled) await enabled.click()
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
