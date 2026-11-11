import { expect, test } from '@playwright/test'
import { login } from './helpers'
import { PRODUCTS_PATH } from './products-helpers'

test.describe('send feedback', () => {
  test.beforeEach(async ({ context }) => {
    await context.route('https://github.com/**', (route) => route.fulfill({ body: 'ok' }))
  })

  test('reports a bug with the failed requests and system info filled in', async ({
    page,
    context,
  }) => {
    const creds = await login(page)

    // A product that doesn't exist: the dashboard's request for it fails.
    await page.goto(`/${creds.store_id}/products/prod_missing00`)
    await page.waitForResponse((response) => response.url().includes('prod_missing00'))

    await page.getByRole('button', { name: /user menu/i }).click()
    await page.getByRole('menuitem', { name: 'Send feedback' }).click()

    const dialog = page.getByRole('dialog', { name: 'Send feedback' })
    await expect(dialog.getByRole('tab', { name: 'Report a bug' })).toHaveAttribute(
      'aria-selected',
      'true',
    )
    await dialog.getByLabel('What happened?').fill('The product page is blank')
    await expect(dialog.getByText(/prod_missing00 404/).first()).toBeVisible()
    await expect(dialog.getByText('Anonymised system info is included.')).toBeVisible()

    const popup = context.waitForEvent('page')
    await dialog.getByRole('button', { name: 'Open issue on GitHub' }).click()
    const params = new URL((await popup).url()).searchParams

    expect(params.get('template')).toBe('bug_report.yml')
    expect(params.get('description')).toBe('The product page is blank')
    expect(params.get('logs')).toContain('prod_missing00 404')
    expect(params.get('environment')).toContain('**Infrastructure**')
    expect(params.get('environment')).not.toContain(creds.store_name)
  })

  test('suggests an idea as a GitHub discussion', async ({ page, context }) => {
    await login(page)
    await page.getByRole('button', { name: /user menu/i }).click()
    await page.getByRole('menuitem', { name: 'Send feedback' }).click()

    const dialog = page.getByRole('dialog', { name: 'Send feedback' })
    await dialog.getByRole('tab', { name: 'Suggest an idea' }).click()
    await dialog.getByLabel('What would you like Spree to do?').fill('Bulk edit prices')

    const popup = context.waitForEvent('page')
    await dialog.getByRole('button', { name: 'Open discussion on GitHub' }).click()
    const url = new URL((await popup).url())

    expect(url.pathname).toBe('/orgs/spree/discussions/new')
    expect(url.searchParams.get('category')).toBe('ideas')
    expect(url.searchParams.get('title')).toBe('Bulk edit prices')
  })

  test('offers to report a server error', async ({ page }) => {
    const session = await login(page)
    await page.route('**/api/v3/admin/products?**', (route) =>
      route.fulfill({
        status: 500,
        contentType: 'application/json',
        headers: { 'X-Request-Id': 'req-500', 'Access-Control-Expose-Headers': 'X-Request-Id' },
        body: JSON.stringify({ error: { code: 'internal_server_error', message: 'Boom' } }),
      }),
    )
    await page.goto(PRODUCTS_PATH(session.store_id))

    const toast = page.getByRole('alert').filter({ hasText: 'Something went wrong on the server' })
    await expect(toast).toContainText('Request req-500')
    await toast.getByRole('button', { name: 'Report' }).click()

    const dialog = page.getByRole('dialog', { name: 'Send feedback' })
    await expect(dialog.getByRole('tab', { name: 'Report a bug' })).toHaveAttribute(
      'aria-selected',
      'true',
    )
    await expect(
      dialog.getByText(/admin\/products 500 internal_server_error/).first(),
    ).toBeVisible()
  })

  test('reports a bug from the developer tools drawer', async ({ page }) => {
    await login(page)
    await page.keyboard.press('ControlOrMeta+Shift+KeyD')

    await page
      .getByRole('dialog', { name: /developer tools/i })
      .getByRole('button', { name: 'Report an issue' })
      .click()

    await expect(page.getByRole('dialog', { name: 'Send feedback' })).toBeVisible()
  })
})
