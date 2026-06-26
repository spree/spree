import { expect, test } from '@playwright/test'
import { login } from './helpers'
import { createProduct } from './products-helpers'

// The e2e store has a US/USD (default_locale en) market plus a Europe/EUR
// (default_locale de) market (see global-setup), so `de` is available as a
// non-default translation locale and the translations editor renders.
test.describe('product translations', () => {
  test('translates a product name into a non-default locale', async ({ page }) => {
    const creds = await login(page)

    const suffix = Date.now()
    const name = `E2E Translatable ${suffix}`
    await createProduct(page, creds.store_id, name)

    // Open the full-page translations editor from the launcher card.
    await page.getByRole('button', { name: /manage translations/i }).click()

    // The editor shows the Field | Original | <locale> spreadsheet. The
    // Original column shows the source value read-only.
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByText('Original', { exact: true })).toBeVisible({ timeout: 15_000 })
    await expect(dialog.getByTestId('source-name')).toContainText(name)

    // Grid cell for the `name` field in the `de` locale column.
    const translated = `Übersetzt ${suffix}`
    await dialog.getByLabel('name de').fill(translated)
    await dialog.getByRole('button', { name: /^save translations$/i }).click()

    // Success toast confirms persistence (UI-only assertion).
    await expect(page.getByText(/translations saved/i)).toBeVisible({ timeout: 15_000 })

    // Reopen the editor and confirm the translated value persisted.
    await page.getByRole('button', { name: /^close$/i }).click()
    await page.getByRole('button', { name: /manage translations/i }).click()
    await expect(page.getByRole('dialog').getByLabel('name de')).toHaveValue(translated, {
      timeout: 15_000,
    })
  })

  test('focusing a rich-text cell without typing does not mark the editor dirty', async ({
    page,
  }) => {
    const creds = await login(page)
    await createProduct(page, creds.store_id, `E2E RichText ${Date.now()}`)

    await page.getByRole('button', { name: /manage translations/i }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByText('Original', { exact: true })).toBeVisible({ timeout: 15_000 })

    // Save is disabled while nothing is dirty.
    const save = dialog.getByRole('button', { name: /^save translations$/i })
    await expect(save).toBeDisabled()

    // Click into the description (rich-text) cell — its editor emits `<p></p>`
    // on mount/focus, which must NOT register as a change. Exact match so it
    // doesn't also resolve `meta_description de`.
    await dialog.getByLabel('description de', { exact: true }).click()

    await expect(save).toBeDisabled()
    await expect(dialog.getByText(/unsaved change/i)).toHaveCount(0)
  })
})
