import { expect, type Page, test } from '@playwright/test'
import { FIXTURE_PROMO_PRODUCT, gotoIndex, login, openRowMenu, rowButton } from './helpers'

const PRICE_LISTS_PATH = (storeId: string) => `/${storeId}/products/price-lists`
const PRODUCTS_PATH = (storeId: string) => `/${storeId}/products`
const CTA = /new price list/i

async function startNewPriceList(page: Page, storeId: string, name: string) {
  await page.getByRole('button', { name: CTA }).click()
  await expect(page).toHaveURL(new RegExp(`/${storeId}/products/price-lists/new`), {
    timeout: 15_000,
  })
  await expect(page.getByRole('heading', { name: /create price list/i })).toBeVisible({
    timeout: 15_000,
  })
  await page.locator('#name').fill(name)
}

async function submitCreate(page: Page, name: string) {
  await page.getByRole('button', { name: /^create$/i }).click()
  // On success the route navigates to the edit page whose header title
  // is the list's name.
  await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
}

async function pickRule(page: Page, ruleLabel: RegExp) {
  await page.getByRole('button', { name: /^add rule$/i }).click()
  await expect(page.getByRole('heading', { name: /^add rule$/i })).toBeVisible()
  // Scope to the picker dialog — page already has rule rows with the same
  // label after a list has rules.
  await page.getByRole('dialog').getByRole('button', { name: ruleLabel }).click()
}

async function saveEditor(page: Page) {
  await page
    .getByRole('dialog')
    .getByRole('button', { name: /^save$/i })
    .click()
}

async function saveForm(page: Page) {
  // Top-of-page Save (the one in the PageHeader, which renders inside
  // <main>). Scope to <main> so we don't hit a Save button inside a
  // dialog or footer.
  await page
    .getByRole('main')
    .getByRole('button', { name: /^save$/i })
    .first()
    .click()
}

// Pick a product from the Products card's `<ResourceMultiAutocomplete>`.
// Unlike the promotions spec's helper, the picker lives on the page (not
// inside a dialog), so we scope to `main` to skip any open Sheet/Dialog.
async function pickProductOnPage(page: Page, optionLabel: string) {
  const input = page.locator('main').getByPlaceholder(/search products by name/i)
  await input.fill(optionLabel)
  await page
    .getByRole('option', { name: new RegExp(optionLabel, 'i') })
    .first()
    .click()
  // Close the listbox so the next focus (the bulk-prices button) lands cleanly.
  await input.press('Escape')
}

async function openBulkPriceEditor(page: Page) {
  // Single "Edit prices" button on both surfaces (price-list PricesCard
  // and product PageHeader).
  await page.getByRole('button', { name: /^edit prices$/i }).click()
  await expect(page.getByRole('dialog')).toBeVisible({ timeout: 15_000 })
  await expect(page.getByRole('heading', { name: /^edit prices —/i })).toBeVisible()
}

test.describe('price lists', () => {
  test('lists price lists', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRICE_LISTS_PATH(creds.store_id), CTA)
  })

  test('creates a price list', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRICE_LISTS_PATH(creds.store_id), CTA)

    const name = `E2E PL ${Date.now()}`
    await startNewPriceList(page, creds.store_id, name)
    await submitCreate(page, name)

    await page.goto(PRICE_LISTS_PATH(creds.store_id))
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
  })

  test('row click opens the edit page', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRICE_LISTS_PATH(creds.store_id), CTA)

    const name = `E2E PL Edit ${Date.now()}`
    await startNewPriceList(page, creds.store_id, name)
    await submitCreate(page, name)

    await page.goto(PRICE_LISTS_PATH(creds.store_id))
    await rowButton(page, name).click()

    await expect(page).toHaveURL(/\/products\/price-lists\/pl_/, { timeout: 15_000 })
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#name')).toHaveValue(name)
  })

  test('adds a Volume Rule via the rule editor', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRICE_LISTS_PATH(creds.store_id), CTA)

    const name = `E2E PL Rule ${Date.now()}`
    await startNewPriceList(page, creds.store_id, name)
    await submitCreate(page, name)

    // Rule-picker buttons include label + description; match by label only.
    await pickRule(page, /^volume rule\b/i)
    await expect(page.getByRole('heading', { name: /^volume rule$/i })).toBeVisible({
      timeout: 5_000,
    })
    await page
      .getByRole('dialog')
      .getByLabel(/min quantity/i)
      .fill('10')
    await saveEditor(page)

    await expect(page.getByText(/min quantity: 10/i)).toBeVisible({ timeout: 5_000 })

    await saveForm(page)

    await expect(page.getByText(/volume rule/i).first()).toBeVisible({ timeout: 15_000 })
  })

  test('bulk-edits a price-list override via the dialog', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRICE_LISTS_PATH(creds.store_id), CTA)

    const name = `E2E PL Prices ${Date.now()}`
    await startNewPriceList(page, creds.store_id, name)
    await submitCreate(page, name)

    // Attach a seeded product so the bulk editor has a row to edit.
    // Saving creates a placeholder price the editor can fill in.
    await pickProductOnPage(page, FIXTURE_PROMO_PRODUCT)
    await expect(page.getByText(/1 product selected/i)).toBeVisible({ timeout: 5_000 })
    await saveForm(page)
    // Card-counter help text updates once the placeholder price exists.
    await expect(page.getByText(/price configured/i)).toBeVisible({ timeout: 15_000 })

    await openBulkPriceEditor(page)

    // MoneyCell's editable input carries `aria-label="Price for <label>"`.
    // The fixture is a master variant with empty `options_text`, so the
    // suffix may be empty or "Default" depending on null-vs-empty handling.
    const priceInput = page
      .getByRole('dialog')
      .getByLabel(/^price for/i)
      .first()
    await expect(priceInput).toBeVisible({ timeout: 15_000 })
    // MoneyCell is a spreadsheet cell — readonly until you double-click
    // (or focus + press Enter) to enter edit mode.
    await priceInput.dblclick()
    await priceInput.fill('33.33')
    await priceInput.press('Enter')

    // Header surfaces the unsaved-change summary as soon as the cell commits.
    await expect(page.getByRole('dialog').getByText(/1 unsaved change/i)).toBeVisible()

    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save prices$/i })
      .click()

    // The dirty-summary chip disappears once the upsert resolves and the
    // editor flushes its in-memory edits map. The Sonner save-success
    // toast auto-dismisses too quickly to be a reliable signal.
    await expect(page.getByRole('dialog').getByText(/unsaved change/i)).toBeHidden({
      timeout: 15_000,
    })
    await expect(
      page
        .getByRole('dialog')
        .getByLabel(/^price for/i)
        .first(),
    ).toHaveValue('33.33')
  })

  test('bulk-edits a product base price from the product page', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), /add product/i)

    // Land on the seeded product's edit page via the index row click.
    // Product table renders the name cell as a `<Link>` (not a button).
    await page
      .getByRole('link', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
      .first()
      .click()
    await expect(page).toHaveURL(/\/products\/prod_/, { timeout: 15_000 })
    await expect(page.getByRole('heading', { name: FIXTURE_PROMO_PRODUCT })).toBeVisible({
      timeout: 15_000,
    })

    // Header "Edit prices" button (the InventoryCard one would also work).
    await openBulkPriceEditor(page)
    // Title carries the product name on this surface.
    await expect(
      page.getByRole('heading', {
        name: new RegExp(`edit prices — ${FIXTURE_PROMO_PRODUCT}`, 'i'),
      }),
    ).toBeVisible()

    const priceInput = page
      .getByRole('dialog')
      .getByLabel(/^price for/i)
      .first()
    await expect(priceInput).toBeVisible({ timeout: 15_000 })
    await priceInput.dblclick()
    await priceInput.fill('29.95')
    await priceInput.press('Enter')

    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save prices$/i })
      .click()

    await expect(page.getByRole('dialog').getByText(/unsaved change/i)).toBeHidden({
      timeout: 15_000,
    })
    await expect(
      page
        .getByRole('dialog')
        .getByLabel(/^price for/i)
        .first(),
    ).toHaveValue('29.95')
  })

  test('deletes a price list', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRICE_LISTS_PATH(creds.store_id), CTA)

    const name = `E2E PL Delete ${Date.now()}`
    await startNewPriceList(page, creds.store_id, name)
    await submitCreate(page, name)

    await page.goto(PRICE_LISTS_PATH(creds.store_id))
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete price list\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
