import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import { expect, test } from '@playwright/test'
import { login, openRowMenu } from './helpers'
import { createProduct } from './products-helpers'

// Any file works — the card serves whatever is attached, it doesn't restrict
// the type. Reuse the shared fixture so no new binary ships with the suite.
const FIXTURE_FILE = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'fixtures/test-image.png',
)

test.describe('product digital files', () => {
  test('uploads a file, edits its download limits, then removes it', async ({ page }) => {
    const creds = await login(page)
    await createProduct(page, creds.store_id, `E2E Digital ${Date.now()}`)

    // Scope to the Digital files card — the Media card on the same page also
    // has a hidden file input, so target this card's own input by its title.
    const digitalCard = page
      .locator('[data-slot="card"]')
      .filter({ has: page.locator('[data-slot="card-title"]', { hasText: /^Digital files$/ }) })
    await expect(digitalCard).toHaveCount(1)

    // The empty card is a dropzone with a hidden file input behind it — set the
    // file directly rather than simulating the click-through.
    const fileName = path.basename(FIXTURE_FILE)
    await digitalCard.locator('input[type="file"]').setInputFiles(FIXTURE_FILE)

    // The uploaded file appears as a row in this card once the asset is created.
    const fileRow = digitalCard.locator('tr').filter({ hasText: fileName })
    await expect(fileRow).toBeVisible({ timeout: 30_000 })

    // Edit its per-file limits through the row menu sheet.
    await openRowMenu(page, fileName)
    await page.getByRole('menuitem', { name: /^edit$/i }).click()

    const sheet = page.getByRole('dialog')
    await expect(sheet).toBeVisible()
    await sheet.getByLabel(/downloads allowed/i).fill('5')
    await sheet.getByLabel(/days available/i).fill('7')
    await sheet.getByRole('button', { name: /^save$/i }).click()
    await expect(sheet).toBeHidden()

    // The chosen limits show in the row rather than the store default — proof
    // the update persisted and the list refetched.
    await expect(fileRow.getByRole('cell', { name: '5', exact: true })).toBeVisible({
      timeout: 15_000,
    })
    await expect(fileRow.getByRole('cell', { name: '7', exact: true })).toBeVisible()

    // Remove it — the row-menu delete goes through a destructive confirm whose
    // action button is the default "Confirm" (the card passes no confirmLabel).
    await openRowMenu(page, fileName)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete this file\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^confirm$/i })
      .click()

    // The row is gone and the card falls back to its empty dropzone.
    await expect(fileRow).toBeHidden({ timeout: 15_000 })
    await expect(page.getByText(/drag & drop files here/i)).toBeVisible()
  })
})
