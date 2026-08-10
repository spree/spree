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
 * ancestor too — including the page wrapper, whose first "Add" button belongs
 * to the Items card — so anchor on the card element itself.
 */
function fulfillmentsCard(page: Page) {
  return page.locator('[data-slot="card"]').filter({
    has: page.getByText(/^fulfillments$/i),
  })
}

test.describe('order fulfillments', () => {
  test('shows the empty state on a draft with no shipping address', async ({ page }) => {
    const creds = await login(page)
    await createDraftOrder(page, creds.store_id)

    await expect(page.getByText(/no fulfillments on this order yet/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  // Manual creation is a completed-order operation — Spree::Fulfillments::Create
  // rejects it otherwise — so the card must not offer an action that can only
  // fail. A draft's fulfillments come from the delivery step instead.
  test('does not offer manual creation on an incomplete order', async ({ page }) => {
    const creds = await login(page)
    await createDraftOrder(page, creds.store_id)

    await expect(page.getByText(/no fulfillments on this order yet/i)).toBeVisible({
      timeout: 15_000,
    })
    await expect(fulfillmentsCard(page).getByRole('button', { name: /^add$/i })).toHaveCount(0)
  })
})
