import { expect, test } from '@playwright/test'
import { login } from './helpers'

test.describe('Enterprise previews', () => {
  test('opens the quotes preview from the Orders section', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/orders`)

    await page.getByRole('link', { name: /^quotes/i }).click()

    await expect(page.getByRole('heading', { name: /^quotes$/i })).toBeVisible({ timeout: 15_000 })
    // Not an order numbered "quotes": the preview takes the address from the order page.
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/quotes$`))
    await expect(page.getByText(/^how it works$/i)).toBeVisible()
    await expect(page.getByRole('link', { name: /^enterprise$/i })).toHaveAttribute(
      'href',
      /^https:\/\/spreecommerce\.org\/enterprise\//,
    )
    await expect(page.getByRole('link', { name: /get spree enterprise/i }).first()).toHaveAttribute(
      'href',
      /utm_campaign=quotes/,
    )
  })

  test('lists Companies as its own section, with company onboarding under it', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/companies`)

    await page.getByRole('link', { name: /^onboarding/i }).click()

    await expect(page.getByRole('heading', { name: /^company onboarding$/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/companies/onboarding$`))
  })

  test('opens the audit log preview from Users & permissions settings', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings/staff`)

    await page.getByRole('link', { name: /^audit log/i }).click()

    await expect(page.getByRole('heading', { name: /^audit log$/i })).toBeVisible({
      timeout: 15_000,
    })
  })
})
