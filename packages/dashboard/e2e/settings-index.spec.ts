import { expect, test } from '@playwright/test'
import { login } from './helpers'

const SETTINGS_PATH = (storeId: string) => `/${storeId}/settings`

test.describe('settings index', () => {
  test('each card opens its settings page', async ({ page }) => {
    const creds = await login(page)
    await page.goto(SETTINGS_PATH(creds.store_id))

    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { name: /^settings$/i })).toBeVisible({
      timeout: 15_000,
    })
    // The card, not the sidebar entry: the card's name carries its description.
    await main.getByRole('link', { name: /^tax rates rates applied/i }).click()

    await expect(page).toHaveURL(new RegExp(`${SETTINGS_PATH(creds.store_id)}/tax-rates`))
    await expect(page.getByRole('button', { name: /add tax rate/i })).toBeVisible({
      timeout: 15_000,
    })
  })

  // Below the desktop breakpoint the settings sidebar is gone, so the page's
  // own search is the only way to narrow the list.
  test('searches settings on a narrow screen', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    const creds = await login(page)
    await page.goto(SETTINGS_PATH(creds.store_id))

    const main = page.getByRole('main')
    const search = main.getByRole('searchbox', { name: /search settings/i })
    await expect(search).toBeVisible({ timeout: 15_000 })

    await search.fill('webhook')
    await expect(main.getByRole('link', { name: /^webhooks/i })).toBeVisible()
    await expect(main.getByRole('link', { name: /^tax rates/i })).toHaveCount(0)

    await search.fill('zzz-nothing-matches')
    await expect(main.getByText(/no settings match/i)).toBeVisible()
  })
})
