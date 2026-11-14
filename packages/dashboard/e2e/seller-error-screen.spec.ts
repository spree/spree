import { expect, test } from '@playwright/test'
import { sellerLogin } from './helpers'

test.describe('seller panel — error screen', () => {
  test('a page that fails to render shows the error screen inside the panel', async ({ page }) => {
    // A product count that is an object instead of a number makes the home
    // page throw while rendering.
    await page.route('**/api/v3/seller/profile', async (route) => {
      if (route.request().method() !== 'GET') return route.fallback()
      const response = await route.fetch()
      const profile = await response.json()
      await route.fulfill({ response, json: { ...profile, products_count: { broken: true } } })
    })

    await sellerLogin(page)

    await expect(page.getByText('Something went wrong')).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('button', { name: 'Try again' })).toBeVisible()
    // Only the page failed: the panel's navigation still works.
    await page.unrouteAll({ behavior: 'ignoreErrors' })
    await page
      .getByRole('link', { name: /^products$/i })
      .first()
      .click()
    await expect(page).toHaveURL(/\/products/)
    await expect(page.getByText('Something went wrong')).toHaveCount(0)
  })
})
