import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const ALLOWED_ORIGINS_PATH = (storeId: string) => `/${storeId}/settings/allowed-origins`
const CTA = /add allowed origin/i

async function createAllowedOrigin(page: Page, origin: string) {
  await page.getByRole('button', { name: /add allowed origin/i }).click()
  await expect(page.getByRole('heading', { name: /add allowed origin/i })).toBeVisible()

  await page.locator('#origin').fill(origin)

  await page.getByRole('button', { name: /add origin/i }).click()
}

test.describe('allowed origins', () => {
  test('lists allowed origins', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, ALLOWED_ORIGINS_PATH(creds.store_id), CTA)
  })

  test('creates a new allowed origin', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, ALLOWED_ORIGINS_PATH(creds.store_id), CTA)

    const origin = `https://e2e-${Date.now()}.example.com`

    await createAllowedOrigin(page, origin)

    await expect(rowButton(page, origin)).toBeVisible({ timeout: 15_000 })
  })

  test('shows inline validation for a malformed origin', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, ALLOWED_ORIGINS_PATH(creds.store_id), CTA)

    await page.getByRole('button', { name: /add allowed origin/i }).click()
    await expect(page.getByRole('heading', { name: /add allowed origin/i })).toBeVisible()

    await page.locator('#origin').fill('not a url')
    await page.getByRole('button', { name: /add origin/i }).click()

    await expect(page.getByText(/must be a bare origin/i)).toBeVisible()
  })

  test('edits an allowed origin', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, ALLOWED_ORIGINS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const original = `https://edit-${suffix}.example.com`
    const updated = `https://edit-${suffix}.example.net`

    await createAllowedOrigin(page, original)
    await expect(rowButton(page, original)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, original).click()
    await expect(page.getByRole('heading', { name: original })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#origin')).toHaveValue(original)

    await page.locator('#origin').fill(updated)
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(rowButton(page, updated)).toBeVisible({ timeout: 15_000 })
  })

  test('deletes an allowed origin', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, ALLOWED_ORIGINS_PATH(creds.store_id), CTA)

    const origin = `https://del-${Date.now()}.example.com`

    await createAllowedOrigin(page, origin)
    await expect(rowButton(page, origin)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, origin)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /remove allowed origin\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, origin)).toHaveCount(0, { timeout: 15_000 })
  })
})
