import { expect, test } from '@playwright/test'
import { login } from './helpers'

const SETTINGS_PATH = (storeId: string) => `/${storeId}/settings`

test.describe('settings index', () => {
  // The index is the way into settings below the desktop breakpoint, where
  // there is no settings rail.
  test('each row opens its settings page', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    const creds = await login(page)
    await page.goto(SETTINGS_PATH(creds.store_id))

    const main = page.getByRole('main')
    await expect(main.getByRole('heading', { name: /^settings$/i })).toBeVisible({
      timeout: 15_000,
    })
    // The row's name carries its description.
    await main.getByRole('link', { name: /^taxes tax categories/i }).click()

    await expect(page).toHaveURL(new RegExp(`${SETTINGS_PATH(creds.store_id)}/taxes/categories`))
    await expect(page.getByRole('button', { name: /add tax category/i })).toBeVisible({
      timeout: 15_000,
    })
  })

  // On a desktop screen the rail lists the same entries, so the index hands
  // over to the first section instead of repeating it.
  test('opens the first section on a desktop screen', async ({ page }) => {
    const creds = await login(page)
    await page.goto(SETTINGS_PATH(creds.store_id))

    await expect(page).toHaveURL(new RegExp(`${SETTINGS_PATH(creds.store_id)}/store$`), {
      timeout: 15_000,
    })
    await expect(page.getByRole('heading', { name: /^store settings$/i, level: 1 })).toBeVisible()
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
    await expect(main.getByRole('link', { name: /^taxes/i })).toHaveCount(0)

    await search.fill('zzz-nothing-matches')
    await expect(main.getByText(/no settings match/i)).toBeVisible()
  })
})
