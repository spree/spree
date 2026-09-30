import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const POLICIES_PATH = (storeId: string) => `/${storeId}/settings/policies`
const CTA = /add policy/i

async function createPolicy(page: Page, name: string) {
  await page.getByRole('button', { name: CTA }).click()
  await expect(page.getByRole('heading', { name: /^add policy$/i })).toBeVisible()
  await page.locator('#policy-name').fill(name)
  await page.getByRole('button', { name: /create policy/i }).click()
  await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
}

test.describe('policies', () => {
  test('creates a policy whose address follows its name', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, POLICIES_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const name = `E2E Warranty ${suffix}`
    await createPolicy(page, name)

    const row = page.getByRole('row').filter({ has: rowButton(page, name) })
    await expect(row.getByText(`e2e-warranty-${suffix}`)).toBeVisible()
    // Nothing written yet, and the list says so rather than showing a blank.
    await expect(row.getByText(/nothing written yet/i)).toBeVisible()
  })

  test('writes the policy content', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, POLICIES_PATH(creds.store_id), CTA)

    const name = `E2E Shipping Policy ${Date.now()}`
    await createPolicy(page, name)

    await rowButton(page, name).click()
    await expect(page.locator('#policy-name')).toHaveValue(name, { timeout: 15_000 })
    const editor = page.locator('#policy-body')
    await editor.click()
    await editor.pressSequentially('Orders ship within two business days.')
    await page.getByRole('button', { name: /^save$/i }).click()

    const row = page.getByRole('row').filter({ has: rowButton(page, name) })
    await expect(row.getByText(/orders ship within two business days/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  test('deletes a policy after confirming', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, POLICIES_PATH(creds.store_id), CTA)

    const name = `E2E Delete Policy ${Date.now()}`
    await createPolicy(page, name)

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete policy\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
