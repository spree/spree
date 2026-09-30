import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton, waitForToastsToClear } from './helpers'

const COMMISSION_RATES_PATH = (storeId: string) => `/${storeId}/sellers/commission-rates`
const CTA = /add commission rate/i

async function createCommissionRate(page: Page, name: string, value: string) {
  await page.getByRole('button', { name: CTA }).click()
  await page.locator('#name').fill(name)
  await page.locator('#value').fill(value)
  await page.getByRole('button', { name: /create commission rate/i }).click()
  await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
}

test.describe('commission rates', () => {
  test('creates a percentage rate and edits it', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COMMISSION_RATES_PATH(creds.store_id), CTA)

    const name = `E2E Commission ${Date.now()}`
    await createCommissionRate(page, name, '12')

    const row = page.getByRole('row').filter({ has: rowButton(page, name) })
    await expect(row.getByText(/^12(\.0+)?%$/)).toBeVisible()
    // A rate with no conditions matches every sale, and the row says so.
    await expect(row.getByText(/^every sale$/i)).toBeVisible()

    await rowButton(page, name).click()
    await expect(page.locator('#value')).toHaveValue(/^12(\.0+)?$/, { timeout: 15_000 })
    await page.locator('#value').fill('15')
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(row.getByText(/^15(\.0+)?%$/)).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a rate after confirming', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COMMISSION_RATES_PATH(creds.store_id), CTA)

    const name = `E2E Old Commission ${Date.now()}`
    await createCommissionRate(page, name, '5')

    await waitForToastsToClear(page)
    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete commission rate\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })

  test('the old settings address opens the commission rates', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings/commission-rates`)

    await expect(page).toHaveURL(new RegExp(`${COMMISSION_RATES_PATH(creds.store_id)}(\\?|$)`), {
      timeout: 15_000,
    })
    await expect(page.getByRole('button', { name: CTA })).toBeVisible()
  })
})
