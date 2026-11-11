import { expect, test } from '@playwright/test'
import { login } from './helpers'

test.describe('system info', () => {
  test('shows an anonymised report and copies it', async ({ page, context }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write'])
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings/system-info`)

    await expect(page.getByRole('heading', { name: 'System info' })).toBeVisible()
    // The dashboard's own packages sit next to Spree's gems; the browser and
    // recent errors only go into the copied report.
    await expect(page.locator('[data-slot="card-title"]')).toHaveText([
      'Spree',
      'Dashboard',
      'Runtime',
      'Infrastructure',
    ])
    await expect(page.getByText('@spree/dashboard-core', { exact: true })).toBeVisible()
    // Reached through the dashboard packages, not listed by the app itself.
    await expect(page.getByText('@spree/core', { exact: true })).toBeVisible()

    const copy = page.getByRole('button', { name: 'Copy as Markdown' })
    // Wide enough for its label, not an icon-sized button.
    expect((await copy.boundingBox())?.width).toBeGreaterThan(100)
    await copy.click()
    await expect(page.getByText('Copied')).toBeVisible()
    const copied = await page.evaluate(() => navigator.clipboard.readText())
    expect(copied).not.toContain(creds.store_name)
    expect(copied).toContain('| User agent |')
    expect(copied).toContain('| @spree/dashboard-core |')
    expect(copied).toContain('**Recent errors**')
  })

  test('reports an issue from the page', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings/system-info`)

    await page.getByRole('button', { name: 'Report an issue on GitHub' }).click()

    await expect(page.getByRole('dialog', { name: 'Send feedback' })).toBeVisible()
  })

  test('is reachable from settings', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings`)

    await page
      .getByRole('link', { name: /system info/i })
      .first()
      .click()

    await expect(page.getByRole('heading', { name: 'System info' })).toBeVisible()
  })
})
