import { expect, test } from '@playwright/test'
import { login } from './helpers'

const GETTING_STARTED_PATH = (storeId: string) => `/${storeId}/getting-started`

test.describe('getting started', () => {
  test('shows setup progress and links each step to where it is done', async ({ page }) => {
    const creds = await login(page)
    await page.goto(GETTING_STARTED_PATH(creds.store_id))

    await expect(page.getByRole('heading', { name: /^getting started$/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(/\d+ of \d+ completed/i)).toBeVisible()

    // The checklist opens on the first unfinished step, and other specs may
    // have finished this one already — so open it only if it is still shut.
    const step = page.getByRole('button', { name: /set up taxes collection/i })
    if ((await step.getAttribute('aria-expanded')) !== 'true') await step.click()
    await page.getByRole('link', { name: /^tax settings$/i }).click()

    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/settings/tax-rates`))
    await expect(page.getByRole('button', { name: /add tax rate/i })).toBeVisible({
      timeout: 15_000,
    })
  })
})
