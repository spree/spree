import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'

const API_KEYS_PATH = (storeId: string) => `/${storeId}/settings/api-keys`
const CTA = /new key/i

/**
 * Creates a read-only secret key and dismisses the one-shot token dialog.
 * Read-only because the suite never uses these keys to call the API — they
 * only need to exist as rows.
 */
async function createSecretKey(page: Page, name: string) {
  await page.getByRole('button', { name: CTA }).click()
  const sheet = page.getByRole('dialog')
  await expect(sheet.getByText(/create api key/i)).toBeVisible()

  await sheet.locator('#api-key-name').fill(name)
  await expect(sheet.getByText(/full access/i)).toBeVisible()
  await sheet.getByText(/read all \(read_all\)/i).click()

  await sheet.getByRole('button', { name: /create key/i }).click()

  // The plaintext token is shown exactly once, behind its own dialog.
  await expect(page.getByText(/copy.*secret|save.*secret/i).first()).toBeVisible({
    timeout: 15_000,
  })
  await page.getByRole('button', { name: /^done$/i }).click()
}

test.describe('api keys', () => {
  test('lists the publishable and secret sections', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, API_KEYS_PATH(creds.store_id), CTA)

    await expect(page.getByText('Publishable keys', { exact: true })).toBeVisible()
    await expect(page.getByText('Secret keys', { exact: true })).toBeVisible()
  })

  // A secret key is the default choice, so the scope picker has to be there.
  test('creates a secret key and reveals its token once', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, API_KEYS_PATH(creds.store_id), CTA)

    const name = `CI key ${Date.now()}`
    await createSecretKey(page, name)

    await expect(page.getByText(name)).toBeVisible()
  })

  // Renames a key this test created rather than a seeded one, so the fixtures
  // other specs read stay as they were seeded.
  test('renames a key through the edit sheet', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, API_KEYS_PATH(creds.store_id), CTA)

    const original = `Rename me ${Date.now()}`
    await createSecretKey(page, original)

    const row = page.locator('tbody tr').filter({ hasText: original })
    await expect(row).toBeVisible({ timeout: 15_000 })
    await row.getByRole('button').last().click()
    await page.getByRole('menuitem', { name: /^edit$/i }).click()

    const sheet = page.getByRole('dialog')
    await expect(sheet.getByText(/edit api key/i)).toBeVisible()

    const renamed = `${original} renamed`
    await sheet.locator('#edit-api-key-name').fill(renamed)
    await sheet.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByText(renamed)).toBeVisible({ timeout: 15_000 })
  })
})
