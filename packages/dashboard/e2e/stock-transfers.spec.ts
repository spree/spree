import { expect, test } from '@playwright/test'
import {
  FIXTURE_TRANSFER_DESTINATION,
  FIXTURE_TRANSFER_SKU,
  FIXTURE_TRANSFER_SOURCE,
  gotoIndex,
  login,
} from './helpers'

const TRANSFERS_PATH = (storeId: string) => `/${storeId}/products/transfers`
const CTA = /new transfer/i

/**
 * The whole point of the 6.0 transfer: a trip has a middle. Stock leaves the
 * source when the van goes and lands at the destination when somebody counts
 * it in — and counting in less than was sent has to be the ordinary case.
 *
 * The draft is opened through the API rather than the form: the receive screen
 * is what is new here, and driving two warehouse selects through the UI only
 * re-tests the select primitive.
 */
test.describe('stock transfers', () => {
  test('lists transfers', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TRANSFERS_PATH(creds.store_id), CTA)
  })

  test('offers the create form', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TRANSFERS_PATH(creds.store_id), CTA)

    await page.getByRole('button', { name: CTA }).click()

    await expect(page.getByRole('heading', { name: /new stock transfer/i })).toBeVisible()
    await expect(page.locator('#source')).toBeVisible()
    await expect(page.locator('#destination')).toBeVisible()
    // Empty until a SKU is added — a draft may open with nothing on it.
    await expect(page.getByRole('button', { name: /create draft/i })).toBeVisible()
  })

  test('sends a draft, then receives less than was sent', async ({ page }) => {
    const creds = await login(page)
    const transfer = await createInTransitTransfer(page, creds.accessToken, 10)

    await page.goto(`${TRANSFERS_PATH(creds.store_id)}/${transfer.id}`)

    await expect(page.getByRole('heading', { name: transfer.number })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(/^in transit$/i).first()).toBeVisible()
    // Gone from the source, not yet at the destination.
    await expect(page.getByText('0 received of 10 shipped')).toBeVisible()

    // Count in eight of the ten, and say why two are missing.
    await page.getByLabel(/^received$/i).fill('8')
    const discrepancy = page.getByLabel(/discrepancy/i)
    await discrepancy.click()
    await page.getByRole('option', { name: /damaged in transit/i }).click()
    await page.getByRole('button', { name: /^receive$/i }).click()

    // Short, so the trip stays open rather than closing.
    await expect(page.getByText(/^partially received$/i).first()).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText('8 received of 10 shipped')).toBeVisible()
  })

  test('makes the merchant say what happened to units already gone', async ({ page }) => {
    const creds = await login(page)
    const transfer = await createInTransitTransfer(page, creds.accessToken, 4)

    await page.goto(`${TRANSFERS_PATH(creds.store_id)}/${transfer.id}`)
    await expect(page.getByRole('heading', { name: transfer.number })).toBeVisible({
      timeout: 15_000,
    })

    // Nothing left to send, so the header offers no forward action.
    await expect(page.getByRole('button', { name: /mark in transit/i })).toHaveCount(0)

    await page.getByRole('button', { name: /more actions/i }).click()
    await page.getByRole('menuitem', { name: /cancel transfer/i }).click()

    // The units are physically gone from the source, so the dialog asks what
    // happened to them and refuses to proceed until it is told.
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByText(/the units have already left/i)).toBeVisible()
    const confirmCancel = dialog.getByRole('button', { name: /^cancel transfer$/i })
    await expect(confirmCancel).toBeDisabled()

    await dialog.getByText(/put the units back at the source/i).click()
    await expect(confirmCancel).toBeEnabled()
    await confirmCancel.click()

    await expect(page.getByText(/^cancelled$/i).first()).toBeVisible({ timeout: 15_000 })
  })
})

/**
 * A transfer already on the road, opened through the Admin API.
 *
 * Both warehouses and the product come from the global-setup fixtures, which
 * is also where the source's stock comes from — a transfer cannot ship from an
 * empty shelf.
 */
async function createInTransitTransfer(
  page: import('@playwright/test').Page,
  accessToken: string,
  quantity: number,
) {
  const headers = { Authorization: `Bearer ${accessToken}` }

  const locations = await page.request
    .get('/api/v3/admin/stock_locations', { headers, params: { limit: 100 } })
    .then((res) => res.json())
  const source = locations.data.find((l: { name: string }) => l.name === FIXTURE_TRANSFER_SOURCE)
  const destination = locations.data.find(
    (l: { name: string }) => l.name === FIXTURE_TRANSFER_DESTINATION,
  )

  // By SKU, not by search: the fixture SKU resolves exactly the variant whose
  // stock global-setup put on the source shelf, and a transfer cannot ship
  // from an empty one.
  const variants = await page.request
    .get('/api/v3/admin/variants', {
      headers,
      params: { 'q[sku_eq]': FIXTURE_TRANSFER_SKU },
    })
    .then((res) => res.json())
  expect(variants.data, `no variant with SKU ${FIXTURE_TRANSFER_SKU}`).not.toHaveLength(0)

  const created = await page.request.post('/api/v3/admin/stock_transfers', {
    headers,
    data: {
      source_location_id: source.id,
      destination_location_id: destination.id,
      reference: `E2E restock ${Date.now()}`,
      items: [{ variant_id: variants.data[0].id, quantity_shipped: quantity }],
    },
  })
  expect(created.status(), await created.text()).toBe(201)
  const transfer = await created.json()

  const shipped = await page.request.patch(
    `/api/v3/admin/stock_transfers/${transfer.id}/mark_in_transit`,
    { headers },
  )
  expect(shipped.status(), await shipped.text()).toBe(200)

  return transfer
}
