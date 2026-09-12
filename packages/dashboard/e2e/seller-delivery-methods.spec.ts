import { expect, test } from '@playwright/test'
import { login } from './helpers'

// The seller panel is its own app on its own origin (see playwright.config.ts).
const SELLER_PANEL = `http://localhost:${process.env.E2E_SELLER_VITE_PORT || '5175'}`

/**
 * Creates a seller, invites someone, and accepts on the panel — returning the
 * signed-in seller page. The invitation flow has its own spec; this is the
 * precondition for anything a seller does afterwards.
 */
async function signInAsNewSeller(
  page: import('@playwright/test').Page,
  browser: import('@playwright/test').Browser,
) {
  const creds = await login(page)
  const suffix = Date.now()
  const sellerName = `E2E Shipping Seller ${suffix}`

  await page.goto(`/${creds.store_id}/sellers`)
  await page.getByRole('button', { name: /add seller/i }).click()
  await page.locator('#name').fill(sellerName)
  await page.getByRole('button', { name: /create seller/i }).click()
  await expect(page.getByRole('heading', { name: sellerName })).toBeVisible({ timeout: 15_000 })

  await page
    .getByRole('button', { name: /^invite$/i })
    .first()
    .click()
  await page.locator('#invite-email').fill(`e2e-shipping-${suffix}@example.com`)

  const [listResponse] = await Promise.all([
    page.waitForResponse(
      (res) =>
        /\/api\/v3\/admin\/sellers\/[^/]+\/invitations$/.test(res.url()) &&
        res.request().method() === 'GET' &&
        res.status() === 200,
      { timeout: 20_000 },
    ),
    page.getByRole('button', { name: /send invitation/i }).click(),
  ])
  const { data } = (await listResponse.json()) as { data: Array<{ acceptance_url: string }> }
  const acceptancePath = data[0].acceptance_url.replace(/^https?:\/\/[^/]+/, '')

  const context = await browser.newContext()
  const sellerPage = await context.newPage()
  await sellerPage.goto(`${SELLER_PANEL}${acceptancePath}`)
  await expect(sellerPage.getByLabel(/^password$/i)).toBeVisible({ timeout: 20_000 })
  await sellerPage.getByLabel(/first name/i).fill('Ali')
  await sellerPage.getByLabel(/last name/i).fill('Okafor')
  await sellerPage.getByLabel(/^password$/i).fill('e2e-password-123')
  await sellerPage.getByLabel(/confirm password/i).fill('e2e-password-123')
  await sellerPage.getByRole('button', { name: /accept|create account|join/i }).click()
  await expect(sellerPage).not.toHaveURL(/accept-invitation/, { timeout: 20_000 })

  return { context, sellerPage }
}

test.describe('seller delivery methods', () => {
  // Creating a seller, inviting, accepting, then pricing a method is four
  // round trips before this spec's own subject starts.
  test.slow()

  // A seller names their own shipping and what it costs. The calculator is
  // named on the wire by its `api_type` shorthand, and the panel picks the
  // flat rate by that same value — a mismatch leaves the price blank and
  // ships the goods free, so both halves have to go through the UI.
  test('a seller prices their own shipping with a flat rate', async ({ page, browser }) => {
    const { context, sellerPage } = await signInAsNewSeller(page, browser)

    try {
      const methodName = `E2E Seller Shipping ${Date.now()}`

      // Navigated by clicking rather than by a built URL: acceptance lands on
      // the panel root and the seller id only appears in the path once the
      // panel has resolved which seller this user acts for.
      await sellerPage
        .getByRole('link', { name: /^settings$/i })
        .first()
        .click()
      await sellerPage
        .getByRole('link', { name: /delivery methods/i })
        .first()
        .click()
      await expect(sellerPage.getByRole('button', { name: /add delivery method/i })).toBeVisible({
        timeout: 20_000,
      })

      await sellerPage.getByRole('button', { name: /add delivery method/i }).click()
      await sellerPage.locator('#delivery-method-name').fill(methodName)

      // The pricing picker is built from `GET /seller/delivery_methods/calculators`.
      // It defaults to the flat rate, so a readable label here proves the
      // catalog resolved and the default matched.
      const calculator = sellerPage.locator('#delivery-method-calculator')
      await expect(calculator).toContainText(/flat rate/i, { timeout: 20_000 })

      // The flat rate's own amount preference — blank would mean the method
      // saves as free.
      const amount = sellerPage.locator('#preference-amount')
      await expect(amount).toBeVisible({ timeout: 20_000 })
      await amount.fill('9.99')

      await sellerPage.getByRole('button', { name: /^save$/i }).click()

      // It is the seller's own row afterwards.
      await expect(sellerPage.getByText(methodName)).toBeVisible({ timeout: 20_000 })

      // Reopening hydrates from the persisted row: the calculator and its
      // amount both round-tripped rather than saving as a free method.
      await sellerPage.getByText(methodName).click()
      await expect(sellerPage.locator('#delivery-method-calculator')).toContainText(/flat rate/i, {
        timeout: 20_000,
      })
      await expect(sellerPage.locator('#preference-amount')).toHaveValue(/9\.99/)
    } finally {
      await context.close()
    }
  })
})
