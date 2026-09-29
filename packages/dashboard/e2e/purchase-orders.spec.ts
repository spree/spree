import { expect, type Page, test } from '@playwright/test'
import {
  FIXTURE_SUPPLIER,
  FIXTURE_TRANSFER_DESTINATION,
  FIXTURE_TRANSFER_PRODUCT,
  FIXTURE_TRANSFER_SKU,
  gotoIndex,
  login,
  openRowMenu,
} from './helpers'

const PURCHASE_ORDERS_PATH = (storeId: string) => `/${storeId}/purchase-orders`
const CTA = /new purchase order/i

/**
 * Raises a purchase order through the API, optionally placed with the
 * supplier. The form has its own test; the rest of the order's life is what
 * the others exercise.
 */
async function createPurchaseOrder(
  page: Page,
  accessToken: string,
  { quantity, ordered = false }: { quantity: number; ordered?: boolean },
) {
  const headers = { Authorization: `Bearer ${accessToken}` }

  const suppliers = await page.request
    .get('/api/v3/admin/suppliers', { headers, params: { 'q[name_eq]': FIXTURE_SUPPLIER } })
    .then((res) => res.json())
  const locations = await page.request
    .get('/api/v3/admin/stock_locations', { headers, params: { limit: 100 } })
    .then((res) => res.json())
  const destination = locations.data.find(
    (location: { name: string }) => location.name === FIXTURE_TRANSFER_DESTINATION,
  )
  const variants = await page.request
    .get('/api/v3/admin/variants', { headers, params: { 'q[sku_eq]': FIXTURE_TRANSFER_SKU } })
    .then((res) => res.json())

  const created = await page.request.post('/api/v3/admin/purchase_orders', {
    headers,
    data: {
      supplier_id: suppliers.data[0].id,
      destination_location_id: destination.id,
      currency: 'USD',
      reference: `E2E PO ${Date.now()}`,
      items: [{ variant_id: variants.data[0].id, quantity_ordered: quantity, unit_cost: 7.5 }],
    },
  })
  expect(created.status(), await created.text()).toBe(201)
  const purchaseOrder = (await created.json()) as { id: string; number: string }

  if (ordered) {
    const placed = await page.request.patch(
      `/api/v3/admin/purchase_orders/${purchaseOrder.id}/mark_ordered`,
      { headers },
    )
    expect(placed.status(), await placed.text()).toBe(200)
  }

  return purchaseOrder
}

async function openPurchaseOrder(
  page: Page,
  storeId: string,
  purchaseOrder: { id: string; number: string },
) {
  await page.goto(`${PURCHASE_ORDERS_PATH(storeId)}/${purchaseOrder.id}`)
  await expect(page.getByRole('heading', { name: purchaseOrder.number })).toBeVisible({
    timeout: 15_000,
  })
}

test.describe('purchase orders', () => {
  test('raises a draft from the form and places it with the supplier', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PURCHASE_ORDERS_PATH(creds.store_id), CTA)
    await page.getByRole('button', { name: CTA }).click()
    await expect(page.getByRole('heading', { name: /new purchase order/i })).toBeVisible()

    await page.locator('#supplier').fill(FIXTURE_SUPPLIER)
    await page.getByRole('option', { name: FIXTURE_SUPPLIER }).click()
    await page.locator('#destination').click()
    await page.getByRole('option', { name: FIXTURE_TRANSFER_DESTINATION }).click()

    await page
      .getByRole('button', { name: /add a product/i })
      .first()
      .click()
    const picker = page.getByRole('dialog')
    await picker.getByRole('searchbox').fill(FIXTURE_TRANSFER_SKU)
    await picker.getByRole('button', { name: new RegExp(FIXTURE_TRANSFER_PRODUCT) }).click()
    await picker.getByRole('button', { name: /^add 1$/i }).click()
    await expect(picker).toBeHidden()
    await page.getByRole('spinbutton', { name: /^ordered$/i }).fill('12')

    await page.getByRole('button', { name: /create draft/i }).click()

    await expect(page).toHaveURL(/\/purchase-orders\/po_/, { timeout: 15_000 })
    await expect(page.getByText(/^draft$/i).first()).toBeVisible()
    await expect(page.getByText('0 received of 12 ordered')).toBeVisible()

    await page.getByRole('button', { name: /mark as ordered/i }).click()
    await expect(page.getByRole('heading', { name: /place this order\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /mark as ordered/i })
      .click()

    await expect(page.getByText(/^ordered$/i).first()).toBeVisible({ timeout: 15_000 })
    // Placed lines are a commitment to the supplier, so they can no longer be edited.
    await expect(page.getByRole('link', { name: /^edit$/i })).toHaveCount(0)
  })

  test('counts in part of a delivery, then closes the order short', async ({ page }) => {
    const creds = await login(page)
    const purchaseOrder = await createPurchaseOrder(page, creds.accessToken, {
      quantity: 10,
      ordered: true,
    })
    await openPurchaseOrder(page, creds.store_id, purchaseOrder)

    await page.getByLabel(/^accepted$/i).fill('4')
    await page.getByRole('button', { name: /^receive$/i }).click()

    await expect(page.getByText(/^partially received$/i).first()).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText('4 received of 10 ordered')).toBeVisible()

    // The supplier cannot send the rest: write it off rather than wait.
    await page.getByRole('button', { name: /more actions/i }).click()
    await page.getByRole('menuitem', { name: /close short/i }).click()
    await expect(page.getByRole('heading', { name: /close this order short\?/i })).toBeVisible()
    await page.locator('#close-short-reason').fill('Discontinued by the supplier')
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^close short$/i })
      .click()

    await expect(page.getByText(/^received$/i).first()).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText('Discontinued by the supplier')).toBeVisible()
  })

  test('corrects a draft', async ({ page }) => {
    const creds = await login(page)
    const purchaseOrder = await createPurchaseOrder(page, creds.accessToken, { quantity: 3 })
    await openPurchaseOrder(page, creds.store_id, purchaseOrder)

    await page.getByRole('link', { name: /^edit$/i }).click()
    await expect(
      page.getByRole('heading', { name: new RegExp(`edit order ${purchaseOrder.number}`, 'i') }),
    ).toBeVisible()

    const reference = `Corrected ${Date.now()}`
    await page.locator('#reference').fill(reference)
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByRole('heading', { name: purchaseOrder.number })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(reference)).toBeVisible()
  })

  test('cancels a placed order after confirming', async ({ page }) => {
    const creds = await login(page)
    const purchaseOrder = await createPurchaseOrder(page, creds.accessToken, {
      quantity: 5,
      ordered: true,
    })
    await openPurchaseOrder(page, creds.store_id, purchaseOrder)

    await page.getByRole('button', { name: /more actions/i }).click()
    await page.getByRole('menuitem', { name: /cancel order/i }).click()
    await expect(page.getByRole('heading', { name: /cancel this purchase order\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /cancel order/i })
      .click()

    await expect(page.getByText(/^cancelled$/i).first()).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a draft from the list', async ({ page }) => {
    const creds = await login(page)
    const purchaseOrder = await createPurchaseOrder(page, creds.accessToken, { quantity: 1 })
    await gotoIndex(page, PURCHASE_ORDERS_PATH(creds.store_id), CTA)

    await openRowMenu(page, purchaseOrder.number)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete this purchase order\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(page.getByRole('row').filter({ hasText: purchaseOrder.number })).toHaveCount(0, {
      timeout: 15_000,
    })
  })
})
