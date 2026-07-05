import { expect, type Page, test } from '@playwright/test'
import {
  FIXTURE_PROMO_COUNTRY,
  FIXTURE_PROMO_CUSTOMER_FIRST_NAME,
  FIXTURE_PROMO_CUSTOMER_FULL_NAME,
  FIXTURE_PROMO_CUSTOMER_GROUP,
  FIXTURE_PROMO_PRODUCT,
  FIXTURE_PROMO_TAXON,
  gotoIndex,
  login,
  rowButton,
} from './helpers'

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

async function cancelEditor(page: Page) {
  await page
    .getByRole('dialog')
    .getByRole('button', { name: /^cancel$/i })
    .click()
}

async function saveEditor(page: Page) {
  await page
    .getByRole('dialog')
    .getByRole('button', { name: /^save$/i })
    .click()
}

// Base UI's Combobox closes the dropdown on select; don't press Escape because
// the keydown bubbles up to the Sheet and dismisses the entire editor.
async function pickAutocompleteOption(page: Page, placeholderRegex: RegExp, optionLabel: string) {
  const input = page.getByRole('dialog').getByPlaceholder(placeholderRegex)
  await input.fill(optionLabel)
  await page
    .getByRole('option', { name: new RegExp(optionLabel, 'i') })
    .first()
    .click()
}

async function submitCreate(page: Page, name: string) {
  await page.getByRole('button', { name: /^create promotion$/i }).click()
  await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
}

const PROMOTIONS_PATH = (storeId: string) => `/${storeId}/promotions`
const CTA = /new promotion/i

test.describe('promotions', () => {
  test('lists promotions', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PROMOTIONS_PATH(creds.store_id), CTA)
  })

  test('creates an automatic promotion with a rule and an action', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PROMOTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Promo ${Date.now()}`

    await startNewPromotion(page, creds.store_id, name)

    // No-preference rule + action: pick the type to append the draft, then
    // cancel to close the editor (Save is disabled when there's nothing to
    // configure).
    await pickRule(page, /^first order$/i)
    await expect(page.getByRole('heading', { name: /^first order$/i })).toBeVisible({
      timeout: 5_000,
    })
    await cancelEditor(page)

    await pickAction(page, /^free shipping$/i)
    await cancelEditor(page)

    await submitCreate(page, name)
  })

  test('removes a rule and an action while editing', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PROMOTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Promo Edit ${Date.now()}`

    await startNewPromotion(page, creds.store_id, name)

    await pickRule(page, /^first order$/i)
    await cancelEditor(page)

    await pickAction(page, /^free shipping$/i)
    await cancelEditor(page)

    await submitCreate(page, name)

    await expect(page.getByText(/^first order$/i).first()).toBeVisible()
    await expect(page.getByText(/^free shipping$/i).first()).toBeVisible()

    // Rule/action rows are flex containers holding an edit button (with the
    // rule label) and a trash button. Scope by the row's class so we don't
    // pick up unrelated buttons in ancestor wrappers.
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

    await page.getByRole('button', { name: /^save$/i }).click()
  })

  // Each test below exercises one custom rule/action editor end-to-end: the
  // editor opens, the resource picker resolves a fixture record (seeded in
  // global-setup.ts), and Save round-trips through the server.

  test('creates a promotion with a Country rule', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PROMOTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Country Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    await pickRule(page, /^country$/i)
    await expect(page.getByRole('heading', { name: /^country$/i })).toBeVisible({
      timeout: 5_000,
    })
    await pickAutocompleteOption(page, /search countries/i, FIXTURE_PROMO_COUNTRY)
    await saveEditor(page)

    await expect(page.getByText(FIXTURE_PROMO_COUNTRY).first()).toBeVisible({ timeout: 5_000 })

    await submitCreate(page, name)
  })

  test('creates a promotion with a Product rule', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PROMOTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Product Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    // Rule labels come from `Spree.t("promotion_rule_types.*.name")`.
    await pickRule(page, /^product\(s\)$/i)
    await expect(page.getByRole('heading', { name: /^product\(s\)$/i })).toBeVisible({
      timeout: 5_000,
    })
    // The match-policy options render as `<FieldLabel>` cards wrapping a
    // Base UI radio. Click the visible card title to pick "all".
    await page.getByText(/^all of these products$/i).click()
    await pickAutocompleteOption(page, /search products by name/i, FIXTURE_PROMO_PRODUCT)
    await saveEditor(page)

    await expect(page.getByText(FIXTURE_PROMO_PRODUCT).first()).toBeVisible({ timeout: 5_000 })

    await submitCreate(page, name)
  })

  test('creates a promotion with a Category rule', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PROMOTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Category Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    // Class is `Spree::Promotion::Rules::Taxon`; the translated label is
    // "Categories" per the 6.0 Taxon→Category rename.
    await pickRule(page, /^categories$/i)
    await expect(page.getByRole('heading', { name: /^categories$/i })).toBeVisible({
      timeout: 5_000,
    })
    await page.getByText(/^any of these categories$/i).click()
    await pickAutocompleteOption(page, /search categories/i, FIXTURE_PROMO_TAXON)
    await saveEditor(page)

    await expect(page.getByText(FIXTURE_PROMO_TAXON).first()).toBeVisible({ timeout: 5_000 })

    await submitCreate(page, name)
  })

  test('creates a promotion with a Customer rule', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PROMOTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Customer Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    // Class is `Rules::User`; translated label is "Customers" because the
    // rule keys off `Spree::Order#user_id`.
    await pickRule(page, /^customers$/i)
    await expect(page.getByRole('heading', { name: /^customers$/i })).toBeVisible({
      timeout: 5_000,
    })

    // `Spree.user_class.search` matches first_name/last_name (LIKE) and email
    // (exact). Search by first name; the row summary renders `full_name`.
    await pickAutocompleteOption(
      page,
      /search customers by name or email/i,
      FIXTURE_PROMO_CUSTOMER_FIRST_NAME,
    )
    await saveEditor(page)

    await expect(page.getByText(FIXTURE_PROMO_CUSTOMER_FULL_NAME).first()).toBeVisible({
      timeout: 5_000,
    })

    await submitCreate(page, name)
  })

  test('creates a promotion with a Customer Group rule', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PROMOTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Group Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    await pickRule(page, /^customer group\(s\)$/i)
    await expect(page.getByRole('heading', { name: /^customer group\(s\)$/i })).toBeVisible({
      timeout: 5_000,
    })
    await pickAutocompleteOption(page, /search customer groups/i, FIXTURE_PROMO_CUSTOMER_GROUP)
    await saveEditor(page)

    await expect(page.getByText(FIXTURE_PROMO_CUSTOMER_GROUP).first()).toBeVisible({
      timeout: 5_000,
    })

    await submitCreate(page, name)
  })

  test('creates a promotion with a Currency rule defaulting to store currency', async ({
    page,
  }) => {
    const creds = await login(page)
    await gotoIndex(page, PROMOTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Currency Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    // The Currency rule has a single `:currency` preference with no schema
    // default. The picker should seed it from the store's default currency so
    // saving the editor (without touching the dropdown) round-trips a real
    // value — not an empty `preferences: {}` that the server quietly accepts
    // but the merchant never sees in the rule preview.
    await pickRule(page, /^currency$/i)
    await expect(page.getByRole('heading', { name: /^currency$/i })).toBeVisible({
      timeout: 5_000,
    })
    await saveEditor(page)

    // Row summary renders `Currency: USD` (humanized key + uppercased ISO).
    await expect(page.getByText(/currency:\s*USD/i).first()).toBeVisible({ timeout: 5_000 })

    await submitCreate(page, name)

    // Reopen the saved promotion's rule editor and confirm the currency
    // persisted server-side, not just in client memory.
    await expect(page.getByText(/currency:\s*USD/i).first()).toBeVisible({ timeout: 5_000 })
  })

  test('creates a promotion with a Create Adjustment action', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PROMOTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Adjustment Promo ${Date.now()}`
    await startNewPromotion(page, creds.store_id, name)

    await pickAction(page, /^create whole-order adjustment$/i)
    await expect(
      page.getByRole('heading', { name: /^create whole-order adjustment$/i }),
    ).toBeVisible({ timeout: 5_000 })

    // Calculator defaults to the first entry once the catalog arrives; wait
    // for the trigger to enable before saving.
    await expect(page.locator('#calculator-type')).toBeEnabled({ timeout: 10_000 })
    await saveEditor(page)

    await expect(page.getByText(/^create whole-order adjustment$/i).first()).toBeVisible()

    await submitCreate(page, name)
  })

  test('creates a promotion with a Create Item Adjustments action', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PROMOTIONS_PATH(creds.store_id), CTA)

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
    await gotoIndex(page, PROMOTIONS_PATH(creds.store_id), CTA)

    const name = `E2E Promo Delete ${Date.now()}`

    await startNewPromotion(page, creds.store_id, name)
    await submitCreate(page, name)

    await page.getByRole('button', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete promotion\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/promotions(?:\\?|$)`), {
      timeout: 15_000,
    })
    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
