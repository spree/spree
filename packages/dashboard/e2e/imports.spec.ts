import { expect, type Page, test } from '@playwright/test'
import { login } from './helpers'

const PRODUCTS_PATH = (storeId: string) => `/${storeId}/products`

function csvFile(rows: string[]) {
  return {
    name: `e2e-import-${Date.now()}.csv`,
    mimeType: 'text/csv',
    buffer: Buffer.from(`${rows.join('\n')}\n`),
  }
}

async function openImportSheet(page: Page, storeId: string) {
  await page.goto(PRODUCTS_PATH(storeId))
  await page.getByRole('button', { name: /^import$/i }).click()
  await expect(page.getByRole('heading', { name: /import from csv/i })).toBeVisible()
}

test.describe('csv import', () => {
  test('imports products through the upload → mapping → progress → results wizard', async ({
    page,
  }) => {
    // Upload + background row processing legitimately take a while.
    test.setTimeout(180_000)

    const creds = await login(page)
    const suffix = Date.now()
    const goodName = `E2E Imported Product ${suffix}`

    await openImportSheet(page, creds.store_id)

    // Rows without name/price are guaranteed row-level failures that feed the
    // failed-rows report without failing the whole import. Thirty of them keep
    // the retry pass long enough to observe its transient copy (a single row
    // re-processes faster than the post-mutation refetch) and paginate the
    // failure report (25 per page).
    const badRows = Array.from({ length: 30 }, (_, i) => {
      const n = String(i + 1).padStart(2, '0')
      return `e2e-import-bad-${n}-${suffix},E2E-IMP-BAD-${n}-${suffix},,`
    })
    await page
      .getByRole('dialog')
      .locator('input[type="file"]')
      .setInputFiles(
        csvFile([
          'slug,sku,name,price',
          `e2e-import-ok-${suffix},E2E-IMP-OK-${suffix},${goodName},10.00`,
          ...badRows,
        ]),
      )
    await page.getByRole('button', { name: /^continue$/i }).click()

    // Mapping step — canonical headers auto-assign, so required fields are
    // already satisfied and the sample value from the file is shown.
    // (CardTitle renders a div, so match by text rather than heading role.)
    await expect(page.getByText('Map columns')).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(`e2e-import-ok-${suffix}`)).toBeVisible()

    await page.getByRole('button', { name: /start import/i }).click()

    // Progress → results, driven entirely by the 2s poll.
    await expect(page.getByText(/import completed/i)).toBeVisible({ timeout: 120_000 })
    await expect(page.getByText(/30 failed/i).first()).toBeVisible()

    // Failure report: broken rows are listed (paginated — 30 rows, 2 pages)
    // and their raw data is inspectable.
    // exact: true — "Retry failed rows (30)" would otherwise also match.
    await expect(page.getByText('Failed rows', { exact: true })).toBeVisible()
    await expect(page.getByRole('button', { name: /next page/i })).toBeVisible()
    await page
      .getByRole('button', { name: /view row data/i })
      .first()
      .click()
    await expect(page.getByText(`E2E-IMP-BAD-01-${suffix}`)).toBeVisible()

    // Retry re-runs the still-broken row: the wizard flips back into the
    // processing state (retry-pass copy) and completes again with the
    // failure intact.
    await page.getByRole('button', { name: /retry failed rows/i }).click()
    await expect(page.getByText(/retrying failed rows/i)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(/import completed/i)).toBeVisible({ timeout: 120_000 })
    await expect(page.getByRole('button', { name: /retry failed rows/i })).toBeVisible({
      timeout: 15_000,
    })

    // The good row became a real product.
    await page.goto(PRODUCTS_PATH(creds.store_id))
    await expect(page.getByText(goodName)).toBeVisible({ timeout: 15_000 })
  })

  test('blocks starting until required fields are mapped', async ({ page }) => {
    const creds = await login(page)
    const suffix = Date.now()

    await openImportSheet(page, creds.store_id)

    // No `price` column at all — a required schema field stays unmapped.
    await page
      .getByRole('dialog')
      .locator('input[type="file"]')
      .setInputFiles(
        csvFile([
          'slug,sku,name',
          `e2e-import-nomap-${suffix},E2E-IMP-NM-${suffix},No Price ${suffix}`,
        ]),
      )
    await page.getByRole('button', { name: /^continue$/i }).click()

    await expect(page.getByText('Map columns')).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('button', { name: /start import/i })).toBeDisabled()
    await expect(page.getByText(/map the required fields to continue/i)).toBeVisible()

    // The import history lists the abandoned mapping-state import too, and a
    // row click re-opens the wizard dialog right where the user left off.
    await page.goto(`/${creds.store_id}/settings/imports`)
    await expect(page.getByText(/^IM\d+/).first()).toBeVisible({ timeout: 15_000 })
    await page
      .getByText(/^IM\d+/)
      .first()
      .click()
    await expect(page.getByText('Map columns')).toBeVisible({ timeout: 15_000 })
  })
})
