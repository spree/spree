import { expect, type Page, test } from '@playwright/test'
import { FIXTURE_PROMO_PRODUCT, login } from './helpers'

const ORDERS_PATH = (storeId: string) => `/${storeId}/orders`
const DRAFTS_PATH = (storeId: string) => `/${storeId}/orders/drafts`
const NEW_ORDER_PATH = (storeId: string) => `/${storeId}/orders/new`
const CTA = /new order/i

// Both orders/ and orders/drafts wrap the CTA in <Button asChild><Link/></Button>,
// so the rendered DOM element is an <a> — getByRole('link') matches it.
async function gotoOrdersIndex(page: Page, path: string) {
  await page.goto(path)
  await expect(page.getByRole('link', { name: CTA })).toBeVisible({ timeout: 15_000 })
}

test.describe('orders', () => {
  test('lists completed orders with the New Order CTA', async ({ page }) => {
    const creds = await login(page)
    await gotoOrdersIndex(page, ORDERS_PATH(creds.store_id))
  })

  test('New Order CTA on the orders list navigates to the new-order page', async ({ page }) => {
    const creds = await login(page)
    await gotoOrdersIndex(page, ORDERS_PATH(creds.store_id))

    await page.getByRole('link', { name: CTA }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/new$`), { timeout: 15_000 })
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible()
  })
})

test.describe('draft orders', () => {
  test('lists drafts with the New Order CTA', async ({ page }) => {
    const creds = await login(page)
    await gotoOrdersIndex(page, DRAFTS_PATH(creds.store_id))
  })

  // Regression: the drafts page rendered the CTA as a bare <Button> with no
  // <Link>, so clicking did nothing. Confirms the navigation now matches the
  // completed-orders list.
  test('New Order CTA on the drafts list navigates to the new-order page', async ({ page }) => {
    const creds = await login(page)
    await gotoOrdersIndex(page, DRAFTS_PATH(creds.store_id))

    await page.getByRole('link', { name: CTA }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/new$`), { timeout: 15_000 })
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible()
  })
})

async function fillNewOrderForm(page: Page, email: string) {
  // Skip the customer combobox and use the email-only path — the form
  // accepts either, and an email-only payload is the minimum the backend
  // service needs (no addresses required for a draft).
  await page.locator('#order-email').fill(email)

  // Variant typeahead is a combobox: results are `role="option"`, so they are
  // reachable by keyboard as well as click.
  await page.getByPlaceholder(/search variant/i).fill(FIXTURE_PROMO_PRODUCT)
  await page
    .getByRole('option', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
    .first()
    .click()
}

test.describe('new order', () => {
  test('creates a draft order with email + variant and lands on the detail page', async ({
    page,
  }) => {
    const creds = await login(page)
    await page.goto(NEW_ORDER_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

    const email = `e2e-order-${Date.now()}@example.com`
    await fillNewOrderForm(page, email)

    // Submit button shares the "New Order" label with the back-button on the
    // sidebar; scope by type=submit so the locator is unambiguous.
    await page.locator('button[type="submit"]').click()

    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/or_[^/]+$`), {
      timeout: 15_000,
    })
  })

  test('newly-created draft shows up in the drafts list', async ({ page }) => {
    const creds = await login(page)
    await page.goto(NEW_ORDER_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

    const email = `e2e-drafts-${Date.now()}@example.com`
    await fillNewOrderForm(page, email)
    await page.locator('button[type="submit"]').click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/or_[^/]+$`), {
      timeout: 15_000,
    })

    // Pull the order number from the H1 (PageHeader renders it as a top-level
    // heading on the order detail page) so we can find the matching row.
    const heading = await page.getByRole('heading', { level: 1 }).first().textContent()
    const numberMatch = heading?.match(/R\d+/)
    expect(numberMatch).toBeTruthy()
    const number = numberMatch?.[0] as string

    await page.goto(DRAFTS_PATH(creds.store_id))
    await expect(page.getByText(`#${number}`)).toBeVisible({ timeout: 15_000 })
  })
})

test.describe('order editing', () => {
  // Editing is a detour from the order, so saving hands the merchant back the
  // view that shows what the edit did rather than leaving them on the form.
  test('returns to the order view after saving', async ({ page }) => {
    const creds = await login(page)
    await page.goto(NEW_ORDER_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

    await fillNewOrderForm(page, `e2e-order-edit-${Date.now()}@example.com`)
    await page.locator('button[type="submit"]').click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/or_[^/]+$`), {
      timeout: 15_000,
    })

    const orderUrl = page.url()
    await page.goto(`${orderUrl}/edit`)
    await expect(page.getByRole('heading', { name: /edit order/i })).toBeVisible({
      timeout: 15_000,
    })

    // Changing a quantity is the smallest edit that dirties the form.
    const quantity = page.locator('input[type="number"]').first()
    await expect(quantity).toBeVisible({ timeout: 15_000 })
    await quantity.fill('2')

    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page).toHaveURL(orderUrl, { timeout: 15_000 })
  })
})
