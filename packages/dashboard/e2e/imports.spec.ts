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

    // Row 2 has no name and no price — guaranteed row-level failure that
    // feeds the failed-rows report without failing the whole import.
    await page
      .getByRole('dialog')
      .locator('input[type="file"]')
      .setInputFiles(
        csvFile([
          'slug,sku,name,price',
          `e2e-import-ok-${suffix},E2E-IMP-OK-${suffix},${goodName},10.00`,
          `e2e-import-bad-${suffix},E2E-IMP-BAD-${suffix},,`,
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
    await expect(page.getByText(/1 failed/i).first()).toBeVisible()

    // Failure report: the broken row is listed and its raw data is inspectable.
    // exact: true — "Retry failed rows (1)" would otherwise also match.
    await expect(page.getByText('Failed rows', { exact: true })).toBeVisible()
    await page
      .getByRole('button', { name: /view row data/i })
      .first()
      .click()
    await expect(page.getByText(`E2E-IMP-BAD-${suffix}`)).toBeVisible()

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
