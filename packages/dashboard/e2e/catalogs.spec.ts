import { expect, type Page, test } from '@playwright/test'
import { FIXTURE_PROMO_PRODUCT, gotoIndex, login } from './helpers'

const CATALOGS_PATH = (storeId: string) => `/${storeId}/products/catalogs`
const CTA = /add catalog/i

async function createCatalog(page: Page, name: string) {
  await page.getByRole('button', { name: CTA }).click()
  const sheet = page.getByRole('dialog')
  await expect(sheet.getByRole('heading', { name: /new catalog/i })).toBeVisible()
  await sheet.locator('#catalog-name').fill(name)
  await sheet.getByRole('button', { name: /create catalog/i }).click()
  // On success the sheet navigates to the new catalog's detail page.
  await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
}

async function saveCatalog(page: Page) {
  await page
    .getByRole('main')
    .getByRole('button', { name: /^save$/i })
    .first()
    .click()
}

// The catalog detail page saves in one shot: settings and staged product
// changes flush together from the header Save, same as the price list editor.
test.describe('catalogs', () => {
  test('creates a catalog', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATALOGS_PATH(creds.store_id), CTA)

    const name = `E2E Catalog ${Date.now()}`
    await createCatalog(page, name)

    await page.goto(CATALOGS_PATH(creds.store_id))
    await expect(page.getByText(name)).toBeVisible({ timeout: 15_000 })
  })

  test('stages product membership and persists it on Save', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATALOGS_PATH(creds.store_id), CTA)

    const name = `E2E Catalog Products ${Date.now()}`
    await createCatalog(page, name)

    // Fresh catalog: the products card shows its empty state.
    await expect(page.getByText(/no products in this catalog yet/i)).toBeVisible({
      timeout: 15_000,
    })

    // Stage a product through the picker sheet — it renders immediately with
    // the "New" badge but is not persisted yet.
    await page.getByRole('button', { name: /add products/i }).click()
    const picker = page.getByRole('dialog')
    await expect(picker.getByRole('heading', { name: /add products to catalog/i })).toBeVisible()
    await picker.getByRole('searchbox').fill(FIXTURE_PROMO_PRODUCT)
    const option = picker
      .getByRole('button', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
      .first()
    await expect(option).toBeVisible({ timeout: 15_000 })
    await option.click()
    await picker.getByRole('button', { name: /^add 1$/i }).click()
    await expect(picker).toBeHidden({ timeout: 15_000 })

    const productRow = page.getByRole('row', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
    await expect(productRow).toBeVisible({ timeout: 15_000 })
    await expect(productRow.getByText(/^new$/i)).toBeVisible()

    // Save flushes the staged addition; the badge disappears once the row
    // comes back from the server.
    await saveCatalog(page)
    await expect(productRow.getByText(/^new$/i)).toHaveCount(0, { timeout: 15_000 })

    // Reload and prove the membership actually persisted.
    await page.reload()
    await expect(productRow).toBeVisible({ timeout: 15_000 })

    // Removing marks the row (restore stays available) and only Save makes
    // it real.
    await productRow.getByRole('button', { name: /remove from catalog/i }).click()
    await expect(productRow.getByRole('button', { name: /restore/i })).toBeVisible()

    // A product staged for removal is re-pickable — the picker must not lock
    // it as "already added", or the row's restore arrow is the only way back.
    await page.getByRole('button', { name: /add products/i }).click()
    const rePicker = page.getByRole('dialog')
    await rePicker.getByRole('searchbox').fill(FIXTURE_PROMO_PRODUCT)
    const reOption = rePicker
      .getByRole('button', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
      .first()
    await expect(reOption).toBeEnabled({ timeout: 15_000 })
    await reOption.click()
    await rePicker.getByRole('button', { name: /^add 1$/i }).click()
    await expect(rePicker).toBeHidden({ timeout: 15_000 })
    // Re-picking cancels the removal rather than staging a duplicate.
    await expect(productRow.getByRole('button', { name: /restore/i })).toHaveCount(0)
    await expect(productRow).toHaveCount(1)

    // Remove it again, for real this time.
    await productRow.getByRole('button', { name: /remove from catalog/i }).click()
    await expect(productRow.getByRole('button', { name: /restore/i })).toBeVisible()

    await saveCatalog(page)
    await expect(page.getByText(/no products in this catalog yet/i)).toBeVisible({
      timeout: 15_000,
    })

    // Reload and prove the removal persisted too.
    await page.reload()
    await expect(page.getByText(/no products in this catalog yet/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  test('renames a catalog from the header Save', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATALOGS_PATH(creds.store_id), CTA)

    const name = `E2E Catalog Rename ${Date.now()}`
    await createCatalog(page, name)

    const renamed = `${name} v2`
    await page.locator('#catalog-name').fill(renamed)
    await saveCatalog(page)
    await expect(page.getByRole('heading', { name: renamed })).toBeVisible({ timeout: 15_000 })

    await page.reload()
    await expect(page.locator('#catalog-name')).toHaveValue(renamed, { timeout: 15_000 })
  })
})
