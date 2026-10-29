import { expect, test } from '@playwright/test'
import {
  createInTransitTransfer,
  FIXTURE_TRANSFER_DESTINATION,
  FIXTURE_TRANSFER_PRODUCT,
  FIXTURE_TRANSFER_SKU,
  FIXTURE_TRANSFER_SOURCE,
  gotoIndex,
  login,
  saveCustomFieldOnCard,
  withCustomFieldDefinition,
} from './helpers'

const TRANSFERS_PATH = (storeId: string) => `/${storeId}/transfers`
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

    // Nothing can be added until the source is known: the picker can only offer
    // what that warehouse is able to send.
    await expect(page.getByRole('button', { name: /add a product/i })).toBeDisabled()
    await expect(page.getByText(/choose the warehouse it leaves from first/i)).toBeVisible()
  })

  test('raises a draft from the form, packs it and sends it', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TRANSFERS_PATH(creds.store_id), CTA)
    await page.getByRole('button', { name: CTA }).click()
    await expect(page.getByRole('heading', { name: /new stock transfer/i })).toBeVisible()

    await page.locator('#source').click()
    await page.getByRole('option', { name: FIXTURE_TRANSFER_SOURCE }).click()
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
    await page.getByRole('spinbutton', { name: /^shipped$/i }).fill('3')
    // Transfers move stock the merchant already owns, so a line carries no cost.
    await expect(page.getByLabel(/^unit cost$/i)).toHaveCount(0)

    await page.getByRole('button', { name: /create draft/i }).click()

    await expect(page).toHaveURL(/\/transfers\/st_/, { timeout: 15_000 })
    await expect(page.getByText(/^draft$/i).first()).toBeVisible()

    await page.getByRole('button', { name: /mark as ready to ship/i }).click()
    await expect(page.getByText(/^ready to ship$/i).first()).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /mark in transit/i }).click()
    await expect(page.getByRole('heading', { name: /send this transfer\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /mark in transit/i })
      .click()

    await expect(page.getByText(/^in transit$/i).first()).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText('0 received of 3 shipped')).toBeVisible()
    await expect(page.getByText(/no deliveries yet/i)).toBeVisible()
  })

  test('records a custom field on the transfer', async ({ page }) => {
    const creds = await login(page)
    await withCustomFieldDefinition(page, creds, 'stock_transfer', async (label) => {
      const transfer = await createInTransitTransfer(page, creds.accessToken, {
        sku: FIXTURE_TRANSFER_SKU,
        quantity: 1,
      })
      await page.goto(`${TRANSFERS_PATH(creds.store_id)}/${transfer.id}`)
      // A detail page with no form of its own: the card edits and saves itself.
      await saveCustomFieldOnCard(page, label, 'Carrier TRK-42')
    })
  })

  test('sends a draft, then counts in a delivery with damage', async ({ page }) => {
    const creds = await login(page)
    const transfer = await createInTransitTransfer(page, creds.accessToken, {
      sku: FIXTURE_TRANSFER_SKU,
      quantity: 10,
    })

    await page.goto(`${TRANSFERS_PATH(creds.store_id)}/${transfer.id}`)

    await expect(page.getByRole('heading', { name: transfer.number })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(/^in transit$/i).first()).toBeVisible()
    // Gone from the source, not yet at the destination.
    await expect(page.getByText('0 received of 10 shipped')).toBeVisible()

    // Count in eight of the ten intact; the other two arrived crushed.
    await page.getByLabel(/^accepted$/i).fill('8')
    await page.getByLabel(/^rejected$/i).fill('2')
    // A refusal has to say why before the delivery can be booked.
    const receive = page.getByRole('button', { name: /^receive$/i })
    await expect(receive).toBeDisabled()
    await page.getByLabel(/^reason$/i).click()
    await page.getByRole('option', { name: /^damaged$/i }).click()
    await receive.click()

    // Everything that left has arrived, so the trip is over — with the two
    // refused units on the delivery's record, not the shelf.
    await expect(page.getByText(/^received$/i).first()).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText('8 received of 10 shipped')).toBeVisible()
    await expect(page.getByText(/8 accepted · 2 rejected/i)).toBeVisible()
    await expect(page.getByRole('cell', { name: /^damaged$/i })).toBeVisible()
  })

  test('counts a transfer in over two deliveries, each its own stock receipt', async ({ page }) => {
    const creds = await login(page)
    const transfer = await createInTransitTransfer(page, creds.accessToken, {
      sku: FIXTURE_TRANSFER_SKU,
      quantity: 6,
    })

    await page.goto(`${TRANSFERS_PATH(creds.store_id)}/${transfer.id}`)
    await expect(page.getByRole('heading', { name: transfer.number })).toBeVisible({
      timeout: 15_000,
    })

    const firstNote = `Van 1 ${Date.now()}`
    await page.getByLabel(/^delivery note$/i).fill(firstNote)
    await page.getByLabel(/^accepted$/i).fill('2')
    await page.getByRole('button', { name: /^receive$/i }).click()

    await expect(page.getByText(/^partially received$/i).first()).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText('2 received of 6 shipped')).toBeVisible()
    await expect(page.getByText(firstNote)).toBeVisible()

    // The rest of the load arrives on a second van.
    await page.getByLabel(/^accepted$/i).fill('4')
    await page.getByRole('button', { name: /^receive$/i }).click()

    await expect(page.getByText('6 received of 6 shipped')).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(/^\d+ accepted · \d+ rejected$/)).toHaveCount(2)
    await expect(page.getByText('2 accepted · 0 rejected')).toBeVisible()
    await expect(page.getByText('4 accepted · 0 rejected')).toBeVisible()
    await expect(page.getByText(/receive a delivery/i)).toHaveCount(0)
  })

  // Filled by the probes in src/testing/slot-probes.tsx.
  test('renders the plugin slot at the end of the main column', async ({ page }) => {
    const creds = await login(page)
    const draft = await createDraftTransfer(page, creds.accessToken, 1)

    await page.goto(`${TRANSFERS_PATH(creds.store_id)}/${draft.id}`)
    await expect(page.getByText('Slot probe: stock_transfer.form_main')).toBeVisible({
      timeout: 15_000,
    })
  })

  test('a draft can be corrected, a shipped one cannot', async ({ page }) => {
    const creds = await login(page)
    const draft = await createDraftTransfer(page, creds.accessToken, 3)

    await page.goto(`${TRANSFERS_PATH(creds.store_id)}/${draft.id}`)
    await expect(page.getByRole('heading', { name: draft.number })).toBeVisible({
      timeout: 15_000,
    })

    await page.getByRole('link', { name: /^edit$/i }).click()
    await expect(
      page.getByRole('heading', { name: new RegExp(`edit transfer ${draft.number}`, 'i') }),
    ).toBeVisible()

    const reference = `Corrected ${Date.now()}`
    await page.getByLabel(/^reference$/i).fill(reference)
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByText(reference)).toBeVisible({ timeout: 15_000 })

    // Once it has shipped there is nothing to correct: what is in the box is a
    // matter of record.
    const shipped = await createInTransitTransfer(page, creds.accessToken, {
      sku: FIXTURE_TRANSFER_SKU,
      quantity: 2,
    })
    await page.goto(`${TRANSFERS_PATH(creds.store_id)}/${shipped.id}`)
    await expect(page.getByRole('heading', { name: shipped.number })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByRole('link', { name: /^edit$/i })).toHaveCount(0)
  })

  test('makes the merchant say what happened to units already gone', async ({ page }) => {
    const creds = await login(page)
    const transfer = await createInTransitTransfer(page, creds.accessToken, {
      sku: FIXTURE_TRANSFER_SKU,
      quantity: 4,
    })

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

/** The same fixture transfer, left as a draft. */
async function createDraftTransfer(
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

  const variants = await page.request
    .get('/api/v3/admin/variants', { headers, params: { 'q[sku_eq]': FIXTURE_TRANSFER_SKU } })
    .then((res) => res.json())

  const created = await page.request.post('/api/v3/admin/stock_transfers', {
    headers,
    data: {
      source_location_id: source.id,
      destination_location_id: destination.id,
      reference: `E2E draft ${Date.now()}`,
      items: [{ variant_id: variants.data[0].id, quantity_shipped: quantity }],
    },
  })
  expect(created.status(), await created.text()).toBe(201)

  return created.json()
}
