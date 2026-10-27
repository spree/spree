import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import { expect, type Page, test } from '@playwright/test'
import {
  adminRequest,
  createPlacedOrder,
  FIXTURE_BOGUS_GATEWAY,
  FIXTURE_BOGUS_ORDER_EMAIL,
  FIXTURE_BOGUS_TRANSACTION_ID,
  FIXTURE_PROMO_CUSTOMER_EMAIL,
  FIXTURE_PROMO_PRODUCT,
  FIXTURE_SPLIT_SKU,
  FIXTURE_SPLIT_WAREHOUSE,
  fillAddressForm,
  login,
} from './helpers'

// A PNG is in the PO document allowlist, so the shared fixture works and no
// new binary ships with the suite.
const FIXTURE_PO_DOCUMENT = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'fixtures/test-image.png',
)

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
    // The main column's plugin slot, filled by src/testing/slot-probes.tsx.
    await expect(page.getByText('Slot probe: order.form_main')).toBeVisible()
  })

  test('picking a market switches the currency and locale to that market', async ({ page }) => {
    const creds = await login(page)
    await page.goto(NEW_ORDER_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

    await page.locator('#order-market').click()
    await page.getByRole('option', { name: 'Europe' }).click()

    await expect(page.locator('#order-currency')).toContainText('EUR')
    await expect(page.locator('#order-currency')).toBeDisabled()
    await expect(page.locator('#order-locale')).toContainText('DE')
  })

  test('asks before a market change removes the picked items', async ({ page }) => {
    const creds = await login(page)
    await page.goto(NEW_ORDER_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

    await fillNewOrderForm(page, `e2e-context-${Date.now()}@example.com`)
    const itemRow = page.getByRole('cell', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
    await expect(itemRow).toBeVisible()

    await page.locator('#order-market').click()
    await page.getByRole('option', { name: 'Europe' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByRole('button', { name: /cancel/i }).click()
    await expect(itemRow).toBeVisible()
    await expect(page.locator('#order-currency')).not.toContainText('EUR')

    await page.locator('#order-market').click()
    await page.getByRole('option', { name: 'Europe' }).click()
    await dialog.getByRole('button', { name: /change and remove items/i }).click()
    await expect(itemRow).toBeHidden()
    await expect(page.locator('#order-currency')).toContainText('EUR')
  })

  // The motivating case for this form: a purchase order arrives by email and
  // the merchant keys the order in, reference and paperwork together.
  test('carries a PO number and its document onto the created order', async ({ page }) => {
    const creds = await login(page)
    await page.goto(NEW_ORDER_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

    const email = `e2e-po-${Date.now()}@example.com`
    const poNumber = `PO-${Date.now()}`
    await fillNewOrderForm(page, email)

    await page.locator('#po-number').fill(poNumber)
    await page.locator('input[type="file"]').setInputFiles(FIXTURE_PO_DOCUMENT)

    // Wait for the upload itself, not for the filename — the field shows the
    // name the moment the file is picked, while the signed id it saves does
    // not exist until the upload resolves. Submit is disabled meanwhile, so
    // the button coming back is the real signal.
    const submit = page.locator('button[type="submit"]')
    await expect(page.getByText(/uploading/i)).toBeHidden({ timeout: 30_000 })
    await expect(submit).toBeEnabled({ timeout: 30_000 })

    await submit.click()

    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/or_[^/]+$`), {
      timeout: 15_000,
    })

    const poCard = page
      .locator('[data-slot="card"]')
      .filter({ has: page.locator('[data-slot="card-title"]', { hasText: /^Purchase order$/ }) })
    await expect(poCard.getByText(poNumber)).toBeVisible({ timeout: 15_000 })
    await expect(poCard.getByRole('button', { name: /test-image\.png/i })).toBeVisible()
  })

  // A division buys for itself but ships to the sites it inherits, so the
  // picker offers its parent's address and the order keeps it.
  test("ships an order for a division to its parent company's address", async ({ page }) => {
    const creds = await login(page)
    const stamp = Date.now()
    const street = `${stamp} Harbor Road`
    const parent = await adminRequest<{ id: string }>(page, creds, 'post', '/companies', {
      name: `E2E Group ${stamp}`,
    })
    await adminRequest(page, creds, 'post', `/companies/${parent.id}/addresses`, {
      label: 'Headquarters',
      first_name: 'Dana',
      last_name: 'Reyes',
      address1: street,
      city: 'Los Angeles',
      postal_code: '90001',
      country_code: 'US',
      state_code: 'CA',
    })
    const divisionName = `E2E Group West ${stamp}`
    await adminRequest(page, creds, 'post', '/companies', {
      name: divisionName,
      kind: 'division',
      parent_id: parent.id,
    })

    await page.goto(NEW_ORDER_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })
    await page.getByPlaceholder(/search companies/i).fill(divisionName)
    await page
      .getByRole('option', { name: new RegExp(divisionName) })
      .first()
      .click()
    await fillNewOrderForm(page, `e2e-division-${stamp}@example.com`)

    await page.getByRole('switch').click()
    await page.locator('#order-shipping-address').click()
    await page.getByRole('option', { name: new RegExp(street) }).click()
    await expect(page.locator('#order-shipping-address')).toContainText(street)

    await page.locator('button[type="submit"]').click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/or_[^/]+$`), {
      timeout: 15_000,
    })
    await expect(page.getByText(street)).toBeVisible({ timeout: 15_000 })
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

  test('deletes a draft order from its actions menu', async ({ page }) => {
    const creds = await login(page)
    await page.goto(NEW_ORDER_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

    const email = `e2e-draft-delete-${Date.now()}@example.com`
    await fillNewOrderForm(page, email)
    await page.locator('button[type="submit"]').click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/or_[^/]+$`), {
      timeout: 15_000,
    })

    const heading = await page.getByRole('heading', { level: 1 }).first().textContent()
    const number = heading?.match(/R\d+/)?.[0] as string
    expect(number).toBeTruthy()

    await page.getByRole('button', { name: /more actions/i }).click()
    await expect(page.getByRole('menuitem', { name: /cancel order/i })).toHaveCount(0)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/drafts`), {
      timeout: 15_000,
    })
    // Wait for the list itself before reading absence, so an empty page mid-load
    // cannot pass for a deleted draft.
    await expect(page.getByRole('link', { name: CTA })).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(`#${number}`)).toHaveCount(0)
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

  // Draft orders take a negotiated unit price: editing it stamps the line
  // manual server-side, and coming back to the form shows the marker with
  // the reset-to-catalog action beside it.
  test('sets a negotiated unit price on a draft order line', async ({ page }) => {
    const creds = await login(page)
    await page.goto(NEW_ORDER_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

    await fillNewOrderForm(page, `e2e-order-price-${Date.now()}@example.com`)
    await page.locator('button[type="submit"]').click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/or_[^/]+$`), {
      timeout: 15_000,
    })

    const orderUrl = page.url()
    await page.goto(`${orderUrl}/edit`)
    await expect(page.getByRole('heading', { name: /edit order/i })).toBeVisible({
      timeout: 15_000,
    })

    const price = page.getByLabel(/unit price for/i).first()
    await expect(price).toBeVisible({ timeout: 15_000 })
    await price.fill('7.20')

    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page).toHaveURL(orderUrl, { timeout: 15_000 })

    await page.goto(`${orderUrl}/edit`)
    await expect(page.getByLabel(/unit price for/i).first()).toHaveValue(/^7\.20?$/, {
      timeout: 15_000,
    })
    await expect(page.getByText(/^negotiated$/i)).toBeVisible()
    await expect(page.getByRole('button', { name: /reset .* to catalog price/i })).toBeVisible()
  })

  // A unit that neither the shipped parcel nor the open one can carry goes
  // out in a parcel of its own, and what already shipped stays as it was.
  test('ships a unit added to a partly shipped order in a new parcel', async ({ page }) => {
    const creds = await login(page)
    const order = await createPlacedOrder(page, creds.accessToken, {
      quantity: 1,
      ship: false,
      extraSkus: [FIXTURE_SPLIT_SKU],
    })

    const locations = await adminRequest<{ data: { id: string }[] }>(
      page,
      creds,
      'get',
      `/stock_locations?q[name_eq]=${encodeURIComponent(FIXTURE_SPLIT_WAREHOUSE)}`,
    )
    const fulfillments = await adminRequest<{ data: { id: string; stock_location_id: string }[] }>(
      page,
      creds,
      'get',
      `/orders/${order.id}/fulfillments`,
    )
    expect(fulfillments.data).toHaveLength(2)
    const promoParcel = fulfillments.data.find(
      (fulfillment) => fulfillment.stock_location_id !== locations.data[0].id,
    )
    await adminRequest(
      page,
      creds,
      'patch',
      `/orders/${order.id}/fulfillments/${promoParcel?.id}/fulfill`,
    )

    const orderUrl = `/${creds.store_id}/orders/${order.id}`
    await page.goto(`${orderUrl}/edit`)
    await expect(page.getByRole('heading', { name: /edit order/i })).toBeVisible({
      timeout: 15_000,
    })

    await page.getByLabel(`Quantity of ${FIXTURE_PROMO_PRODUCT}`).fill('2')
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page).toHaveURL(new RegExp(`${orderUrl}$`), { timeout: 15_000 })

    await expect(page.getByText(/^unfulfilled$/i)).toHaveCount(2, { timeout: 15_000 })
    await expect(page.getByText(/^fulfilled$/i)).toHaveCount(1)
    await expect(page.getByText(FIXTURE_SPLIT_WAREHOUSE)).toBeVisible()
  })
})

test.describe('order addresses', () => {
  // Regression: the dashboard sent `shipping_address` while the API permitted
  // only `ship_address`, so the request succeeded and the address never
  // changed. Asserting on the rendered card is what catches that — the
  // mutation itself resolved happily throughout.
  test('saves an edited shipping address onto the order', async ({ page }) => {
    const creds = await login(page)
    await page.goto(NEW_ORDER_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

    await fillNewOrderForm(page, `e2e-order-address-${Date.now()}@example.com`)
    await page.locator('button[type="submit"]').click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/or_[^/]+$`), {
      timeout: 15_000,
    })

    await page.getByRole('button', { name: /edit shipping address/i }).click()

    // Named, because the country and state comboboxes inside the sheet are
    // themselves dialogs.
    const dialog = page.getByRole('dialog', { name: /edit shipping address/i })
    await expect(dialog).toBeVisible({ timeout: 15_000 })

    const street = `${Date.now()} Vine Street`
    await fillAddressForm(page, {
      firstName: 'Ada',
      lastName: 'Lovelace',
      address1: street,
      city: 'Brooklyn',
      postalCode: '11201',
      phone: '555-0142',
      country: 'United States',
      state: 'New York',
    })

    await dialog.getByRole('button', { name: /^save$/i }).click()

    await expect(dialog).toBeHidden({ timeout: 15_000 })
    await expect(page.getByText(street)).toBeVisible({ timeout: 15_000 })
  })

  test('uses the shipping address for billing', async ({ page }) => {
    const creds = await login(page)
    const street = `${Date.now()} Paryska Street`
    const order = await adminRequest<{ id: string }>(page, creds, 'post', '/orders', {
      email: `e2e-order-same-address-${Date.now()}@example.com`,
      shipping_address: {
        first_name: 'Ada',
        last_name: 'Lovelace',
        address1: street,
        city: 'Los Angeles',
        country_code: 'US',
        state_code: 'CA',
        postal_code: '90001',
        phone: '5555555555',
      },
    })

    await page.goto(`${ORDERS_PATH(creds.store_id)}/${order.id}`)
    const sameAsShipping = page.getByRole('button', { name: /same as shipping address/i })
    await expect(sameAsShipping).toBeVisible({ timeout: 15_000 })
    await sameAsShipping.click()

    await expect(sameAsShipping).toBeHidden({ timeout: 15_000 })
    await expect(page.getByText(/^same as shipping address$/i)).toBeVisible()
    await expect(page.getByText(street)).toHaveCount(1)
  })
})

test.describe('order customer', () => {
  test("changes a guest order's email", async ({ page }) => {
    const creds = await login(page)
    const order = await adminRequest<{ id: string }>(page, creds, 'post', '/orders', {
      email: `e2e-guest-${Date.now()}@example.com`,
    })
    const newEmail = `e2e-guest-renamed-${Date.now()}@example.com`

    await page.goto(`${ORDERS_PATH(creds.store_id)}/${order.id}`)
    await page.getByRole('button', { name: /edit customer/i }).click()
    const dialog = page.getByRole('dialog', { name: /edit customer/i })
    await dialog.getByLabel(/email/i).fill(newEmail)
    await dialog.getByRole('button', { name: /^save$/i }).click()

    await expect(dialog).toBeHidden({ timeout: 15_000 })
    await expect(page.getByText(newEmail)).toBeVisible({ timeout: 15_000 })
  })

  test('detaches the customer, leaving a guest order', async ({ page }) => {
    const creds = await login(page)
    const customers = await adminRequest<{ data: { id: string }[] }>(
      page,
      creds,
      'get',
      `/customers?q[email_eq]=${encodeURIComponent(FIXTURE_PROMO_CUSTOMER_EMAIL)}`,
    )
    const order = await adminRequest<{ id: string }>(page, creds, 'post', '/orders', {
      customer_id: customers.data[0].id,
    })

    await page.goto(`${ORDERS_PATH(creds.store_id)}/${order.id}`)
    const customerLink = page.getByRole('link', { name: 'Promo Customer', exact: true })
    await expect(customerLink).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /edit customer/i }).click()
    const dialog = page.getByRole('dialog', { name: /edit customer/i })
    await dialog.locator('[data-slot="combobox-clear"]').click()
    await expect(dialog.getByLabel(/email/i)).toHaveValue(FIXTURE_PROMO_CUSTOMER_EMAIL)
    await dialog.getByRole('button', { name: /^save$/i }).click()

    await expect(dialog).toBeHidden({ timeout: 15_000 })
    await expect(customerLink).toBeHidden({ timeout: 15_000 })
    await expect(page.getByText(FIXTURE_PROMO_CUSTOMER_EMAIL)).toBeVisible()
  })

  test('asks before removing the customer from a placed order', async ({ page }) => {
    const creds = await login(page)
    const order = await createPlacedOrder(page, creds.accessToken, { quantity: 1, ship: false })

    await page.goto(`${ORDERS_PATH(creds.store_id)}/${order.id}`)
    const customerLink = page.getByRole('link', { name: 'Promo Customer', exact: true })
    await expect(customerLink).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /edit customer/i }).click()
    const dialog = page.getByRole('dialog', { name: /edit customer/i })
    await dialog.locator('[data-slot="combobox-clear"]').click()
    await dialog.getByRole('button', { name: /^save$/i }).click()

    await page.getByRole('button', { name: /^remove customer$/i }).click()

    await expect(dialog).toBeHidden({ timeout: 15_000 })
    await expect(customerLink).toBeHidden({ timeout: 15_000 })
  })
})

test.describe('order tags', () => {
  async function createDraft(page: Page, storeId: string, email: string) {
    await page.goto(NEW_ORDER_PATH(storeId))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })
    await fillNewOrderForm(page, email)
    await page.locator('button[type="submit"]').click()
    await expect(page).toHaveURL(new RegExp(`/${storeId}/orders/or_[^/]+$`), { timeout: 15_000 })
  }

  function tagsCard(page: Page) {
    return page
      .locator('[data-slot="card"]')
      .filter({ has: page.locator('[data-slot="card-title"]', { hasText: /^tags$/i }) })
  }

  // The order tag vocabulary is fetched by its short name (`order`); a tag
  // saved on one order is offered as an existing tag on the next.
  test('tags an order and offers the tag on another order', async ({ page }) => {
    const creds = await login(page)
    const suffix = Date.now()
    const tagName = `e2e-order-tag-${suffix}`

    await createDraft(page, creds.store_id, `e2e-order-tag-a-${suffix}@example.com`)
    await tagsCard(page)
      .getByRole('button', { name: /^edit$/i })
      .click()
    const input = tagsCard(page).getByPlaceholder(/type to add tags/i)
    await input.fill(tagName)
    await input.press('Enter')
    await tagsCard(page)
      .getByRole('button', { name: /^save$/i })
      .click()
    await expect(tagsCard(page).getByText(tagName, { exact: true })).toBeVisible({
      timeout: 15_000,
    })
    await expect(tagsCard(page).getByPlaceholder(/type to add tags/i)).toHaveCount(0)

    await createDraft(page, creds.store_id, `e2e-order-tag-b-${suffix}@example.com`)
    await tagsCard(page)
      .getByRole('button', { name: /^edit$/i })
      .click()
    await tagsCard(page)
      .getByPlaceholder(/type to add tags/i)
      .fill(tagName)
    await expect(page.getByRole('option', { name: tagName, exact: true })).toBeVisible({
      timeout: 15_000,
    })
  })
})

test.describe('order payments', () => {
  test("links a card payment to its page at the gateway's dashboard", async ({ page }) => {
    const creds = await login(page)
    const orders = await adminRequest<{ data: { id: string }[] }>(
      page,
      { ...creds, store_id: creds.comma_store_id },
      'get',
      `/orders?q[email_eq]=${encodeURIComponent(FIXTURE_BOGUS_ORDER_EMAIL)}`,
    )
    await page.goto(`/${creds.comma_store_id}/orders/${orders.data[0].id}`)

    await page
      .locator('tr')
      .filter({ hasText: FIXTURE_BOGUS_GATEWAY })
      .getByRole('button', { name: /^actions$/i })
      .click({ timeout: 15_000 })

    const link = page.getByRole('menuitem', { name: `View at ${FIXTURE_BOGUS_GATEWAY}` })
    await expect(link).toHaveAttribute(
      'href',
      `https://dashboard.bogus.example/payments/${FIXTURE_BOGUS_TRANSACTION_ID}`,
    )
    await expect(link).toHaveAttribute('target', '_blank')
  })

  test("shows a card payment's checks and captures", async ({ page }) => {
    const creds = await login(page)
    const orders = await adminRequest<{ data: { id: string }[] }>(
      page,
      { ...creds, store_id: creds.comma_store_id },
      'get',
      `/orders?q[email_eq]=${encodeURIComponent(FIXTURE_BOGUS_ORDER_EMAIL)}`,
    )
    await page.goto(`/${creds.comma_store_id}/orders/${orders.data[0].id}`)

    const row = page.locator('tr').filter({ hasText: FIXTURE_BOGUS_GATEWAY })
    await expect(row.getByText('Failed card checks')).toBeVisible({ timeout: 15_000 })

    await row.getByRole('button', { name: /^actions$/i }).click()
    await page.getByRole('menuitem', { name: 'View details' }).click()

    const dialog = page.getByRole('dialog')
    await expect(dialog.getByText(FIXTURE_BOGUS_TRANSACTION_ID)).toBeVisible()
    await expect(dialog.getByText('Did not pass')).toHaveCount(2)
    await expect(dialog.getByText('CVV does not match')).toBeVisible()
    await expect(dialog.getByRole('row').filter({ hasText: '€10.00' })).toBeVisible()
  })
})
