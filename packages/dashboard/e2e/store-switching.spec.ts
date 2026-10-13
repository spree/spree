import { expect, test } from '@playwright/test'
import { FIXTURE_COMMA_STORE_NAME, FIXTURE_TWO_STORE_STAFF_EMAIL, getCredentials } from './helpers'

test('the sidebar follows the permissions of the store that is open', async ({ page }) => {
  const creds = getCredentials()
  const res = await page.request.post('/api/v3/admin/auth/login', {
    data: { email: FIXTURE_TWO_STORE_STAFF_EMAIL, password: creds.admin_password },
  })
  expect(res.ok()).toBe(true)

  const sidebar = page.locator('[data-slot="sidebar"]').first()
  const productsLink = sidebar.getByRole('link', { name: /^products$/i })
  const ordersLink = sidebar.getByRole('link', { name: /^orders$/i })

  await page.goto(`/${creds.store_id}`)
  await expect(productsLink).toBeVisible({ timeout: 15_000 })

  await page.getByRole('button', { name: /switch store/i }).click()
  await page.getByRole('menuitem', { name: FIXTURE_COMMA_STORE_NAME }).click()

  await expect(page).toHaveURL(new RegExp(`/${creds.comma_store_id}`))
  await expect(ordersLink).toBeVisible({ timeout: 15_000 })
  await expect(productsLink).toBeHidden()

  await page.getByRole('button', { name: /switch store/i }).click()
  await page.getByRole('menuitem', { name: creds.store_name }).click()

  await expect(page).toHaveURL(new RegExp(`/${creds.store_id}`))
  await expect(productsLink).toBeVisible({ timeout: 15_000 })
})
