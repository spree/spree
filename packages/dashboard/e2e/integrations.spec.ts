import { expect, test } from '@playwright/test'
import { login } from './helpers'

test.describe('integrations', () => {
  // Integrations come from provider gems, and the test app installs none —
  // so the page has to explain where they come from rather than sit blank.
  test('explains where integrations come from when none are installed', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings/integrations`)

    await expect(page.getByRole('heading', { name: /^integrations$/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(/no integrations installed/i)).toBeVisible()
    await expect(page.getByText(/install a provider gem/i)).toBeVisible()
  })
})
