import { expect, type Page, test } from '@playwright/test'
import { FIXTURE_PROMO_PRODUCT, login } from './helpers'

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
  await page.getByPlaceholder(/search variant/i).fill(FIXTURE_PROMO_PRODUCT)
  await page
    .getByRole('button', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
    .first()
    .click()

  await page.locator('button[type="submit"]').click()
  await expect(page).toHaveURL(new RegExp(`/${storeId}/orders/or_[^/]+$`), { timeout: 15_000 })
}

/**
 * The Fulfillments card. Filtering `div` by contained text would match every
 * ancestor too, so anchor on the card element itself.
 */
function fulfillmentsCard(page: Page) {
  // The title holds an icon and a count badge beside the word, so match the
  // text loosely; anchoring on the card element keeps sibling cards out.
  return page.locator('[data-slot="card"]').filter({
    has: page.locator('[data-slot="card-title"]', { hasText: /fulfillments/i }),
  })
}

test.describe('order fulfillments', () => {
  // A draft carries no fulfillments, so its line item has nobody to claim it
  // and lands in the unfulfilled group at the top of the card — which is what
  // tells the merchant the goods still need shipping.
  test('lists the unclaimed line item on a draft with no shipping address', async ({ page }) => {
    const creds = await login(page)
    await createDraftOrder(page, creds.store_id)

    const card = fulfillmentsCard(page)
    await expect(card.getByText(/unfulfilled \(\d+\)/i)).toBeVisible({ timeout: 15_000 })
    await expect(card.getByText(new RegExp(FIXTURE_PROMO_PRODUCT, 'i')).first()).toBeVisible()
  })

  // Manual creation is a completed-order operation — Spree::Fulfillments::Create
  // rejects it otherwise — so the card must not offer an action that can only
  // fail. A draft's fulfillments come from the delivery step instead. "Add
  // item" sits in the same header and stays available.
  test('does not offer manual creation on an incomplete order', async ({ page }) => {
    const creds = await login(page)
    await createDraftOrder(page, creds.store_id)

    const card = fulfillmentsCard(page)
    await expect(card.getByText(/unfulfilled \(\d+\)/i)).toBeVisible({ timeout: 15_000 })
    await expect(card.getByRole('button', { name: /^add fulfillment$/i })).toHaveCount(0)
    await expect(card.getByRole('button', { name: /^add item$/i })).toBeVisible()
  })
})
