import { expect, type Page, test } from '@playwright/test'
import {
  clickBulkAction,
  FIXTURE_BULK_CATEGORY,
  FIXTURE_BULK_PRODUCT_A,
  FIXTURE_BULK_PRODUCT_B,
  FIXTURE_BULK_PRODUCT_C,
  FIXTURE_BULK_PRODUCT_D,
  FIXTURE_BULK_PRODUCT_E,
  FIXTURE_BULK_PRODUCT_F,
  FIXTURE_BULK_PRODUCT_G,
  FIXTURE_BULK_PRODUCT_H,
  FIXTURE_BULK_PRODUCT_I,
  FIXTURE_BULK_PRODUCT_J,
  gotoIndex,
  login,
} from './helpers'

const PRODUCTS_PATH = (storeId: string) => `/${storeId}/products`
const CTA = /add product/i

/**
 * Tick the row-level checkbox of the row whose name cell contains
 * `productName`. The leading checkbox cell carries `aria-label="Select row"`
 * (set by `<ResourceTable>` when `bulkActions` is supplied).
 */
async function selectRow(page: Page, productName: string) {
  await page
    .locator('tr')
    .filter({ hasText: productName })
    .getByRole('checkbox', { name: /select row/i })
    .check()
}

/**
 * Open the row-action kebab menu for the row whose name cell contains
 * `productName`. The menu trigger carries the universal `admin.row_actions.menu_label`
 * aria-label ("Open actions").
 */
async function openRowMenu(page: Page, productName: string) {
  await page
    .locator('tr')
    .filter({ hasText: productName })
    .getByRole('button', { name: /open actions/i })
    .click()
}

test.describe('products bulk operations', () => {
  test('archives selected products via Set status…', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), CTA)

    // Both seeded products start as Active. Sanity-check before mutating.
    await expect(page.getByRole('link', { name: FIXTURE_BULK_PRODUCT_A })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByRole('link', { name: FIXTURE_BULK_PRODUCT_B })).toBeVisible()

    await selectRow(page, FIXTURE_BULK_PRODUCT_A)
    await selectRow(page, FIXTURE_BULK_PRODUCT_B)
    await expect(page.getByText(/^2 selected$/)).toBeVisible()

    await clickBulkAction(page, /set status/i)
    await expect(page.getByRole('heading', { name: /set product status/i })).toBeVisible()

    await page.getByRole('combobox').click()
    await page.getByRole('option', { name: /^archived$/i }).click()

    // Regression guard: the trigger must render the translated label ("Archived"),
    // not the raw status value ("archived"). Base UI's <SelectValue> only resolves
    // the label when the <Select> is given an `items` array.
    await expect(page.getByRole('combobox')).toHaveText('Archived')

    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^apply$/i })
      .click()

    // The bulk-action bar surfaces a counted success toast, and the rows'
    // `<StatusBadge>` swaps to Archived once the table refetches.
    await expect(page.getByText(/updated status on 2 products/i)).toBeVisible({
      timeout: 15_000,
    })
    const rowA = page.locator('tr').filter({ hasText: FIXTURE_BULK_PRODUCT_A })
    const rowB = page.locator('tr').filter({ hasText: FIXTURE_BULK_PRODUCT_B })
    await expect(rowA.getByText(/archived/i)).toBeVisible()
    await expect(rowB.getByText(/archived/i)).toBeVisible()
  })

  test('attaches selected products to a category via Add to categories…', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), CTA)

    await selectRow(page, FIXTURE_BULK_PRODUCT_C)
    await selectRow(page, FIXTURE_BULK_PRODUCT_D)
    await expect(page.getByText(/^2 selected$/)).toBeVisible()

    await clickBulkAction(page, /add to categories/i)
    await expect(page.getByRole('heading', { name: /^add to categories$/i })).toBeVisible()

    // The category combobox is a chips-with-search picker. Type the seed
    // category name and pick the matching option.
    await page
      .getByRole('dialog')
      .getByPlaceholder(/search categories/i)
      .fill(FIXTURE_BULK_CATEGORY)
    await page
      .getByRole('option', { name: new RegExp(FIXTURE_BULK_CATEGORY, 'i') })
      .first()
      .click()
    await page.getByRole('dialog').getByRole('button', { name: /^add$/i }).click()

    await expect(page.getByText(/added 2 products to categories/i)).toBeVisible({
      timeout: 15_000,
    })

    // Open product C's edit page and confirm the category chip is rendered.
    await page.getByRole('link', { name: FIXTURE_BULK_PRODUCT_C }).click()
    await expect(page.getByRole('heading', { name: FIXTURE_BULK_PRODUCT_C })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(FIXTURE_BULK_CATEGORY)).toBeVisible()
  })

  test('tags selected products via Add tags…', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), CTA)

    // Unique tag name per run so re-running the suite locally doesn't trip on
    // the "already tagged" path.
    const tagName = `e2e-bulk-tag-${Date.now()}`

    await selectRow(page, FIXTURE_BULK_PRODUCT_E)
    await selectRow(page, FIXTURE_BULK_PRODUCT_F)
    await expect(page.getByText(/^2 selected$/)).toBeVisible()

    await clickBulkAction(page, /^add tags…$/i)
    await expect(page.getByRole('heading', { name: /^add tags$/i })).toBeVisible()

    // TagCombobox: type the new tag, press Enter to confirm it as a chip.
    const tagInput = page.getByRole('dialog').getByPlaceholder(/type to add tags/i)
    await tagInput.fill(tagName)
    await tagInput.press('Enter')
    await expect(page.getByRole('dialog').getByText(tagName)).toBeVisible()

    await page.getByRole('dialog').getByRole('button', { name: /^add$/i }).click()

    await expect(page.getByText(/added tags to 2 products/i)).toBeVisible({ timeout: 15_000 })
  })

  test('soft-deletes selected products via the bulk Delete action', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), CTA)

    await expect(page.getByRole('link', { name: FIXTURE_BULK_PRODUCT_G })).toBeVisible({
      timeout: 15_000,
    })
    await selectRow(page, FIXTURE_BULK_PRODUCT_G)
    await selectRow(page, FIXTURE_BULK_PRODUCT_H)
    await expect(page.getByText(/^2 selected$/)).toBeVisible()

    // The Delete bulk action confirms via the shared confirm dialog (NOT the
    // form-based BulkDialog) — the confirm dialog uses role="alertdialog" or
    // role="dialog" with the heading "Delete {n} products?".
    await clickBulkAction(page, /^delete$/i)
    await expect(page.getByRole('heading', { name: /delete 2 products\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(page.getByText(/deleted 2 products/i)).toBeVisible({ timeout: 15_000 })

    // Once the table refetches, the rows are gone (soft-deleted = filtered
    // out of the default list scope).
    await expect(page.getByRole('link', { name: FIXTURE_BULK_PRODUCT_G })).toHaveCount(0, {
      timeout: 15_000,
    })
    await expect(page.getByRole('link', { name: FIXTURE_BULK_PRODUCT_H })).toHaveCount(0)
  })

  test('duplicates a product via the row-action menu and lands on its edit page', async ({
    page,
  }) => {
    const creds = await login(page)
    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), CTA)

    await openRowMenu(page, FIXTURE_BULK_PRODUCT_I)
    await page.getByRole('menuitem', { name: /duplicate/i }).click()

    // Server prefixes clones with "COPY OF " — the page title becomes the new
    // name once the navigation completes.
    await expect(
      page.getByRole('heading', { name: new RegExp(`COPY OF ${FIXTURE_BULK_PRODUCT_I}`, 'i') }),
    ).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(/product duplicated/i)).toBeVisible()
  })

  test('deletes a product via the row-action menu after confirming', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), CTA)

    // Self-contained: duplicate product J inside this test (so it survives
    // re-runs and doesn't depend on the prior clone test), then delete the
    // resulting clone via the row-action menu.
    await openRowMenu(page, FIXTURE_BULK_PRODUCT_J)
    await page.getByRole('menuitem', { name: /duplicate/i }).click()

    const cloneName = `COPY OF ${FIXTURE_BULK_PRODUCT_J}`
    await expect(page.getByRole('heading', { name: new RegExp(cloneName, 'i') })).toBeVisible({
      timeout: 15_000,
    })

    // Back to the index, find the clone row and open its menu.
    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), CTA)
    await expect(page.getByRole('link', { name: cloneName })).toBeVisible({ timeout: 15_000 })
    await openRowMenu(page, cloneName)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()

    // ConfirmProvider renders a generic confirm dialog with the
    // `admin.products.delete_label` title and the standard confirm copy.
    await expect(page.getByRole('heading', { name: /delete product/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(page.getByText(/product deleted/i)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('link', { name: cloneName })).toHaveCount(0, { timeout: 15_000 })
  })
})
