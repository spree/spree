import { expect, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton, waitForToastsToClear } from './helpers'

const REQUIREMENTS_PATH = (storeId: string) => `/${storeId}/settings/seller-requirements`
const CTA = /add requirement/i

test.describe('seller requirements', () => {
  test('lists the starting checklist every marketplace gets', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, REQUIREMENTS_PATH(creds.store_id), CTA)

    await expect(rowButton(page, 'Accept terms')).toBeVisible()
  })

  // One flow rather than three: a required requirement left behind would
  // stand between every later seller spec and approval, so the record this
  // creates is deleted before the test ends.
  test('adds a seller confirmation, switches it off, and deletes it', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, REQUIREMENTS_PATH(creds.store_id), CTA)

    const name = `E2E Licence ${Date.now()}`

    await page.getByRole('button', { name: CTA }).click()
    await expect(page.getByRole('heading', { name: /add a requirement/i })).toBeVisible()
    await page.getByLabel(/^type$/i).click()
    await page.getByRole('option', { name: /seller confirmation/i }).click()
    await page.getByLabel(/^name/i).fill(name)
    await page.getByLabel(/^instructions$/i).fill('Confirm you hold a trading licence.')
    await page.getByRole('switch', { name: /^required$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()

    const row = page.getByRole('row').filter({ has: rowButton(page, name) })
    await expect(row).toBeVisible({ timeout: 15_000 })
    await expect(row.getByText(/seller confirmation/i)).toBeVisible()
    await expect(row.getByText(/^recommended$/i)).toBeVisible()

    await rowButton(page, name).click()
    await page.getByRole('switch', { name: /^active$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()
    await expect(row.getByText(/^off$/i)).toBeVisible({ timeout: 15_000 })

    await waitForToastsToClear(page)
    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete requirement\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()
    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
