import { expect, type Page, test } from '@playwright/test'
import { FIXTURE_PROMO_PRODUCT, gotoIndex, login } from './helpers'

const CATEGORIES_PATH = (storeId: string) => `/${storeId}/products/categories`
const CTA = /new category/i

// The category tree renders each row's name as a clickable <button> (it
// navigates to the detail page). Anchor on the exact name to avoid matching
// substrings of sibling categories created by other tests in the serial run.
function treeRow(page: Page, name: string) {
  return page.getByRole('button', { name: new RegExp(`^${name}$`) })
}

// Create a top-level category through the full-page "New category" form and
// land back on the tree. Returns once the new row is visible.
async function createCategory(page: Page, name: string) {
  await page.getByRole('button', { name: CTA }).click()
  await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

  await page.locator('#category-name').fill(name)
  await page.getByRole('button', { name: /^save$/i }).click()

  // Create replaces the new-form route in history; back lands on the tree.
  await expect(page.locator('#category-name')).toHaveValue(name, { timeout: 15_000 })
  await page.getByRole('button', { name: /^back$/i }).click()
  await expect(page).toHaveURL(/\/products\/categories(?:\?|$)/, { timeout: 15_000 })
  await expect(page.getByRole('heading', { name: /^categories$/i })).toBeVisible({
    timeout: 15_000,
  })
  await expect(treeRow(page, name)).toBeVisible({ timeout: 15_000 })
}

test.describe('categories management', () => {
  test('creates a category', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATEGORIES_PATH(creds.store_id), CTA)

    const name = `E2E Category ${Date.now()}`
    await createCategory(page, name)

    await expect(treeRow(page, name)).toBeVisible()
  })

  test('edits a category name', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATEGORIES_PATH(creds.store_id), CTA)

    const original = `E2E Edit ${Date.now()}`
    await createCategory(page, original)

    // Click the category name in the tree → full-page edit.
    await treeRow(page, original).click()
    await expect(page.locator('#category-name')).toHaveValue(original, { timeout: 15_000 })

    const renamed = `${original} Renamed`
    await page.locator('#category-name').fill(renamed)
    await page.getByRole('button', { name: /^save$/i }).click()

    // Back to the tree — the renamed row is present, the old name is gone.
    await page.goto(CATEGORIES_PATH(creds.store_id))
    await expect(treeRow(page, renamed)).toBeVisible({ timeout: 15_000 })
    await expect(treeRow(page, original)).toHaveCount(0)
  })

  test('adds and removes a product', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATEGORIES_PATH(creds.store_id), CTA)

    const name = `E2E Products ${Date.now()}`
    await createCategory(page, name)
    await treeRow(page, name).click()
    await expect(page.locator('#category-name')).toHaveValue(name, { timeout: 15_000 })

    // Fresh category: the products panel shows its empty state.
    await expect(page.getByText(/no products in this category yet/i)).toBeVisible({
      timeout: 15_000,
    })

    // Open the picker sheet, search for the seeded product, select it, confirm.
    await page.getByRole('button', { name: /add products/i }).click()
    const picker = page.getByRole('dialog')
    await expect(picker.getByRole('heading', { name: /add products to category/i })).toBeVisible()

    // Search is debounced + async; wait for the matching option to render
    // before selecting it.
    await picker.getByRole('searchbox').fill(FIXTURE_PROMO_PRODUCT)
    const option = picker
      .getByRole('button', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
      .first()
    await expect(option).toBeVisible({ timeout: 15_000 })
    await option.click()

    // Selecting stages it; the confirm button flips from "Add 0" to "Add 1".
    const confirm = picker.getByRole('button', { name: /^add 1$/i })
    await expect(confirm).toBeEnabled({ timeout: 15_000 })
    await confirm.click()

    // The product row renders immediately, staged — the badge marks it as
    // not yet persisted, and the page's Save is what writes it.
    const productRow = page.getByRole('row', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
    await expect(productRow).toBeVisible({ timeout: 15_000 })
    await expect(productRow.getByText(/^new$/i)).toBeVisible()

    await page.getByRole('button', { name: /^save$/i }).click()

    // One Save, one toast — the membership flush rides inside the category
    // update and must not announce itself separately. Asserted before the
    // staged badge clears, because toasts auto-dismiss after a few seconds.
    // `[data-type]` is the toast root; dnd-kit also renders an empty
    // `role="status"` region, so counting that role would overcount.
    // Exactly one toast for the whole Save: the membership flush rides inside
    // the category update and must not announce itself separately.
    // `toHaveText` on the collection asserts the full stack in one shot, so a
    // second toast fails the array comparison rather than slipping past a
    // count that was momentarily 1.
    const toasts = page.locator('[role="status"][data-type]')
    await expect(toasts).toHaveText([/category updated/i])

    await expect(productRow.getByText(/^new$/i)).toHaveCount(0, { timeout: 15_000 })

    // Reload and prove the membership actually persisted.
    await page.reload()
    await expect(productRow).toBeVisible({ timeout: 15_000 })

    // Removing stages too — no confirm, because Save is the confirmation.
    await productRow.getByRole('button', { name: /remove from category/i }).click()
    await expect(productRow.getByRole('button', { name: /restore/i })).toBeVisible()

    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/no products in this category yet/i)).toBeVisible({
      timeout: 15_000,
    })

    await page.reload()
    await expect(page.getByText(/no products in this category yet/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  test('repositions a top-level category', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATEGORIES_PATH(creds.store_id), CTA)

    // Two fresh siblings with a shared prefix so their relative order is
    // unambiguous and isolated from other rows.
    const prefix = `E2E Reorder ${Date.now()}`
    const first = `${prefix} A`
    const second = `${prefix} B`
    await createCategory(page, first)
    await createCategory(page, second)

    const rowA = treeRow(page, first)
    const rowB = treeRow(page, second)
    await expect(rowA).toBeVisible()
    await expect(rowB).toBeVisible()

    // Drag B above A. dnd-kit's PointerSensor has `activationConstraint:
    // { distance: 5 }`, so move past the threshold before settling on the
    // target — a single dragTo() can land below the activation distance.
    const handleB = rowB.locator('xpath=ancestor::tr').getByLabel(/drag to reorder/i)
    const targetBox = await rowA.locator('xpath=ancestor::tr').boundingBox()
    if (!targetBox) throw new Error('could not resolve row A bounding box')

    await handleB.hover()
    await page.mouse.down()
    await page.mouse.move(targetBox.x + targetBox.width / 2, targetBox.y - 4, { steps: 8 })
    await page.mouse.move(targetBox.x + targetBox.width / 2, targetBox.y + 2, { steps: 4 })
    await page.mouse.up()

    // After reordering, B precedes A in the tree's DOM order. Compare the
    // vertical position of the two rows.
    await expect(async () => {
      const boxA = await rowA.boundingBox()
      const boxB = await rowB.boundingBox()
      expect(boxA && boxB).toBeTruthy()
      expect((boxB as { y: number }).y).toBeLessThan((boxA as { y: number }).y)
    }).toPass({ timeout: 15_000 })
  })
})
