import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'

const API_KEYS_PATH = (storeId: string) => `/${storeId}/settings/api-keys`
const CTA = /new key/i
const ME_URL = /\/api\/v3\/admin\/me(\?|$)/

/**
 * Answers `/me` the way an installation with maintenance tasks turned off
 * does: the admin's permission keys come back without them. Faked on the
 * response because the switch is a server setting every spec shares.
 */
async function withholdMaintenanceTaskKeys(page: Page) {
  await page.route(ME_URL, async (route) => {
    if (route.request().method() !== 'GET') return route.fallback()
    const response = await route.fetch()
    const me = await response.json()
    me.permission_keys = me.permission_keys.filter(
      (key: string) => !key.endsWith('_maintenance_tasks'),
    )
    await route.fulfill({ response, json: me })
  })
}

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

  // The admin role may grant every scope even when the installation withholds
  // some keys from everyone, so the two catch-all choices must stay pickable.
  test('lets an admin pick read all and full access when some keys are withheld', async ({
    page,
  }) => {
    await withholdMaintenanceTaskKeys(page)
    const creds = await login(page)
    await gotoIndex(page, API_KEYS_PATH(creds.store_id), CTA)

    await page.getByRole('button', { name: CTA }).click()
    const sheet = page.getByRole('dialog')
    const name = `Full access key ${Date.now()}`
    await sheet.locator('#api-key-name').fill(name)

    // The withheld key itself is not on offer.
    await expect(sheet.getByRole('checkbox', { name: 'Manage Maintenance tasks' })).toBeDisabled()

    const readAll = sheet.getByRole('checkbox', { name: /^read all \(read_all\)/i })
    const fullAccess = sheet.getByRole('checkbox', { name: /^full access \(write_all\)/i })
    await expect(readAll).toBeEnabled()
    await expect(fullAccess).toBeEnabled()

    await readAll.click()
    await expect(readAll).toBeChecked()
    await readAll.click()
    await expect(readAll).not.toBeChecked()

    await fullAccess.click()
    await expect(fullAccess).toBeChecked()

    await sheet.getByRole('button', { name: /create key/i }).click()
    await expect(page.getByText(/copy.*secret|save.*secret/i).first()).toBeVisible({
      timeout: 15_000,
    })
    await page.getByRole('button', { name: /^done$/i }).click()

    const row = page.locator('tbody tr').filter({ hasText: name })
    await expect(row.getByText('Full access', { exact: true })).toBeVisible({ timeout: 15_000 })
  })

  // Admins reviewing a key they don't recognize need to see where it came from.
  test('shows the IP address a key was created from', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, API_KEYS_PATH(creds.store_id), CTA)

    const name = `IP key ${Date.now()}`
    await createSecretKey(page, name)

    // Only the first part shows until asked for, then all of it, then masked again.
    const row = page.locator('tbody tr').filter({ hasText: name })
    const masked = /^from IP [0-9a-f]*[.:]\*{8}$/i
    await expect(row.getByText(masked)).toBeVisible({ timeout: 15_000 })

    await row.getByRole('button', { name: /^show$/i }).click()
    await expect(row.getByText(/^from IP [^*\s]+$/)).toBeVisible()

    await row.getByRole('button', { name: /^hide$/i }).click()
    await expect(row.getByText(masked)).toBeVisible()
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
