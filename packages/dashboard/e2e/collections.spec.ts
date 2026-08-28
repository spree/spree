import { expect, type Page, test } from '@playwright/test'
import { FIXTURE_PROMO_PRODUCT, gotoIndex, login, openRowMenu, rowButton } from './helpers'

const COLLECTIONS_PATH = (storeId: string) => `/${storeId}/products/collections`
const CTA = /new collection/i

/**
 * Create a collection through the full-page "New collection" form. The create
 * route navigates to the edit page on success; this returns with that page
 * fully settled so a caller can edit fields without racing the hydration
 * effect (which resets the form whenever the source row refetches while the
 * form is clean).
 */
async function createCollection(page: Page, name: string) {
  await page.getByRole('button', { name: CTA }).click()
  await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

  await page.locator('#collection-name').fill(name)
  await page.getByRole('button', { name: /^save$/i }).click()

  // The edit page's heading renders from the persisted row, so waiting on it
  // (rather than on the input) confirms the refetch has already landed.
  await expect(page.getByRole('heading', { name, level: 1 })).toBeVisible({ timeout: 15_000 })
  await expect(page.locator('#collection-name')).toHaveValue(name)
}

test.describe('collections management', () => {
  test('creates a manual collection', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COLLECTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Collection ${Date.now()}`
    await createCollection(page, name)

    await page.goto(COLLECTIONS_PATH(creds.store_id))
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
  })

  test('edits the name and default sorting', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COLLECTIONS_PATH(creds.store_id), CTA)

    const original = `E2E Sort ${Date.now()}`
    await createCollection(page, original)

    const renamed = `${original} Renamed`
    await page.locator('#collection-name').fill(renamed)

    // Default sorting starts at "Manual"; switch it to best selling.
    await page.locator('#collection-sort-order').click()
    await page.getByRole('option', { name: /^best selling$/i }).click()
    await expect(page.locator('#collection-sort-order')).toHaveText(/best selling/i)

    await page.getByRole('button', { name: /^save$/i }).click()

    // The page heading re-renders from the saved row, so it flipping to the new
    // name is the signal the update round-tripped (and the sort came with it).
    await expect(page.getByRole('heading', { name: renamed, level: 1 })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.locator('#collection-sort-order')).toHaveText(/best selling/i)

    // The index shows the new name. Match it exactly — `rowButton` anchors on a
    // prefix, and `renamed` starts with `original`, so a prefix check for the
    // old name would still match the renamed row.
    await page.goto(COLLECTIONS_PATH(creds.store_id))
    await expect(rowButton(page, renamed)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('button', { name: new RegExp(`^${original}$`) })).toHaveCount(0)
  })

  test('adds and removes a product on a manual collection', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COLLECTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Members ${Date.now()}`
    await createCollection(page, name)

    // Fresh collection: the products panel shows its empty state.
    await expect(page.getByText(/no products in this collection yet/i)).toBeVisible({
      timeout: 15_000,
    })

    // Open the picker sheet, search for the seeded product, select it, confirm.
    await page.getByRole('button', { name: /add products/i }).click()
    const picker = page.getByRole('dialog')
    await expect(picker.getByRole('heading', { name: /add products to collection/i })).toBeVisible()

    // Search is debounced + async; wait for the matching option to render
    // before selecting it.
    await picker.getByRole('searchbox').fill(FIXTURE_PROMO_PRODUCT)
    const option = picker
      .getByRole('button', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
      .first()
    await expect(option).toBeVisible({ timeout: 15_000 })
    await option.click()

    const confirm = picker.getByRole('button', { name: /^add 1$/i })
    await expect(confirm).toBeEnabled({ timeout: 15_000 })
    await confirm.click()

    const productRow = page.getByRole('row', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
    await expect(productRow).toBeVisible({ timeout: 15_000 })

    // Staged, not yet written — the badge says so, and Save is what persists.
    await expect(productRow.getByText(/^new$/i)).toBeVisible()
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(productRow.getByText(/^new$/i)).toHaveCount(0, { timeout: 15_000 })

    await page.reload()
    await expect(productRow).toBeVisible({ timeout: 15_000 })

    // Removing stages too — no confirm, because Save is the confirmation.
    await productRow.getByRole('button', { name: /remove from collection/i }).click()
    await expect(productRow.getByRole('button', { name: /restore/i })).toBeVisible()

    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/no products in this collection yet/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  test('bulk-removes selected products on Save, discardable until then', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COLLECTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Bulk Remove ${Date.now()}`
    await createCollection(page, name)

    // Curate one product so there is something to select.
    await page.getByRole('button', { name: /add products/i }).click()
    const picker = page.getByRole('dialog')
    await picker.getByRole('searchbox').fill(FIXTURE_PROMO_PRODUCT)
    const option = picker
      .getByRole('button', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
      .first()
    await expect(option).toBeVisible({ timeout: 15_000 })
    await option.click()
    await picker.getByRole('button', { name: /^add 1$/i }).click()

    const productRow = page.getByRole('row', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
    await expect(productRow).toBeVisible({ timeout: 15_000 })
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(productRow.getByText(/^new$/i)).toHaveCount(0, { timeout: 15_000 })

    // Selecting a row swaps the "Add products" CTA for the bulk remove button.
    const card = page.locator('#root')
    await productRow.getByRole('checkbox').check()
    await card.getByRole('button', { name: /^remove$/i }).click()

    // Staged, not written: Discard rolls it back with the rest of the form.
    await expect(productRow.getByRole('button', { name: /restore/i })).toBeVisible()
    await page.getByRole('button', { name: /^discard$/i }).click()
    await expect(productRow.getByRole('button', { name: /restore/i })).toHaveCount(0)
    await expect(productRow).toBeVisible()

    // Staging it again and saving is what actually removes it.
    await productRow.getByRole('checkbox').check()
    await card.getByRole('button', { name: /^remove$/i }).click()
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/no products in this collection yet/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  test('flipping to rules hides the curation controls before saving', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COLLECTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Toggle ${Date.now()}`
    await createCollection(page, name)

    // Curate one product so the panel has a row carrying the controls.
    await page.getByRole('button', { name: /add products/i }).click()
    const picker = page.getByRole('dialog')
    await picker.getByRole('searchbox').fill(FIXTURE_PROMO_PRODUCT)
    const option = picker
      .getByRole('button', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
      .first()
    await expect(option).toBeVisible({ timeout: 15_000 })
    await option.click()
    await picker.getByRole('button', { name: /^add 1$/i }).click()

    const productRow = page.getByRole('row', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
    await expect(productRow).toBeVisible({ timeout: 15_000 })
    await expect(productRow.getByRole('button', { name: /remove from collection/i })).toBeVisible()

    // Switching to rule-driven membership takes the curation affordances away
    // immediately — no save required, because saving would hand membership to
    // the rules and discard anything picked by hand.
    await page.getByRole('switch', { name: /set members automatically/i }).click()

    await expect(page.getByText(/members are set by the rules above/i)).toBeVisible()
    await expect(page.getByRole('button', { name: /add products/i })).toHaveCount(0)
    await expect(productRow.getByRole('button', { name: /remove from collection/i })).toHaveCount(0)
    await expect(productRow.getByRole('checkbox')).toHaveCount(0)

    // Switching back restores them.
    await page.getByRole('switch', { name: /set members automatically/i }).click()
    await expect(page.getByRole('button', { name: /add products/i })).toBeVisible()
    await expect(productRow.getByRole('button', { name: /remove from collection/i })).toBeVisible()
  })

  test('creates an automatic collection whose membership is read-only', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COLLECTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Automatic ${Date.now()}`
    await page.getByRole('button', { name: CTA }).click()
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })
    await page.locator('#collection-name').fill(name)

    // Flipping the switch reveals the match policy and seeds a blank rule row.
    // Target the switch role specifically — Base UI also renders a hidden
    // checkbox input carrying the same accessible name.
    await page.getByRole('switch', { name: /set members automatically/i }).click()
    await expect(page.locator('#collection-rule-value-0')).toBeVisible()
    await page.locator('#collection-rule-value-0').fill('summer')

    await page.getByRole('button', { name: /^save$/i }).click()

    // Create lands on the edit page, hydrated from the persisted row — so the
    // rule and the automatic flag both round-tripped through the API.
    await expect(page.getByRole('heading', { name, level: 1 })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#collection-rule-value-0')).toHaveValue('summer')

    // The products panel is read-only: it explains that the rules own the
    // membership and offers no way to curate by hand.
    await expect(page.getByText(/members are set by the rules above/i)).toBeVisible()
    await expect(page.getByRole('button', { name: /add products/i })).toHaveCount(0)

    // The index labels it as automatic.
    await page.goto(COLLECTIONS_PATH(creds.store_id))
    const row = page.locator('tr').filter({ hasText: name })
    await expect(row.getByText(/^automatic$/i)).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a collection', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COLLECTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Delete ${Date.now()}`
    await createCollection(page, name)
    await page.goto(COLLECTIONS_PATH(creds.store_id))
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    // Scope to the dialog — the row menu also carries a "Delete" item.
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
