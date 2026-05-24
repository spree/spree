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
    // The count is the last <td> in the row. Poll until it reads ≥ 2.
    await expect
      .poll(async () => Number((await groupRow.locator('td').last().innerText()).trim()), {
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
