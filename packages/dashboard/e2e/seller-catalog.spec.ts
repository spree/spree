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
  const sellerName = `E2E Catalog Seller ${suffix}`

  await page.goto(`/${creds.store_id}/sellers`)
  await page.getByRole('button', { name: /add seller/i }).click()
  await page.locator('#name').fill(sellerName)
  await page.getByRole('button', { name: /create seller/i }).click()
  await expect(page.getByRole('heading', { name: sellerName })).toBeVisible({ timeout: 15_000 })

  await page
    .getByRole('button', { name: /^invite$/i })
    .first()
    .click()
  await page.locator('#invite-email').fill(`e2e-catalog-${suffix}@example.com`)

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
  await sellerPage.getByLabel(/first name/i).fill('Pat')
  await sellerPage.getByLabel(/last name/i).fill('Carlson')
  await sellerPage.getByLabel(/^password$/i).fill('e2e-password-123')
  await sellerPage.getByLabel(/confirm password/i).fill('e2e-password-123')
  await sellerPage.getByRole('button', { name: /accept|create account|join/i }).click()
  await expect(sellerPage).not.toHaveURL(/accept-invitation/, { timeout: 20_000 })

  return { context, sellerPage, sellerName }
}

test.describe('seller catalog and orders', () => {
  test('a seller lists a product and sees their orders', async ({ page, browser }) => {
    const { context, sellerPage } = await signInAsNewSeller(page, browser)

    try {
      // Products: the list is reachable from the nav and starts empty.
      await sellerPage
        .getByRole('link', { name: /products/i })
        .first()
        .click()
      await expect(sellerPage.getByRole('heading', { name: /products/i })).toBeVisible({
        timeout: 20_000,
      })

      // Creating one lands on its own page, which is how the panel proves the
      // record was saved rather than merely posted.
      const productName = `E2E Lamp ${Date.now()}`
      await sellerPage.getByRole('button', { name: /add product/i }).click()
      await sellerPage.locator('#name').fill(productName)
      await sellerPage.locator('#amount').fill('19.99')
      await sellerPage.getByRole('button', { name: /^save$/i }).click()

      // The URL is what proves it saved: creating navigates to the new
      // record's own page, which cannot happen if the POST did not return one.
      await expect(sellerPage).toHaveURL(/\/products\/prod_/, { timeout: 20_000 })
      await expect(sellerPage.getByRole('heading', { name: productName })).toBeVisible({
        timeout: 20_000,
      })

      // And it is in the seller's own list afterwards.
      await sellerPage
        .getByRole('link', { name: /products/i })
        .first()
        .click()
      await expect(sellerPage.getByText(productName)).toBeVisible({ timeout: 20_000 })

      // Orders: nothing sold yet, so the empty state rather than an error.
      await sellerPage
        .getByRole('link', { name: /orders/i })
        .first()
        .click()
      await expect(sellerPage.getByRole('heading', { name: /orders/i })).toBeVisible({
        timeout: 20_000,
      })
      await expect(sellerPage.getByText(/something went wrong/i)).toHaveCount(0)
    } finally {
      await context.close()
    }
  })
})
