import { expect, type Page, test } from '@playwright/test'
import {
  addNewOrderItem,
  adminRequest,
  createPlacedOrder,
  FIXTURE_PROMO_PRODUCT,
  login,
} from './helpers'

const NEW_ORDER_PATH = (storeId: string) => `/${storeId}/orders/new`

/**
 * Creates a draft order with a single line item and lands on its detail page.
 * A draft built this way has no shipping address yet, so it carries no
 * fulfillments — the state a merchant starts from.
 */
async function createDraftOrder(page: Page, storeId: string) {
  await page.goto(NEW_ORDER_PATH(storeId))
  await expect(page.getByRole('heading', { name: /new order/i })).toBeVisible({ timeout: 15_000 })

  await page.locator('#order-email').fill(`e2e-fulfillment-${Date.now()}@example.com`)
  await addNewOrderItem(page, FIXTURE_PROMO_PRODUCT)

  await page.locator('button[type="submit"]').click()
  await expect(page).toHaveURL(new RegExp(`/${storeId}/orders/or_[^/]+$`), { timeout: 15_000 })
}

/**
 * The Fulfillments section. Filtering `div` by contained text would match every
 * ancestor too, so anchor on the section element itself.
 */
function fulfillmentsCard(page: Page) {
  // The heading holds an icon and a count badge beside the word, so match
  // the text loosely; anchoring on the section keeps sibling ones out.
  return page
    .locator('[data-slot="section"]')
    .filter({ has: page.getByRole('heading', { name: /fulfillments/i }) })
}

test.describe('order fulfillments', () => {
  // A draft carries no fulfillments, so its line item has nobody to claim it
  // and lands in the unfulfilled group at the top of the card — which is what
  // tells the merchant the goods still need shipping.
  test('lists the unclaimed line item on a draft with no shipping address', async ({ page }) => {
    const creds = await login(page)
    await createDraftOrder(page, creds.store_id)

    const card = fulfillmentsCard(page)
    await expect(card.getByText(/\d+ items? still to fulfill/i)).toBeVisible({ timeout: 15_000 })
    await expect(card.getByText(new RegExp(FIXTURE_PROMO_PRODUCT, 'i')).first()).toBeVisible()
  })

  // Manual creation is a completed-order operation — Spree::Fulfillments::Create
  // rejects it otherwise — so the card must not offer an action that can only
  // fail. A draft's fulfillments come from the delivery step instead.
  test('does not offer manual creation on an incomplete order', async ({ page }) => {
    const creds = await login(page)
    await createDraftOrder(page, creds.store_id)

    const card = fulfillmentsCard(page)
    await expect(card.getByText(/\d+ items? still to fulfill/i)).toBeVisible({ timeout: 15_000 })
    await expect(card.getByRole('button', { name: /^add fulfillment$/i })).toHaveCount(0)
  })

  // Changing what an order contains after placement belongs to the order edit
  // screen, so the card's item rows are read-only: they still say what ships
  // where, but carry no per-row menu.
  test('lists item rows without per-row actions', async ({ page }) => {
    const creds = await login(page)
    await createDraftOrder(page, creds.store_id)

    const card = fulfillmentsCard(page)
    await expect(card.getByText(/\d+ items? still to fulfill/i)).toBeVisible({ timeout: 15_000 })
    await expect(card.getByText(new RegExp(FIXTURE_PROMO_PRODUCT, 'i')).first()).toBeVisible()
    await expect(card.getByRole('button', { name: /actions for/i })).toHaveCount(0)
  })
  // Tracking is a Spree::Delivery since 6.0, and a draft has no fulfillment
  // record to hang one off — so the card offers no tracking controls until
  // the order is placed. Anything else would present an action that can only
  // fail.
  test('offers no tracking or label controls on a draft', async ({ page }) => {
    const creds = await login(page)
    await createDraftOrder(page, creds.store_id)

    const card = fulfillmentsCard(page)
    await expect(card.getByText(/\d+ items? still to fulfill/i)).toBeVisible({ timeout: 15_000 })
    await expect(card.getByRole('button', { name: /add tracking/i })).toHaveCount(0)
    await expect(card.getByRole('button', { name: /buy label/i })).toHaveCount(0)
    await expect(card.getByRole('button', { name: /print label/i })).toHaveCount(0)
  })

  // A label bought elsewhere goes to private storage, under the
  // `file_signed_id` name the label endpoint now requires.
  test('uploads a label bought elsewhere onto a placed order', async ({ page }) => {
    const creds = await login(page)
    const order = await createPlacedOrder(page, creds.accessToken, { ship: false })
    await page.goto(`/${creds.store_id}/orders/${order.id}`)

    const card = fulfillmentsCard(page)
    await card
      .getByRole('button', { name: /^actions$/i })
      .first()
      .click({ timeout: 15_000 })
    await page.getByRole('menuitem', { name: /^upload label$/i }).click()

    const dialog = page.getByRole('dialog')
    await dialog.locator('input[type="file"]').setInputFiles({
      name: 'label.pdf',
      mimeType: 'application/pdf',
      buffer: Buffer.from('%PDF-1.4\n%%EOF\n'),
    })
    await dialog.locator('#label-tracking-number').fill(`1Z${Date.now()}`)

    // Saving is disabled until the upload resolves.
    const submit = dialog.getByRole('button', { name: /^upload label$/i })
    await expect(submit).toBeEnabled({ timeout: 30_000 })
    await submit.click()

    await expect(dialog).toBeHidden({ timeout: 15_000 })
    await expect(card.getByText(/^uploaded$/i)).toBeVisible({ timeout: 15_000 })
    await expect(card.getByRole('button', { name: /print label/i })).toBeVisible()
  })

  // Marking delivered emails the customer unless the merchant unticks it.
  test('marks a shipped parcel delivered without emailing the customer', async ({ page }) => {
    const creds = await login(page)
    const order = await createPlacedOrder(page, creds.accessToken)
    await page.goto(`/${creds.store_id}/orders/${order.id}`)

    const card = fulfillmentsCard(page)
    await card.getByRole('button', { name: /^mark as delivered$/i }).click({ timeout: 15_000 })

    const dialog = page.getByRole('dialog')
    const notify = dialog.getByRole('checkbox', { name: /email the customer/i })
    await expect(notify).toBeChecked()

    // Backing out forgets the choice: the next attempt asks afresh.
    await notify.click()
    await dialog.getByRole('button', { name: /^cancel$/i }).click()
    await expect(dialog).toBeHidden()
    await card.getByRole('button', { name: /^mark as delivered$/i }).click()
    await expect(notify).toBeChecked()

    await notify.click()
    await expect(notify).not.toBeChecked()

    const request = page.waitForRequest(
      (req) => req.method() === 'PATCH' && req.url().endsWith('/mark_delivered'),
    )
    await dialog.getByRole('button', { name: /^mark as delivered$/i }).click()
    expect((await request).postDataJSON()).toMatchObject({ notify_customer: false })

    await expect(dialog).toBeHidden({ timeout: 15_000 })
    await expect(card.getByRole('button', { name: /^mark as delivered$/i })).toHaveCount(0)
    await expect(card.getByText(/^delivered$/i).first()).toBeVisible()
  })

  // The last consignment to arrive completes the parcel, so it asks too.
  test('asks before the last tracked consignment marks the parcel delivered', async ({ page }) => {
    const creds = await login(page)
    const order = await createPlacedOrder(page, creds.accessToken)
    const { data } = await adminRequest<{ data: { id: string }[] }>(
      page,
      creds,
      'get',
      `/orders/${order.id}/fulfillments`,
    )
    const tracking = `1Z${Date.now()}`
    await adminRequest(
      page,
      creds,
      'post',
      `/orders/${order.id}/fulfillments/${data[0].id}/deliveries`,
      { tracking_number: tracking },
    )
    await page.goto(`/${creds.store_id}/orders/${order.id}`)

    // The consignment's own menu sits on its row, beside the tracking number.
    const card = fulfillmentsCard(page)
    await card
      .getByText(tracking, { exact: true })
      .locator('xpath=ancestor::div[2]')
      .getByRole('button', { name: /^actions$/i })
      .click({ timeout: 15_000 })
    await page.getByRole('menuitem', { name: /^mark arrived$/i }).click()

    const dialog = page.getByRole('dialog')
    await expect(dialog.getByRole('checkbox', { name: /email the customer/i })).toBeChecked()

    const request = page.waitForRequest(
      (req) => req.method() === 'PATCH' && /\/deliveries\/[^/]+\/mark_delivered$/.test(req.url()),
    )
    await dialog.getByRole('button', { name: /^mark as delivered$/i }).click()
    expect((await request).postDataJSON()).toMatchObject({ notify_customer: true })

    await expect(dialog).toBeHidden({ timeout: 15_000 })
    await expect(card.getByRole('button', { name: /^mark as delivered$/i })).toHaveCount(0)
  })
})
