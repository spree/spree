import { expect, type Page, test } from '@playwright/test'
import {
  adminApiSession,
  adminRequest,
  FIXTURE_BULK_CATEGORY,
  FIXTURE_SELLER_PASSWORD,
  FIXTURE_SELLER_WRITER_EMAIL,
  login,
  SELLER_PANEL,
} from './helpers'
import { addProductCategory, categorizationCard, publishingCard } from './products-helpers'

const SAVE_FIRST = /save your changes first/i
const DECISION_REQUEST = /\/api\/v3\/admin\/products\/[^/]+\/(approve|reject)$/

/** Every approve or reject request the page sends, from here on. */
function recordDecisionRequests(page: Page): string[] {
  const decisions: string[] = []
  page.on('request', (request) => {
    const match = new URL(request.url()).pathname.match(DECISION_REQUEST)
    if (request.method() === 'PATCH' && match) decisions.push(match[1])
  })
  return decisions
}

/**
 * A product the panel seller lists and submits for review through the Seller
 * API, so it reaches the operator exactly as a real submission does: on no
 * sales channel.
 */
async function submittedSellerProduct(page: Page, name: string): Promise<string> {
  const signIn = await page.request.post(`${SELLER_PANEL}/api/v3/seller/auth/login`, {
    data: { email: FIXTURE_SELLER_WRITER_EMAIL, password: FIXTURE_SELLER_PASSWORD },
  })
  expect(signIn.ok(), await signIn.text()).toBeTruthy()
  const { token, sellers } = (await signIn.json()) as { token: string; sellers: { id: string }[] }
  const headers = { Authorization: `Bearer ${token}`, 'X-Spree-Seller-Id': sellers[0].id }

  const created = await page.request.post(`${SELLER_PANEL}/api/v3/seller/products`, {
    headers,
    data: { name },
  })
  expect(created.ok(), await created.text()).toBeTruthy()
  const { id } = (await created.json()) as { id: string }

  const submitted = await page.request.patch(
    `${SELLER_PANEL}/api/v3/seller/products/${id}/submit`,
    { headers },
  )
  expect(submitted.ok(), await submitted.text()).toBeTruthy()
  return id
}

async function openProduct(page: Page, storeId: string, productId: string) {
  await page.goto(`/${storeId}/products/${productId}`)
  await expect(page.getByRole('button', { name: /^approve$/i })).toBeVisible({ timeout: 15_000 })
}

async function approve(page: Page) {
  await page.getByRole('button', { name: /^approve$/i }).click()
  await page
    .getByRole('dialog')
    .getByRole('button', { name: /^approve$/i })
    .click()
  await expect(page.getByText(/product approved/i)).toBeVisible({ timeout: 15_000 })
}

test.describe('product review', () => {
  let productId: string | undefined

  test.afterEach(async ({ page }) => {
    if (!productId) return
    const admin = await adminApiSession(page)
    await adminRequest(page, admin, 'delete', `/products/${productId}`).catch(() => undefined)
    productId = undefined
  })

  // A seller's product arrives on no channel; approving it is what puts it
  // on sale, so it has to land on the store's own channel.
  test('lists an approved seller product on the default sales channel', async ({ page }) => {
    const name = `E2E Review Listed ${Date.now()}`
    productId = await submittedSellerProduct(page, name)
    const creds = await login(page)

    await openProduct(page, creds.store_id, productId)
    await expect(publishingCard(page).getByText(/not listed on any sales channel/i)).toBeVisible()

    await approve(page)

    await page.reload()
    await expect(publishingCard(page).getByText(/online store/i)).toBeVisible({ timeout: 15_000 })
    await expect(publishingCard(page).getByText(/not listed on any sales channel/i)).toHaveCount(0)
  })

  // Neither decision saves the form, so an edit made during review must be
  // saved first rather than silently dropped.
  test('asks to save unsaved edits before a decision, then keeps them', async ({ page }) => {
    const name = `E2E Review Edited ${Date.now()}`
    productId = await submittedSellerProduct(page, name)
    const creds = await login(page)

    await openProduct(page, creds.store_id, productId)
    const decisions = recordDecisionRequests(page)
    await addProductCategory(page, FIXTURE_BULK_CATEGORY)

    await page.getByRole('button', { name: /^approve$/i }).click()
    await expect(page.getByText(SAVE_FIRST)).toBeVisible()
    await expect(page.getByRole('dialog')).toHaveCount(0)

    // The Approve warning has to go before Send back is tried, so the one
    // that shows next can only be Send back's own.
    await expect(page.getByText(SAVE_FIRST)).toHaveCount(0, { timeout: 15_000 })

    await page.getByRole('button', { name: /^send back$/i }).click()
    await page.getByRole('button', { name: /^send back$/i }).click()
    await expect(page.getByText(SAVE_FIRST)).toBeVisible()
    await expect(page.getByText(/sent back to the seller/i)).toHaveCount(0)
    await page.getByRole('button', { name: /^cancel$/i }).click()

    // Still awaiting a decision: nothing was sent.
    await expect(page.getByRole('button', { name: /^approve$/i })).toBeVisible()
    expect(decisions).toEqual([])

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 15_000,
    })

    await approve(page)
    expect(decisions).toEqual(['approve'])

    await page.reload()
    await expect(
      categorizationCard(page).locator('[data-slot="combobox-chip"]', {
        hasText: FIXTURE_BULK_CATEGORY,
      }),
    ).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('button', { name: /^approve$/i })).toHaveCount(0)
  })
})
