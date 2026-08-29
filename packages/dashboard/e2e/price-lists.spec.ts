import { expect, type Page, test } from '@playwright/test'
import {
  FIXTURE_PROMO_CUSTOMER_EMAIL,
  FIXTURE_PROMO_CUSTOMER_FIRST_NAME,
  FIXTURE_PROMO_CUSTOMER_GROUP,
  FIXTURE_PROMO_PRODUCT,
  gotoIndex,
  login,
  openRowMenu,
  rowButton,
} from './helpers'

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

// Mirrors the helper in `promotions.spec.ts`: fills the autocomplete/combobox
// inside the rule editor sheet, then clicks the first matching option. Base
// UI's Combobox closes the dropdown on select; don't press Escape because
// the keydown bubbles up to the Sheet and dismisses the editor.
async function pickAutocompleteOption(page: Page, placeholderRegex: RegExp, optionLabel: string) {
  const input = page.getByRole('dialog').getByPlaceholder(placeholderRegex)
  await input.fill(optionLabel)
  await page
    .getByRole('option', { name: new RegExp(optionLabel, 'i') })
    .first()
    .click()
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

// Add a product through the Products card's picker sheet (the same shared
// membership panel categories/collections/catalogs use). Membership lives in
// form state, so the row appears immediately but persists only on Save.
async function pickProductOnPage(page: Page, optionLabel: string) {
  await page
    .locator('main')
    .getByRole('button', { name: /^add products$/i })
    .click()
  const picker = page.getByRole('dialog')
  await expect(picker.getByRole('heading', { name: /add products to price list/i })).toBeVisible()

  // Search is debounced + async; wait for the matching option to render
  // before selecting it.
  await picker.getByRole('searchbox').fill(optionLabel)
  const option = picker.getByRole('button', { name: new RegExp(optionLabel, 'i') }).first()
  await expect(option).toBeVisible({ timeout: 15_000 })
  await option.click()

  const confirm = picker.getByRole('button', { name: /^add 1$/i })
  await expect(confirm).toBeEnabled({ timeout: 15_000 })
  await confirm.click()
  await expect(picker).toBeHidden({ timeout: 15_000 })

  // The staged product renders as a row in the membership table.
  await expect(page.getByRole('row', { name: new RegExp(optionLabel, 'i') }).first()).toBeVisible({
    timeout: 15_000,
  })
}

async function openBulkPriceEditor(page: Page) {
  // Single "Edit prices" button on both surfaces — the price list's page
  // header and the product PageHeader.
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
      .getByLabel(/minimum quantity/i)
      .fill('10')
    await saveEditor(page)

    await expect(page.getByText(/min quantity: 10/i)).toBeVisible({ timeout: 5_000 })

    await saveForm(page)

    await expect(page.getByText(/volume rule/i).first()).toBeVisible({ timeout: 15_000 })
  })

  test('adds a Customer Group Rule with the seeded group', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRICE_LISTS_PATH(creds.store_id), CTA)

    const name = `E2E PL CG Rule ${Date.now()}`
    await startNewPriceList(page, creds.store_id, name)
    await submitCreate(page, name)

    await pickRule(page, /^customer group rule\b/i)
    await expect(page.getByRole('heading', { name: /^customer group rule$/i })).toBeVisible({
      timeout: 5_000,
    })

    await pickAutocompleteOption(page, /search customer groups/i, FIXTURE_PROMO_CUSTOMER_GROUP)
    await saveEditor(page)

    // Row summary renders the group name (proves the API embed shipped the
    // resolved `customer_groups` array, which the SPA echoes on the draft).
    await expect(page.getByText(FIXTURE_PROMO_CUSTOMER_GROUP).first()).toBeVisible({
      timeout: 5_000,
    })

    await saveForm(page)

    // Reload and verify the chip + preview survive (proves the serializer
    // embed round-trips on reload, not just during the in-progress edit).
    await page.reload()
    await expect(page.getByText(FIXTURE_PROMO_CUSTOMER_GROUP).first()).toBeVisible({
      timeout: 15_000,
    })
  })

  test('adds a Customer Rule with the seeded customer', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRICE_LISTS_PATH(creds.store_id), CTA)

    const name = `E2E PL Customer Rule ${Date.now()}`
    await startNewPriceList(page, creds.store_id, name)
    await submitCreate(page, name)

    // Wire shorthand is `user_rule`; the SPA labels it "Customer rule"
    // (see `Spree::PriceRules::UserRule.human_name`).
    await pickRule(page, /^customer rule\b/i)
    await expect(page.getByRole('heading', { name: /^customer rule$/i })).toBeVisible({
      timeout: 5_000,
    })

    // `Spree.user_class.search` matches first_name (LIKE) and email (exact);
    // we type the first name to drive the search, then assert on the email
    // string the price-list `RuleSummary` renders.
    await pickAutocompleteOption(page, /search customers/i, FIXTURE_PROMO_CUSTOMER_FIRST_NAME)
    await saveEditor(page)

    await expect(page.getByText(FIXTURE_PROMO_CUSTOMER_EMAIL).first()).toBeVisible({
      timeout: 5_000,
    })

    await saveForm(page)

    await page.reload()
    await expect(page.getByText(FIXTURE_PROMO_CUSTOMER_EMAIL).first()).toBeVisible({
      timeout: 15_000,
    })
  })

  test('adds a Market Rule with the seeded default market', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRICE_LISTS_PATH(creds.store_id), CTA)

    const name = `E2E PL Market Rule ${Date.now()}`
    await startNewPriceList(page, creds.store_id, name)
    await submitCreate(page, name)

    await pickRule(page, /^market rule\b/i)
    await expect(page.getByRole('heading', { name: /^market rule$/i })).toBeVisible({
      timeout: 5_000,
    })

    // `Spree::Store#ensure_default_market` seeds a default market named
    // after the store's default country. The e2e setup defaults to US, so
    // the seeded market is "United States".
    const seededMarket = 'United States'
    await pickAutocompleteOption(page, /search markets/i, seededMarket)
    await saveEditor(page)

    await expect(page.getByText(seededMarket).first()).toBeVisible({ timeout: 5_000 })

    await saveForm(page)

    await page.reload()
    await expect(page.getByText(seededMarket).first()).toBeVisible({ timeout: 15_000 })
  })

  test('removes a rule while editing', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRICE_LISTS_PATH(creds.store_id), CTA)

    const name = `E2E PL Remove Rule ${Date.now()}`
    await startNewPriceList(page, creds.store_id, name)
    await submitCreate(page, name)

    // Stage a Volume Rule so we have a row to remove. Picker opens the
    // editor sheet automatically on the new row; submit it with valid
    // defaults so it gets persisted on save below.
    await pickRule(page, /^volume rule\b/i)
    await page
      .getByRole('dialog')
      .getByLabel(/minimum quantity/i)
      .fill('5')
    await saveEditor(page)
    await saveForm(page)
    await expect(page.getByText(/min quantity: 5/i)).toBeVisible({ timeout: 15_000 })

    // Click the trash button on the Volume Rule row, confirm the dialog,
    // and verify the row disappears. The rule list and the picker share
    // a single `<RuleRow>` div with `items-stretch`; scope to it so we
    // don't pick up unrelated buttons.
    const ruleRow = page.locator('div.items-stretch').filter({ hasText: 'Volume Rule' }).first()
    await ruleRow.getByRole('button').last().click()
    await expect(page.getByRole('heading', { name: /remove rule\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^remove$/i })
      .click()
    await expect(page.getByText(/volume rule/i)).toHaveCount(0, { timeout: 5_000 })

    // Save the form so the omission is persisted (the backend reconciles
    // "row omitted from payload" as a destroy).
    await saveForm(page)

    // Reload and prove the row is actually gone, not just hidden client-side.
    await page.reload()
    await expect(page.getByText(/volume rule/i)).toHaveCount(0, { timeout: 15_000 })
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
    await saveForm(page)
    // The Products card's description picks up the price count once
    // placeholder prices exist. A multi-currency store creates one
    // placeholder per currency, so the copy is singular or plural depending
    // on the store — match either form.
    await expect(page.getByText(/\d+ price(s)? (is|are) configured/i)).toBeVisible({
      timeout: 15_000,
    })

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

  // Multi-currency: the bulk editor scopes its grid to one currency at a time
  // via the header currency selector. Edit + save a USD price, switch to EUR,
  // edit + save again, then confirm each currency kept its own value. The e2e
  // store seeds a EUR market alongside USD (see global-setup.ts).
  test('bulk-edits price-list overrides in two currencies', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PRICE_LISTS_PATH(creds.store_id), CTA)

    const name = `E2E PL Multi-Cur ${Date.now()}`
    await startNewPriceList(page, creds.store_id, name)
    await submitCreate(page, name)

    await pickProductOnPage(page, FIXTURE_PROMO_PRODUCT)
    await saveForm(page)
    await expect(page.getByText(/\d+ price(s)? (is|are) configured/i)).toBeVisible({
      timeout: 15_000,
    })

    await openBulkPriceEditor(page)
    const dialog = page.getByRole('dialog')
    // The editor opens on the store default currency (USD).
    const currencyTrigger = dialog.getByRole('combobox').first()
    await expect(currencyTrigger).toContainText('USD')

    const priceCell = () => dialog.getByLabel(/^price for/i).first()
    await expect(priceCell()).toBeVisible({ timeout: 15_000 })
    await priceCell().dblclick()
    await priceCell().fill('40.00')
    await priceCell().press('Enter')
    await dialog.getByRole('button', { name: /^save prices$/i }).click()
    await expect(dialog.getByText(/unsaved change/i)).toBeHidden({ timeout: 15_000 })

    // Switch to EUR — the grid reloads with that currency's (empty) prices and
    // formats in the EUR market locale (de: comma decimal). Enter a localized
    // amount `55,55`; it must persist as 55.55 (not 5555).
    await currencyTrigger.click()
    await page.getByRole('option', { name: 'EUR' }).click()
    await expect(currencyTrigger).toContainText('EUR')

    await priceCell().dblclick()
    await priceCell().fill('55,55')
    await priceCell().press('Enter')
    await dialog.getByRole('button', { name: /^save prices$/i }).click()
    await expect(dialog.getByText(/unsaved change/i)).toBeHidden({ timeout: 15_000 })
    // Round-trips as the comma-decimal `55,55`, proving locale-aware parsing.
    await expect(priceCell()).toHaveValue('55,55')

    // Switch back to USD — its value is independent of the EUR edit and shown
    // period-decimal.
    await currencyTrigger.click()
    await page.getByRole('option', { name: 'USD' }).click()
    await expect(currencyTrigger).toContainText('USD')
    // Period-decimal; the grid trims trailing zeros (40.00 → 40.0).
    await expect(priceCell()).toHaveValue(/^40[.,]0+$/)
  })

  // Skip on CI: the dblclick→fill→blur pattern flakes against the fixture
  // product's seeded `33.33` price. The same code path (PricesCard inline
  // editing + product-form Save round-trip) is exercised on a fresh product
  // by products-prices-inventory.spec.ts, which uses the same fillGridCell
  // helper but never hits this flake. Tracked as a follow-up.
  test.skip('bulk-edits a product base price from the product page', async ({ page }) => {
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

    // Base product prices now live in an inline PricesCard on the product
    // page — the modal "Edit prices" flow only applies to price-list pages.
    // Use the DataGrid textbox role + commit-by-blur pattern that the rest
    // of the product e2e suite uses.
    const pricesCard = page
      .locator('[data-slot="card"]')
      .filter({ has: page.locator('[data-slot="card-title"]', { hasText: /^Prices$/ }) })
    const priceCell = pricesCard.getByRole('textbox', { name: /^price for/i }).first()
    await expect(priceCell).toBeVisible({ timeout: 15_000 })
    await priceCell.dblclick()
    await priceCell.fill('29.95')
    await priceCell.blur()

    // Save via the product-level Save button. Prices ride the product PATCH.
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    // Reload and confirm the price persisted in the inline card.
    await page.reload()
    await expect(pricesCard.getByRole('textbox', { name: /^price for/i }).first()).toHaveValue(
      /^29[.,]95$/,
      { timeout: 15_000 },
    )
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
