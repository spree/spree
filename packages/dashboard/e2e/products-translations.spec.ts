import { expect, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import { createProduct } from './products-helpers'

const TRANSLATIONS_PATH = (storeId: string) => `/${storeId}/products/translations`

/** The records search — not the header "Search settings" command box. */
function coverageSearch(page: import('@playwright/test').Page) {
  return page.getByRole('searchbox', { name: 'Search…' })
}

async function seedProductWithPlainDescriptionTranslation(
  page: import('@playwright/test').Page,
  storeId: string,
  accessToken: string,
  name: string,
  descriptionDe: string,
): Promise<string> {
  const headers = {
    'X-Spree-Store-Id': storeId,
    Authorization: `Bearer ${accessToken}`,
  }
  const created = await page.request.post('/api/v3/admin/products', {
    headers,
    data: { name, status: 'active', price: 9.99 },
  })
  if (!created.ok()) {
    throw new Error(`Failed to seed product: ${created.status()} ${await created.text()}`)
  }
  const { id } = (await created.json()) as { id: string }

  const batched = await page.request.post('/api/v3/admin/translations/batch', {
    headers,
    data: {
      translations: [
        {
          resource_type: 'product',
          resource_id: id,
          values: { de: { description: descriptionDe } },
        },
      ],
    },
  })
  if (!batched.ok()) {
    throw new Error(`Failed to seed translation: ${batched.status()} ${await batched.text()}`)
  }

  return id
}

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

  test('opening a record whose description is stored as plain text is not dirty', async ({
    page,
  }) => {
    const creds = await login(page)
    const suffix = Date.now()
    const name = `E2E PlainDesc ${suffix}`
    // Sample-data / CSV translations store description as bare text. TipTap
    // wraps that in `<p>` on mount — that wrap must not count as an edit.
    await seedProductWithPlainDescriptionTranslation(
      page,
      creds.store_id,
      creds.accessToken,
      name,
      'Höhenverstellbarer Standventilator mit 40cm Rotordurchmesser',
    )

    await gotoIndex(page, TRANSLATIONS_PATH(creds.store_id), /import/i)
    await coverageSearch(page).fill(name)
    await page.getByRole('button', { name }).click()

    const dialog = page.getByRole('dialog')
    await expect(dialog.getByText('Original', { exact: true })).toBeVisible({ timeout: 15_000 })
    await expect(dialog.getByRole('button', { name: /^save translations$/i })).toBeDisabled()
    await expect(dialog.getByText(/unsaved change/i)).toHaveCount(0)
  })

  test('renaming a product refreshes the translations coverage list', async ({ page }) => {
    const creds = await login(page)
    const suffix = Date.now()
    const name = `E2E Rename ${suffix}`
    const renamed = `E2E Renamed ${suffix}`
    await createProduct(page, creds.store_id, name)
    const productUrl = page.url()

    await gotoIndex(page, TRANSLATIONS_PATH(creds.store_id), /import/i)
    await coverageSearch(page).fill(name)
    await expect(page.getByRole('row', { name: new RegExp(name) })).toBeVisible({ timeout: 15_000 })

    await page.goto(productUrl)
    await expect(page.getByLabel(/^name$/i)).toHaveValue(name, { timeout: 15_000 })
    await page.getByLabel(/^name$/i).fill(renamed)
    await page.getByRole('button', { name: /^save product$/i }).click()
    await expect(page.getByText(/product saved/i)).toBeVisible({ timeout: 15_000 })

    await gotoIndex(page, TRANSLATIONS_PATH(creds.store_id), /import/i)
    await coverageSearch(page).fill(renamed)
    await expect(page.getByRole('row', { name: new RegExp(renamed) })).toBeVisible({
      timeout: 15_000,
    })
  })

  test('saving a translation refreshes the coverage grid behind the editor', async ({ page }) => {
    const creds = await login(page)
    const suffix = Date.now()
    const name = `E2E Coverage ${suffix}`
    await createProduct(page, creds.store_id, name)

    await gotoIndex(page, TRANSLATIONS_PATH(creds.store_id), /import/i)
    await coverageSearch(page).fill(name)
    const row = page.getByRole('row', { name: new RegExp(name) })
    await expect(row).toBeVisible({ timeout: 15_000 })
    await expect(row.getByText('—')).toBeVisible()

    await row.getByRole('button', { name }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByText('Original', { exact: true })).toBeVisible({ timeout: 15_000 })

    await dialog.getByLabel('name de').fill(`Übersetzt ${suffix}`)
    await dialog.getByRole('button', { name: /^save translations$/i }).click()
    await expect(page.getByText(/translations saved/i)).toBeVisible({ timeout: 15_000 })
    await dialog.getByRole('button', { name: /^close$/i }).click()

    await expect(row.getByText('—')).toBeHidden({ timeout: 15_000 })
    await expect(row.getByText(/\d+\/\d+/)).toBeVisible()
  })
})
