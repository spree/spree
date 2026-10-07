import { expect, type Page, test } from '@playwright/test'
import { createShippedOrder, FIXTURE_PROMO_PRODUCT, login } from './helpers'

/** One of the order page's cards, found by its title. */
function card(page: Page, title: RegExp) {
  return page
    .locator('[data-slot="card"]')
    .filter({ has: page.locator('[data-slot="card-title"]', { hasText: title }) })
    .first()
}

/** Picks an action from a return or claim's own menu. */
async function recordAction(page: Page, section: RegExp, action: RegExp) {
  await card(page, section)
    .getByRole('button', { name: /^actions$/i })
    .click()
  await page.getByRole('menuitem', { name: action }).click()
}

test.describe('post-sale', () => {
  // Creating a paid, shipped order through the API, then walking the return
  // through every state, is more than the default budget allows.
  test.slow()

  test('takes a return from request to refund, and lists it store-wide', async ({ page }) => {
    const creds = await login(page)
    const order = await createShippedOrder(page, creds.accessToken)
    await page.goto(`/${creds.store_id}/orders/${order.id}`)

    const returns = card(page, /^returns/i)
    await expect(returns.getByText(/no returns for this order/i)).toBeVisible({ timeout: 15_000 })
    await returns.getByRole('button', { name: /new return/i }).click()

    const dialog = page.getByRole('dialog')
    await expect(dialog.getByRole('heading', { name: /new return/i })).toBeVisible()
    await dialog.getByRole('spinbutton', { name: new RegExp(FIXTURE_PROMO_PRODUCT) }).fill('1')
    await dialog.locator('#reason-return-reasons').click()
    await page.getByRole('option', { name: 'Damaged/Defective' }).click()
    await dialog.locator('#return-memo').fill('Cracked in transit')
    await dialog.getByRole('button', { name: /new return/i }).click()

    await expect(returns.getByText(/^requested$/i)).toBeVisible({ timeout: 15_000 })

    await recordAction(page, /^returns/i, /^approve$/i)
    await expect(returns.getByText(/^approved$/i)).toBeVisible({ timeout: 15_000 })

    await recordAction(page, /^returns/i, /receive items/i)
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /receive items/i })
      .click()
    await expect(returns.getByText(/^received$/i)).toBeVisible({ timeout: 15_000 })

    await recordAction(page, /^returns/i, /^refund$/i)
    await page.locator('#refund-method').click()
    await page.getByRole('option', { name: /store credit/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^refund$/i })
      .click()
    // The status badge, and the footer naming what went back rather than what
    // was owed.
    await expect(
      returns.locator('[data-slot="status-badge"]').filter({ hasText: /^refunded$/i }),
    ).toBeVisible({ timeout: 15_000 })
    await expect(
      returns.locator('[data-slot="card-footer"]').getByText(/^refunded$/i),
    ).toBeVisible()

    // The cross-order list is where the team sees what is still in flight.
    await page.goto(`/${creds.store_id}/returns`)
    await expect(page.getByRole('row').filter({ hasText: order.number })).toBeVisible({
      timeout: 15_000,
    })
  })

  test('opens a claim for a missing item, denies it, and lists it store-wide', async ({ page }) => {
    const creds = await login(page)
    const order = await createShippedOrder(page, creds.accessToken, 1)
    await page.goto(`/${creds.store_id}/orders/${order.id}`)

    const claims = card(page, /^claims/i)
    await claims.getByRole('button', { name: /new claim/i }).click({ timeout: 15_000 })

    const dialog = page.getByRole('dialog')
    await expect(dialog.getByRole('heading', { name: /new claim/i })).toBeVisible()
    await dialog.getByRole('spinbutton', { name: new RegExp(FIXTURE_PROMO_PRODUCT) }).fill('1')
    await dialog.locator('#reason-claim-reasons').click()
    await page.getByRole('option', { name: 'Never arrived' }).click()
    await dialog.getByRole('button', { name: /new claim/i }).click()

    await expect(claims.getByText(/^open$/i)).toBeVisible({ timeout: 15_000 })

    await recordAction(page, /^claims/i, /^deny$/i)
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^deny$/i })
      .click()
    await expect(claims.getByText(/^denied$/i)).toBeVisible({ timeout: 15_000 })

    await page.goto(`/${creds.store_id}/claims`)
    await expect(page.getByRole('row').filter({ hasText: order.number })).toBeVisible({
      timeout: 15_000,
    })
  })

  test('lists exchanges store-wide', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/exchanges`)

    await expect(page.getByRole('heading', { name: /^exchanges$/i })).toBeVisible({
      timeout: 15_000,
    })
  })
})
