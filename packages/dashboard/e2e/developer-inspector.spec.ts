import { expect, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import { PRODUCTS_PATH } from './products-helpers'

test.describe('developer inspector', () => {
  test('lists Admin API requests with their request ID', async ({ page }) => {
    const session = await login(page)
    await gotoIndex(page, PRODUCTS_PATH(session.store_id), /add product/i)
    await page.keyboard.press('ControlOrMeta+Shift+KeyD')

    const drawer = page.getByRole('dialog', { name: /developer tools/i })
    await expect(drawer).toBeVisible()
    await expect(drawer.getByRole('tab', { name: /errors/i })).toBeVisible()

    await drawer
      .getByRole('button', { name: /GET.*\/api\/v3\/admin\/products/ })
      .first()
      .click()

    await expect(drawer.getByTestId('developer-inspector-request-id')).toHaveText(
      /^[0-9a-f-]{20,}$/,
    )
    await expect(drawer.getByRole('button', { name: /copy as curl/i })).toBeVisible()
    await expect(drawer.getByRole('button', { name: /copy request id/i })).toBeVisible()

    // A long response body scrolls inside the drawer instead of growing it.
    const viewport = page.viewportSize()
    const box = await drawer.boundingBox()
    expect(box?.height).toBeLessThan((viewport?.height ?? 0) * 0.8)
  })

  test('opens from the account menu', async ({ page }) => {
    await login(page)

    await page.getByRole('button', { name: /user menu/i }).click()
    await page.getByRole('menuitem', { name: /developer tools/i }).click()

    await expect(page.getByRole('dialog', { name: /developer tools/i })).toBeVisible()
  })
})
