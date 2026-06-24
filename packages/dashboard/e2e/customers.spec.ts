import { expect, type Page, test } from '@playwright/test'
import { FIXTURE_PROMO_CUSTOMER_GROUP, fillAddressForm, gotoIndex, login } from './helpers'

const CUSTOMERS_PATH = (storeId: string) => `/${storeId}/customers`
const CTA = /new customer/i

async function createCustomer(page: Page, email: string) {
  await page.getByRole('button', { name: /new customer/i }).click()
  await expect(page.getByRole('heading', { name: /^new customer$/i })).toBeVisible()
  await page.locator('#email').fill(email)
  await page.getByRole('button', { name: /^create customer$/i }).click()
  await expect(page.getByRole('heading', { name: email })).toBeVisible({ timeout: 15_000 })
}

test.describe('customers', () => {
  test('lists customers', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)
  })

  test('creates a new customer', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-create-${Date.now()}@example.com`
    await createCustomer(page, email)

    // Back to the index, the row appears.
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)
    await expect(page.getByRole('link', { name: email })).toBeVisible({ timeout: 15_000 })
  })

  test('edits a customer profile', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-edit-${Date.now()}@example.com`
    await createCustomer(page, email)

    // `<CardTitle>` renders as a `<div>` (not an `<h*>`), so we scope by text
    // and pick the first Edit button under it.
    const profileCard = page.locator('div').filter({
      has: page.getByText('Profile', { exact: true }),
    })
    await profileCard
      .getByRole('button', { name: /^edit$/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /^edit customer$/i })).toBeVisible()

    await page.locator('#first_name').fill('Pat')
    await page.locator('#last_name').fill('Smith')
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByRole('heading', { name: 'Pat Smith' })).toBeVisible({ timeout: 15_000 })
  })

  test('adds an address', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-addr-${Date.now()}@example.com`
    await createCustomer(page, email)

    await page.getByRole('button', { name: /add address/i }).click()
    await expect(page.getByRole('heading', { name: /^add address$/i })).toBeVisible()

    await fillAddressForm(page, {
      firstName: 'Pat',
      lastName: 'Smith',
      address1: '1 Main St',
      city: 'Anytown',
      postalCode: '12345',
      phone: '555-0100',
      country: 'United States',
      state: 'California',
    })
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByText('1 Main St')).toBeVisible({ timeout: 15_000 })
  })

  test('issues store credit', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-credit-${Date.now()}@example.com`
    await createCustomer(page, email)

    await page.getByRole('button', { name: /issue store credit/i }).click()
    await expect(page.getByRole('heading', { name: /issue store credit/i })).toBeVisible()

    await page.locator('#sc-amount').fill('25.00')
    await page.locator('#sc-memo').fill('E2E test credit')
    await page.locator('#sc-category').click()
    await page.getByRole('option').first().click()

    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^issue store credit$/i })
      .click()

    await expect(page.getByText(/25\.00/).first()).toBeVisible({ timeout: 15_000 })
  })

  // Store credits are multi-currency AND localized. Selecting EUR drives both
  // the credit's currency and (via the EUR market's `de` locale) the amount's
  // display/parse format. The amount is entered comma-decimal (`1.234,56` =
  // 1234.56); the dashboard normalizes it to canonical form before sending, so
  // it persists as 1234.56 and renders €1,234.56 (en display locale) — not the
  // mangled 123456.
  test('issues store credit in EUR with a localized (comma-decimal) amount', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-credit-eur-${Date.now()}@example.com`
    await createCustomer(page, email)

    await page.getByRole('button', { name: /issue store credit/i }).click()
    await expect(page.getByRole('heading', { name: /issue store credit/i })).toBeVisible()

    // Switch to EUR first so the form's locale resolves before submit.
    await page.locator('#sc-currency').click()
    await page.getByRole('option', { name: /EUR/ }).click()
    // German-formatted amount: dot thousands, comma decimal.
    await page.locator('#sc-amount').fill('1.234,56')
    await page.locator('#sc-memo').fill('E2E EUR localized credit')
    await page.locator('#sc-category').click()
    await page.getByRole('option').first().click()

    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^issue store credit$/i })
      .click()

    // Persisted as 1234.56 EUR (not 123456): renders €1,234.56 in the en display
    // locale. The comma-decimal input round-tripped through client normalization.
    await expect(page.getByText(/€\s?1,234\.56/).first()).toBeVisible({ timeout: 15_000 })
    // Guard against the mangled value (comma treated as thousands → 123456).
    await expect(page.getByText(/123,456/)).toHaveCount(0)
  })

  // Regression: typing a USD-style `25.00`, THEN switching the currency to EUR
  // must not re-read the `.` as a thousands separator on submit (→ 2500). The
  // form reformats the amount to the new currency's locale on switch, so it
  // persists as €25.00.
  test('reformats the amount when the store-credit currency switches', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-credit-switch-${Date.now()}@example.com`
    await createCustomer(page, email)

    await page.getByRole('button', { name: /issue store credit/i }).click()
    await expect(page.getByRole('heading', { name: /issue store credit/i })).toBeVisible()

    // Type a period-decimal amount under the USD default, THEN switch to EUR.
    await page.locator('#sc-amount').fill('25.00')
    await page.locator('#sc-currency').click()
    await page.getByRole('option', { name: /EUR/ }).click()
    await page.locator('#sc-memo').fill('E2E currency switch')
    await page.locator('#sc-category').click()
    await page.getByRole('option').first().click()

    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^issue store credit$/i })
      .click()

    // €25.00, not €2,500.00.
    await expect(page.getByText(/€\s?25\.00/).first()).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(/2,500/)).toHaveCount(0)
  })

  test('edits a store credit amount', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-credit-edit-${Date.now()}@example.com`
    await createCustomer(page, email)

    await page.getByRole('button', { name: /issue store credit/i }).click()
    await expect(page.getByRole('heading', { name: /issue store credit/i })).toBeVisible()
    await page.locator('#sc-amount').fill('25.00')
    await page.locator('#sc-memo').fill('E2E credit to edit')
    await page.locator('#sc-category').click()
    await page.getByRole('option').first().click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^issue store credit$/i })
      .click()
    await expect(page.getByText(/25\.00/).first()).toBeVisible({ timeout: 15_000 })

    // Open the credit row's actions menu → Edit, change the amount, and save.
    // The trigger is an icon-only button with no accessible name, so scope to
    // the table row that shows the amount and click its button. Covers the
    // EditStoreCreditDialog raw-string submit path.
    await page
      .getByRole('row', { name: /25\.00/ })
      .getByRole('button')
      .click()
    await page.getByRole('menuitem', { name: /^edit$/i }).click()
    await expect(page.getByRole('heading', { name: /edit store credit/i })).toBeVisible()

    const amount = page.locator('#edit-sc-amount')
    await expect(amount).toBeEnabled()
    await amount.fill('40.00')
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()

    await expect(page.getByText(/40\.00/).first()).toBeVisible({ timeout: 15_000 })
  })

  // The Edit dialog locks currency to the credit's currency, so editing an EUR
  // credit must parse the new amount under the EUR market locale too. Issue in
  // EUR, then edit to another comma-decimal value and confirm it round-trips.
  test('edits an EUR store credit with a localized amount', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-credit-eur-edit-${Date.now()}@example.com`
    await createCustomer(page, email)

    // Issue an EUR credit at 50,00 (€50.00).
    await page.getByRole('button', { name: /issue store credit/i }).click()
    await expect(page.getByRole('heading', { name: /issue store credit/i })).toBeVisible()
    await page.locator('#sc-currency').click()
    await page.getByRole('option', { name: /EUR/ }).click()
    await page.locator('#sc-amount').fill('50,00')
    await page.locator('#sc-memo').fill('E2E EUR credit to edit')
    await page.locator('#sc-category').click()
    await page.getByRole('option').first().click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^issue store credit$/i })
      .click()
    await expect(page.getByText(/€\s?50\.00/).first()).toBeVisible({ timeout: 15_000 })

    // Edit the amount to a comma-decimal 73,45 → must persist as €73.45.
    await page
      .getByRole('row', { name: /50\.00/ })
      .getByRole('button')
      .click()
    await page.getByRole('menuitem', { name: /^edit$/i }).click()
    await expect(page.getByRole('heading', { name: /edit store credit/i })).toBeVisible()

    const amount = page.locator('#edit-sc-amount')
    await expect(amount).toBeEnabled()
    await amount.fill('73,45')
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()

    await expect(page.getByText(/€\s?73\.45/).first()).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(/7,345/)).toHaveCount(0)
  })

  test('bulk-assigns selected customers to a group', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const emailA = `e2e-bulk-a-${suffix}@example.com`
    const emailB = `e2e-bulk-b-${suffix}@example.com`
    await createCustomer(page, emailA)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)
    await createCustomer(page, emailB)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    // Locate the two rows we just created and tick their checkboxes. The row
    // selection markup is `<input type="checkbox" aria-label="Select row">`
    // scoped to the row whose cell text contains the email.
    for (const email of [emailA, emailB]) {
      await page
        .locator('tr')
        .filter({ hasText: email })
        .getByRole('checkbox', { name: /select row/i })
        .check()
    }

    // The bulk action bar appears once any row is selected.
    await expect(page.getByText(/2 selected/i)).toBeVisible()
    await page.getByRole('button', { name: /add to group/i }).click()

    // Picker sheet opens — pick the seeded group, then confirm.
    await expect(page.getByRole('heading', { name: /add to groups/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByPlaceholder(/search customer groups/i)
      .fill(FIXTURE_PROMO_CUSTOMER_GROUP)
    await page
      .getByRole('option', { name: new RegExp(FIXTURE_PROMO_CUSTOMER_GROUP, 'i') })
      .first()
      .click()
    await page.getByRole('dialog').getByRole('button', { name: /^add$/i }).click()

    // After success, the toast confirms the count and the row chips render
    // the group name once the table refetches.
    await expect(page.getByText(/added 2 customers to groups/i)).toBeVisible({ timeout: 15_000 })

    // Visit /customers/groups WITHIN the QueryClient's staleTime window (60s).
    // If the bulk action didn't invalidate the groups cache, the stale
    // snapshot (showing 0 customers in the seeded group) would render here.
    // Regression guard for the TanStack Query cross-resource invalidation bug.
    await page.goto(`/${creds.store_id}/customers/groups`)
    const groupRow = page.locator('tr').filter({ hasText: FIXTURE_PROMO_CUSTOMER_GROUP })
    // The customers_count is column index 1 (0=name, 1=count, trailing kebab
    // doesn't count toward the data columns we care about). Poll until ≥ 2.
    await expect
      .poll(async () => Number((await groupRow.locator('td').nth(1).innerText()).trim()), {
        timeout: 15_000,
      })
      .toBeGreaterThanOrEqual(2)
  })

  test('bulk-adds tags to selected customers', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const emailA = `e2e-bulk-tag-a-${suffix}@example.com`
    const emailB = `e2e-bulk-tag-b-${suffix}@example.com`
    // Unique tag per run so the "already tagged" path doesn't surface on
    // a local re-run of the suite.
    const tagName = `e2e-bulk-${suffix}`

    await createCustomer(page, emailA)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)
    await createCustomer(page, emailB)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    for (const email of [emailA, emailB]) {
      await page
        .locator('tr')
        .filter({ hasText: email })
        .getByRole('checkbox', { name: /select row/i })
        .check()
    }

    await expect(page.getByText(/2 selected/i)).toBeVisible()
    await page.getByRole('button', { name: /^add tags…$/i }).click()
    await expect(page.getByRole('heading', { name: /^add tags$/i })).toBeVisible()

    // TagCombobox: type and press Enter to confirm the new tag as a chip,
    // then submit the dialog.
    const tagInput = page.getByRole('dialog').getByPlaceholder(/type to add tags/i)
    await tagInput.fill(tagName)
    await tagInput.press('Enter')
    await expect(page.getByRole('dialog').getByText(tagName)).toBeVisible()

    await page.getByRole('dialog').getByRole('button', { name: /^add$/i }).click()

    await expect(page.getByText(/added tags to 2 customers/i)).toBeVisible({ timeout: 15_000 })
  })

  // The detail page's Customer Groups card edits one customer's membership by
  // diffing the picked set against current membership. The group list is
  // preloaded (no typing required to discover it), mirroring the bulk dialog.
  test('assigns and removes a customer group from the detail page', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-detail-group-${Date.now()}@example.com`
    await createCustomer(page, email)

    // Open the Groups card editor. `<CardTitle>` is a `<div>`, so scope by its
    // text and click the Edit button under it (same idiom as the Profile card).
    const groupsCard = page.locator('div').filter({
      has: page.getByText('Customer groups', { exact: true }),
    })
    await groupsCard
      .getByRole('button', { name: /^edit$/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /^edit customer groups$/i })).toBeVisible()

    // The seeded group is preloaded — open the picker and select it without
    // having to type a query first.
    await page.getByPlaceholder(/search customer groups/i).click()
    await page
      .getByRole('option', { name: new RegExp(FIXTURE_PROMO_CUSTOMER_GROUP, 'i') })
      .first()
      .click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()

    // Back on the detail page, the card renders the group as a badge.
    await expect(page.getByText(FIXTURE_PROMO_CUSTOMER_GROUP, { exact: true })).toBeVisible({
      timeout: 15_000,
    })

    // Re-open and remove it. The selected group renders as a chip whose remove
    // affordance is an icon-only button (no accessible name), so scope to the
    // chip carrying the group name and click its remove control.
    await groupsCard
      .getByRole('button', { name: /^edit$/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /^edit customer groups$/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .locator('[data-slot="combobox-chip"]', { hasText: FIXTURE_PROMO_CUSTOMER_GROUP })
      .locator('[data-slot="combobox-chip-remove"]')
      .click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()

    await expect(page.getByText(/not in any groups/i)).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a customer', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-delete-${Date.now()}@example.com`
    await createCustomer(page, email)

    // PageHeader's more-actions dropdown holds the destructive Delete entry.
    await page.getByRole('button', { name: /more actions/i }).click()
    await page.getByRole('menuitem', { name: /delete customer/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /delete customer/i })
      .click()

    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/customers(?:\\?|$)`), {
      timeout: 15_000,
    })
    await expect(page.getByRole('link', { name: email })).toHaveCount(0, { timeout: 15_000 })
  })
})
