import { expect, type Page, test } from '@playwright/test'
import { login } from './helpers'

const TAXES_PATH = (storeId: string) => `/${storeId}/settings/taxes`

function exemptionReasons(page: Page) {
  return page.locator('[data-slot="card"]').filter({
    has: page.locator('[data-slot="card-title"]', { hasText: /^tax exemption reasons$/i }),
  })
}

test.describe('taxes', () => {
  test('opens on categories and switches between the tabs', async ({ page }) => {
    const creds = await login(page)
    await page.goto(TAXES_PATH(creds.store_id))

    await expect(page).toHaveURL(new RegExp(`${TAXES_PATH(creds.store_id)}/categories`))
    await expect(page.getByRole('heading', { name: /^taxes$/i })).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('tab', { name: /^categories$/i })).toHaveAttribute(
      'aria-selected',
      'true',
    )
    await expect(page.getByText(/^tax calculation$/i)).toBeVisible()
    await expect(page.getByRole('link', { name: /manage markets/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /add tax category/i })).toBeVisible()

    await page.getByRole('tab', { name: /^rates$/i }).click()
    await expect(page).toHaveURL(new RegExp(`${TAXES_PATH(creds.store_id)}/rates`))
    await expect(page.getByRole('tab', { name: /^rates$/i })).toHaveAttribute(
      'aria-selected',
      'true',
    )
    await expect(page.getByRole('button', { name: /add tax rate/i })).toBeVisible({
      timeout: 15_000,
    })

    await page.getByRole('tab', { name: /^exemption reasons$/i }).click()
    await expect(page).toHaveURL(new RegExp(`${TAXES_PATH(creds.store_id)}/exemption-reasons`))
    await expect(
      exemptionReasons(page).getByRole('cell', { name: 'RESALE', exact: true }),
    ).toBeVisible({ timeout: 15_000 })
  })

  // The tax engine reads the code, not the name, so the list shows both.
  test('adds a tax exemption reason with its code', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`${TAXES_PATH(creds.store_id)}/exemption-reasons`)

    const name = `E2E Diplomatic ${Date.now()}`
    const code = `diplomatic_${Date.now()}`
    await exemptionReasons(page)
      .getByRole('button', { name: /add reason/i })
      .click()
    await page.locator('#reason-name').fill(name)
    await page.locator('#reason-code').fill(code)
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^create$/i })
      .click()

    const row = exemptionReasons(page).getByRole('row').filter({ hasText: name })
    // Codes are stored upper case, the way tax engines compare them.
    await expect(row.getByText(code.toUpperCase())).toBeVisible({ timeout: 15_000 })
  })
})
