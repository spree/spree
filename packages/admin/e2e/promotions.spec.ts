import { expect, type Page, test } from '@playwright/test'
import { login, rowButton } from './helpers'

// Fixture identifiers — kept in sync with `global-setup.ts`. The bootstrap
// seeds one of each so the resource pickers below have something to match.
const FIXTURE_TAXON = 'E2E Promo Category'
const FIXTURE_PRODUCT = 'E2E Promo Product'
const FIXTURE_CUSTOMER_EMAIL = 'e2e-promo-customer@example.com'
const FIXTURE_CUSTOMER_GROUP = 'E2E Promo Group'
const FIXTURE_COUNTRY = 'United States'

async function gotoIndex(page: Page, storeId: string) {
  await page.goto(`/${storeId}/promotions`)
  await expect(page.getByRole('button', { name: /new promotion/i })).toBeVisible({
    timeout: 15_000,
  })
}

async function startNewPromotion(page: Page, storeId: string, name: string) {
  await page.getByRole('button', { name: /new promotion/i }).click()
  await expect(page).toHaveURL(new RegExp(`/${storeId}/promotions/new`), { timeout: 15_000 })
  await expect(page.getByRole('heading', { name: /^new promotion$/i })).toBeVisible({
    timeout: 15_000,
  })
  await page.locator('#name').fill(name)
  // Kind defaults to "Coupon code"; switch to automatic so we don't have to
  // generate a code each time.
  await page.locator('#kind').click()
  await page.getByRole('option', { name: /automatic/i }).click()
}

/**
 * Open the Add Rule sheet and pick a rule type. The picker button text is
 * the rule class demodulized + titleized (e.g. `Taxon`, not `Category` —
 * the SPA renames it inside the editor but the picker still shows the
 * class name).
 */
async function pickRule(page: Page, ruleLabel: RegExp) {
  await page.getByRole('button', { name: /^add rule$/i }).click()
  await expect(page.getByRole('heading', { name: /^add rule$/i })).toBeVisible()
  await page.getByRole('button', { name: ruleLabel }).click()
}

async function pickAction(page: Page, actionLabel: RegExp) {
  await page.getByRole('button', { name: /^add action$/i }).click()
  await expect(page.getByRole('heading', { name: /^add action$/i })).toBeVisible()
  await page.getByRole('button', { name: actionLabel }).click()
}

/**
 * Drive a `<ResourceMultiAutocomplete>` to add one option: type a query,
 * wait for the matching option, click it. Base UI's Combobox closes the
 * dropdown on select; don't press Escape because the keydown bubbles up
 * to the Sheet and dismisses the entire editor.
 */
async function pickAutocompleteOption(page: Page, placeholderRegex: RegExp, optionLabel: string) {
  const input = page.getByRole('dialog').getByPlaceholder(placeholderRegex)
  await input.fill(optionLabel)
  await page.getByRole('option', { name: new RegExp(optionLabel, 'i') }).first().click()
}

async function saveEditor(page: Page) {
  await page
    .getByRole('dialog')
    .getByRole('button', { name: /^save$/i })
    .click()
}

async function submitCreate(page: Page, name: string) {
  await page.getByRole('button', { name: /^create promotion$/i }).click()
  await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
}

test.describe('promotions', () => {
  test('lists promotions', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, creds.store_id)
  })

  test('creates an automatic promotion with a rule and an action', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, creds.store_id)

    const name = `E2E Promo ${Date.now()}`

    await startNewPromotion(page, creds.store_id, name)

    // Picking a rule type appends the draft immediately and opens the editor.
    // For a no-preference rule ("First order"), Save is disabled — the user
    // just closes the editor with Cancel. The draft is already in the array.
    await pickRule(page, /^first order$/i)
    await expect(page.getByRole('heading', { name: /^first order$/i })).toBeVisible({
      timeout: 5_000,
    })
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^cancel$/i })
      .click()

    // Same flow for an action — Free shipping has no calculator/preferences.
    await pickAction(page, /^free shipping$/i)
    const actionCancelBtn = page.getByRole('dialog').getByRole('button', { name: /^cancel$/i })
    if (await actionCancelBtn.isVisible()) {
      await actionCancelBtn.click()
    }

    await submitCreate(page, name)
  })

  test('removes a rule and an action while editing', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, creds.store_id)

    const name = `E2E Promo Edit ${Date.now()}`

    await startNewPromotion(page, creds.store_id, name)

    await pickRule(page, /^first order$/i)
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^cancel$/i })
      .click()

    await pickAction(page, /^free shipping$/i)
    const seedActionCancel = page.getByRole('dialog').getByRole('button', { name: /^cancel$/i })
    if (await seedActionCancel.isVisible()) {
      await seedActionCancel.click()
    }

    await submitCreate(page, name)

    // Now on the edit page. Confirm rule + action present, then remove them.
    await expect(page.getByText(/^first order$/i).first()).toBeVisible()
    await expect(page.getByText(/^free shipping$/i).first()).toBeVisible()

    // Each rule/action row is a flex container holding an edit button (with
    // the rule label) and a trash button. Scope by the row's class so we
    // don't pick up unrelated buttons in ancestor wrappers.
    const ruleRow = page.locator('div.items-stretch').filter({ hasText: 'First order' }).first()
    await ruleRow.getByRole('button').last().click()
    await expect(page.getByRole('heading', { name: /remove rule\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^remove$/i })
      .click()
    await expect(page.getByText(/^first order$/i)).toHaveCount(0, { timeout: 5_000 })

    const actionRow = page.locator('div.items-stretch').filter({ hasText: 'Free shipping' }).first()
    await actionRow.getByRole('button').last().click()
    await expect(page.getByRole('heading', { name: /remove action\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^remove$/i })
      .click()
    await expect(page.getByText(/^free shipping$/i)).toHaveCount(0, { timeout: 5_000 })

    // Save the now-empty promotion.
    await page.getByRole('button', { name: /^save$/i }).click()
  })

  // Each test below exercises one custom rule/action editor end-to-end. We
  // care that the editor opens, the resource picker resolves a real record,
  // and Save round-trips through the server without errors. The fixture
  // records are seeded once in `global-setup.ts`.

  test('creates a promotion with a Country rule', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, creds.store_id)

    const name = `E2E Country Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    await pickRule(page, /^country$/i)
    await expect(page.getByRole('heading', { name: /^country$/i })).toBeVisible({
      timeout: 5_000,
    })
    await pickAutocompleteOption(page, /search countries/i, FIXTURE_COUNTRY)
    await saveEditor(page)

    // Row reflects the picked country in the summary line.
    await expect(page.getByText(FIXTURE_COUNTRY).first()).toBeVisible({ timeout: 5_000 })

    await submitCreate(page, name)
  })

  test('creates a promotion with a Product rule', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, creds.store_id)

    const name = `E2E Product Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    // Picker label is the translated `human_name` ("Product(s)"); editor
    // heading mirrors the same translation.
    await pickRule(page, /^product\(s\)$/i)
    await expect(page.getByRole('heading', { name: /^product\(s\)$/i })).toBeVisible({
      timeout: 5_000,
    })

    // Default match policy "any" is preselected; flip to "all" to exercise
    // the MatchPolicyPicker click handler.
    await page.getByRole('button', { name: /all of these products/i }).click()

    await pickAutocompleteOption(page, /search products by name/i, FIXTURE_PRODUCT)
    await saveEditor(page)

    await expect(page.getByText(FIXTURE_PRODUCT).first()).toBeVisible({ timeout: 5_000 })

    await submitCreate(page, name)
  })

  test('creates a promotion with a Category rule', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, creds.store_id)

    const name = `E2E Category Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    // Class is `Spree::Promotion::Rules::Taxon`; `human_name` is translated
    // to "Categories" per the 6.0 Taxon→Category rename.
    await pickRule(page, /^categories$/i)
    await expect(page.getByRole('heading', { name: /^categories$/i })).toBeVisible({
      timeout: 5_000,
    })
    await page.getByRole('button', { name: /any of these categories/i }).click()

    await pickAutocompleteOption(page, /search categories/i, FIXTURE_TAXON)
    await saveEditor(page)

    await expect(page.getByText(FIXTURE_TAXON).first()).toBeVisible({ timeout: 5_000 })

    await submitCreate(page, name)
  })

  test('creates a promotion with a Customer rule', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, creds.store_id)

    const name = `E2E Customer Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    // Class is `Rules::User`; `human_name` is translated to "Customers"
    // because the rule keys off `Spree::Order#user_id`.
    await pickRule(page, /^customers$/i)
    await expect(page.getByRole('heading', { name: /^customers$/i })).toBeVisible({
      timeout: 5_000,
    })

    // Search by the seeded `first_name` — the user.search Ransack scope hits
    // first_name/last_name/email. Email search is exact-match (lower) and
    // the Base UI combobox debounces input enough that we hit "No matches"
    // for partial emails; the first_name path is the most reliable.
    await pickAutocompleteOption(page, /search customers by name or email/i, 'Promo')
    await saveEditor(page)

    // Row summary uses `full_name || email` — seeded customer has both, so
    // the rendered chip is the full name.
    await expect(page.getByText('Promo Customer').first()).toBeVisible({ timeout: 5_000 })

    await submitCreate(page, name)
  })

  test('creates a promotion with a Customer Group rule', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, creds.store_id)

    const name = `E2E Group Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    // `human_name` is translated to "Customer Group(s)".
    await pickRule(page, /^customer group\(s\)$/i)
    await expect(page.getByRole('heading', { name: /^customer group\(s\)$/i })).toBeVisible({
      timeout: 5_000,
    })

    await pickAutocompleteOption(page, /search customer groups/i, FIXTURE_CUSTOMER_GROUP)
    await saveEditor(page)

    await expect(page.getByText(FIXTURE_CUSTOMER_GROUP).first()).toBeVisible({ timeout: 5_000 })

    await submitCreate(page, name)
  })

  test('creates a promotion with a Create Adjustment action', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, creds.store_id)

    const name = `E2E Adjustment Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    // Picker labels come from `Spree.t("promotion_action_types.*.name")`.
    await pickAction(page, /^create whole-order adjustment$/i)
    await expect(
      page.getByRole('heading', { name: /^create whole-order adjustment$/i }),
    ).toBeVisible({ timeout: 5_000 })

    // Calculator defaults to the first entry once the catalog arrives; saving
    // without changes proves the auto-default + preferences round-trip work.
    // Wait for the calculator trigger to leave the "Loading…" placeholder
    // before saving so the form isn't disabled.
    await expect(page.locator('#calculator-type')).toBeEnabled({ timeout: 10_000 })
    await saveEditor(page)

    await expect(page.getByText(/^create whole-order adjustment$/i).first()).toBeVisible()

    await submitCreate(page, name)
  })

  test('creates a promotion with a Create Item Adjustments action', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, creds.store_id)

    const name = `E2E Item Adjustments Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    await pickAction(page, /^create per-line-item adjustment$/i)
    await expect(
      page.getByRole('heading', { name: /^create per-line-item adjustment$/i }),
    ).toBeVisible({ timeout: 5_000 })

    await expect(page.locator('#calculator-type')).toBeEnabled({ timeout: 10_000 })
    await saveEditor(page)

    await expect(page.getByText(/^create per-line-item adjustment$/i).first()).toBeVisible()

    await submitCreate(page, name)
  })

  test('deletes a promotion', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, creds.store_id)

    const name = `E2E Promo Delete ${Date.now()}`

    await startNewPromotion(page, creds.store_id, name)
    await submitCreate(page, name)

    await page.getByRole('button', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete promotion\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    // Navigates back to the index.
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/promotions(?:\\?|$)`), {
      timeout: 15_000,
    })
    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
