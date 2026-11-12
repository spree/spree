import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import { expect, type Page, test } from '@playwright/test'
import {
  addNewOrderItem,
  adminRequest,
  createPlacedOrder,
  deleteSeededRecords,
  type E2ELoginSession,
  FIXTURE_BOGUS_GATEWAY,
  FIXTURE_BOGUS_ORDER_EMAIL,
  FIXTURE_BOGUS_TRANSACTION_ID,
  FIXTURE_PROMO_CUSTOMER_EMAIL,
  FIXTURE_PROMO_PRODUCT,
  fillAddressForm,
  login,
  section,
  seedRecord,
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

  test('filters by a date range picked on the calendar', async ({ page }) => {
    const creds = await login(page)
    await gotoOrdersIndex(page, ORDERS_PATH(creds.store_id))
    const trigger = page.getByRole('button', { name: /^date/i })

    // A preset applies at once and shows as the trigger's value.
    await trigger.click()
    await page.getByRole('button', { name: /^last 30 days$/i }).click()
    await expect(trigger).toContainText(/last 30 days/i)

    // A range picked last month leaves out every order placed by this run.
    await trigger.click()
    const lastMonth = page.getByRole('grid').first()
    await lastMonth.getByRole('button', { name: /\b10(st|nd|rd|th)\b/ }).click()
    // The second day completes the range and applies it, like a preset.
    await lastMonth.getByRole('button', { name: /\b12(st|nd|rd|th)\b/ }).click()
    await expect(trigger).toContainText(/10 – \w+ 12/)
    await expect(page.getByText(/no orders found/i)).toBeVisible({ timeout: 15_000 })

    await trigger.click()
    await page.getByRole('button', { name: /^any date$/i }).click()
    await expect(trigger).toContainText(/any date/i)
    await expect(page.getByText(/no orders found/i)).toBeHidden({ timeout: 15_000 })
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

  await addNewOrderItem(page, FIXTURE_PROMO_PRODUCT)
}

test.describe('new order', () => {
  test('lists items like the edit screen, from an empty state', async ({ page }) => {
    const creds = await login(page)
    await page.goto(NEW_ORDER_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

    await expect(page.getByText(/^no items yet$/i)).toBeVisible()

    await addNewOrderItem(page, FIXTURE_PROMO_PRODUCT)

    const quantity = page.getByRole('spinbutton', {
      name: new RegExp(`^quantity of ${FIXTURE_PROMO_PRODUCT}`, 'i'),
    })
    await expect(quantity).toHaveValue('1')
    // Picking the same product again adds to its row rather than a second one.
    await addNewOrderItem(page, FIXTURE_PROMO_PRODUCT)
    await expect(quantity).toHaveValue('2')

    await page
      .getByRole('button', { name: new RegExp(`^remove ${FIXTURE_PROMO_PRODUCT}`, 'i') })
      .click()
    await expect(page.getByText(/^no items yet$/i)).toBeVisible()
  })

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
    // Anchored: the quantity and remove cells name the product too.
    const itemRow = page.getByRole('cell', { name: new RegExp(`^${FIXTURE_PROMO_PRODUCT}`, 'i') })
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

  // The save replaces the lines when it finishes, so a variant picked during
  // it would be dropped without a word: Mod+S does nothing while the product
  // picker is open.
  test('does not save from the keyboard while the product picker is open', async ({ page }) => {
    const creds = await login(page)
    await page.goto(NEW_ORDER_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: CTA })).toBeVisible({ timeout: 15_000 })

    await fillNewOrderForm(page, `e2e-order-picker-${Date.now()}@example.com`)
    await page.locator('button[type="submit"]').click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders/or_[^/]+$`), {
      timeout: 15_000,
    })

    const editUrl = `${page.url()}/edit`
    await page.goto(editUrl)
    await expect(page.getByRole('heading', { name: /edit order/i })).toBeVisible({
      timeout: 15_000,
    })

    // A dirty form is what the shortcut would otherwise save.
    const quantity = page.locator('input[type="number"]').first()
    await expect(quantity).toBeVisible({ timeout: 15_000 })
    await quantity.fill('2')

    await page.getByRole('button', { name: /^add product$/i }).click()
    const picker = page.getByRole('dialog', { name: /add line item/i })
    await expect(picker).toBeVisible()

    const updates: string[] = []
    page.on('request', (request) => {
      if (request.method() === 'PATCH' && /\/orders\/or_[^/]+$/.test(request.url())) {
        updates.push(request.url())
      }
    })
    await page.keyboard.press('ControlOrMeta+s')

    // Give a save that should not happen the time it would need to be sent.
    await page.waitForTimeout(1_000)
    expect(updates).toEqual([])
    await expect(picker).toBeVisible()
    await expect(page).toHaveURL(editUrl)
  })
})

// A draft order of 2 × 24.50 and 1 × 18.00 (67.00), on products of its own
// so the names are unique in the order view.
async function seedTwoLineDraftOrder(page: Page, session: E2ELoginSession) {
  const locations = await adminRequest<{ data: { id: string }[] }>(
    page,
    session,
    'get',
    '/stock_locations',
  )
  // A draft order only takes products its channel sells.
  const channels = await adminRequest<{ data: { id: string; default: boolean }[] }>(
    page,
    session,
    'get',
    '/channels',
  )
  const channelId = channels.data.find((channel) => channel.default)?.id
  const stamp = Date.now()
  const lines = [
    { name: `Kept line ${stamp}`, sku: `E2E-KEPT-${stamp}`, amount: '24.50', quantity: 2 },
    { name: `Removed line ${stamp}`, sku: `E2E-REMOVED-${stamp}`, amount: '18.00', quantity: 1 },
  ]

  const items = []
  for (const line of lines) {
    await seedRecord(page, session, '/products', {
      name: line.name,
      status: 'active',
      prices: [{ amount: line.amount, currency: 'USD' }],
      product_publications: [{ channel_id: channelId }],
      variants: [
        {
          options: [],
          sku: line.sku,
          track_inventory: true,
          stock_levels: [{ stock_location_id: locations.data[0].id, count_on_hand: 10 }],
        },
      ],
    })
    const variants = await adminRequest<{ data: { id: string }[] }>(
      page,
      session,
      'get',
      `/variants?q[sku_eq]=${line.sku}`,
    )
    items.push({ variant_id: variants.data[0].id, quantity: line.quantity })
  }

  const order = await adminRequest<{ id: string }>(page, session, 'post', '/orders', {
    email: `e2e-remove-line-${stamp}@example.com`,
    items,
  })
  return { orderId: order.id, kept: lines[0].name, removed: lines[1].name }
}

// The order the merchant opens must add up to the lines that are left.
async function expectOnlyKeptLine(page: Page, kept: string, removed: string) {
  await expect(page.getByText(kept)).toBeVisible({ timeout: 15_000 })
  await expect(page.getByText(removed)).toHaveCount(0)

  const summary = section(page, /^summary$/i)
  await expect(summary.getByText(/^subtotal$/i).locator('..')).toContainText('$49.00')
  await expect(summary.getByText(/^total$/i).locator('..')).toContainText('$49.00')
}

test.describe('removing a draft order line', () => {
  test.afterEach(async ({ page }) => deleteSeededRecords(page))

  test('from the edit screen leaves the totals of the lines that are left', async ({ page }) => {
    const session = await login(page)
    const { orderId, kept, removed } = await seedTwoLineDraftOrder(page, session)

    const orderUrl = `/${session.store_id}/orders/${orderId}`
    await page.goto(`${orderUrl}/edit`)
    await expect(page.getByRole('heading', { name: /edit order/i })).toBeVisible({
      timeout: 15_000,
    })

    await page.getByRole('button', { name: `Remove ${removed}` }).click()
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page).toHaveURL(new RegExp(`${orderUrl}$`), { timeout: 15_000 })

    await expectOnlyKeptLine(page, kept, removed)
  })

  // Connected agents and API clients remove a line on its own, through the
  // item endpoint the dashboard does not use.
  test('through the Admin API leaves the totals of the lines that are left', async ({ page }) => {
    const session = await login(page)
    const { orderId, kept, removed } = await seedTwoLineDraftOrder(page, session)

    const items = await adminRequest<{ data: { id: string; name: string }[] }>(
      page,
      session,
      'get',
      `/orders/${orderId}/items`,
    )
    const line = items.data.find((item) => item.name === removed)
    expect(line, 'the 18.00 line').toBeTruthy()
    await adminRequest(page, session, 'delete', `/orders/${orderId}/items/${line?.id}`)

    await page.goto(`/${session.store_id}/orders/${orderId}`)
    await expectOnlyKeptLine(page, kept, removed)
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
    const editor = page.getByRole('form', { name: /edit customer/i })
    await editor.getByLabel(/email/i).fill(newEmail)
    await editor.getByRole('button', { name: /^save$/i }).click()

    await expect(editor).toBeHidden({ timeout: 15_000 })
    await expect(page.getByText(newEmail)).toBeVisible({ timeout: 15_000 })
  })

  test('lists customers by name and adds a new one from the picker', async ({ page }) => {
    const creds = await login(page)
    const order = await adminRequest<{ id: string }>(page, creds, 'post', '/orders', {
      email: `e2e-guest-${Date.now()}@example.com`,
    })
    const stamp = Date.now()
    const email = `e2e-new-customer-${stamp}@example.com`

    await page.goto(`${ORDERS_PATH(creds.store_id)}/${order.id}`)
    await page.getByRole('button', { name: /edit customer/i }).click()
    const editor = page.getByRole('form', { name: /edit customer/i })
    const picker = editor.locator('#order-customer-picker')

    // Existing customers read by name, with the email under it.
    await picker.fill('Promo')
    const promo = page.getByRole('option').filter({ hasText: 'Promo Customer' })
    await expect(promo).toBeVisible({ timeout: 15_000 })
    await expect(promo).toContainText(FIXTURE_PROMO_CUSTOMER_EMAIL)

    // One not on file is created from the picker and chosen straight away.
    await page.getByRole('button', { name: /^add new customer$/i }).click()
    const sheet = page.getByRole('dialog', { name: /new customer/i })
    await sheet.getByLabel(/^email$/i).fill(email)
    await sheet.getByLabel(/^first name$/i).fill('Ada')
    await sheet.getByLabel(/^last name$/i).fill(`Picker ${stamp}`)
    await sheet.getByRole('button', { name: /^create customer$/i }).click()
    await expect(sheet).toBeHidden({ timeout: 15_000 })
    await expect(picker).toHaveValue(`Ada Picker ${stamp}`)

    await editor.getByRole('button', { name: /^save$/i }).click()
    await expect(editor).toBeHidden({ timeout: 15_000 })
    await expect(page.getByRole('link', { name: `Ada Picker ${stamp}`, exact: true })).toBeVisible({
      timeout: 15_000,
    })
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
    const editor = page.getByRole('form', { name: /edit customer/i })
    await editor.locator('[data-slot="combobox-clear"]').click()
    await expect(editor.getByLabel(/email/i)).toHaveValue(FIXTURE_PROMO_CUSTOMER_EMAIL)
    await editor.getByRole('button', { name: /^save$/i }).click()

    await expect(editor).toBeHidden({ timeout: 15_000 })
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
    const editor = page.getByRole('form', { name: /edit customer/i })
    await editor.locator('[data-slot="combobox-clear"]').click()
    await editor.getByRole('button', { name: /^save$/i }).click()

    await page.getByRole('button', { name: /^remove customer$/i }).click()

    await expect(editor).toBeHidden({ timeout: 15_000 })
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

  test('offers capturing an authorized payment from the order header', async ({ page }) => {
    const creds = await login(page)
    const orders = await adminRequest<{ data: { id: string }[] }>(
      page,
      { ...creds, store_id: creds.comma_store_id },
      'get',
      `/orders?q[email_eq]=${encodeURIComponent(FIXTURE_BOGUS_ORDER_EMAIL)}`,
    )
    const orderId = orders.data[0].id

    // Capturing for real would change the fixture other specs read, so the
    // order payload reports one payment still waiting to be captured.
    await page.route(`**/api/v3/admin/orders/${orderId}**`, async (route) => {
      const url = new URL(route.request().url())
      if (route.request().method() !== 'GET' || !url.pathname.endsWith(`/orders/${orderId}`)) {
        return route.fallback()
      }
      const response = await route.fetch()
      const order = await response.json()
      order.payments = order.payments
        .slice(0, 1)
        .map((payment: object) => ({ ...payment, status: 'pending', can_capture: true }))
      await route.fulfill({ response, json: order })
    })

    await page.goto(`/${creds.comma_store_id}/orders/${orderId}`)

    // The payment row names the hold the way the order's status does.
    const row = page.locator('tr').filter({ hasText: FIXTURE_BOGUS_GATEWAY })
    await expect(row.getByText('Authorized')).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /^capture .*10\.00/i }).click()
    const dialog = page.getByRole('alertdialog').or(page.getByRole('dialog'))
    await expect(dialog.getByText('Capture this payment?')).toBeVisible()
    await page.keyboard.press('Escape')
    await expect(dialog).toBeHidden()
  })

  test('offers Void on a payment the gateway can void', async ({ page }) => {
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

    await expect(page.getByRole('menuitem', { name: 'Void' })).toBeVisible()
  })

  test('hides Void when the gateway cannot void the payment', async ({ page }) => {
    const creds = await login(page)
    const orders = await adminRequest<{ data: { id: string }[] }>(
      page,
      { ...creds, store_id: creds.comma_store_id },
      'get',
      `/orders?q[email_eq]=${encodeURIComponent(FIXTURE_BOGUS_ORDER_EMAIL)}`,
    )
    const orderId = orders.data[0].id

    // The fixture gateway can void, so the order payload reports a gateway
    // that cannot (as Stripe does for a captured payment).
    await page.route(`**/api/v3/admin/orders/${orderId}**`, async (route) => {
      const url = new URL(route.request().url())
      if (route.request().method() !== 'GET' || !url.pathname.endsWith(`/orders/${orderId}`)) {
        return route.fallback()
      }
      const response = await route.fetch()
      const order = await response.json()
      order.payments = order.payments.map((payment: object) => ({ ...payment, can_void: false }))
      await route.fulfill({ response, json: order })
    })

    await page.goto(`/${creds.comma_store_id}/orders/${orderId}`)

    await page
      .locator('tr')
      .filter({ hasText: FIXTURE_BOGUS_GATEWAY })
      .getByRole('button', { name: /^actions$/i })
      .click({ timeout: 15_000 })

    await expect(page.getByRole('menuitem', { name: 'View details' })).toBeVisible()
    await expect(page.getByRole('menuitem', { name: 'Void' })).toHaveCount(0)
  })
})
