import { expect, test } from '@playwright/test'
import { login } from './helpers'

test.describe('view as JSON', () => {
  test('shows the store record and copies it as curl without the token', async ({
    page,
    context,
  }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write'])
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings/store`)

    await page.getByRole('button', { name: 'More actions' }).click()
    await page.getByRole('menuitem', { name: 'View as JSON' }).click()

    const drawer = page.getByRole('dialog')
    await expect(drawer.getByText(`"${creds.store_id}"`).first()).toBeVisible()

    await drawer.getByRole('button', { name: 'Copy as curl' }).click()
    const curl = await page.evaluate(() => navigator.clipboard.readText())
    expect(curl).toContain('/api/v3/admin/store')
    expect(curl).toContain('Bearer $SPREE_API_TOKEN')
    expect(curl).toContain(`X-Spree-Store-Id: ${creds.store_id}`)
  })
})
