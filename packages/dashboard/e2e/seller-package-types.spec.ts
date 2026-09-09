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
  const sellerName = `E2E Packaging Seller ${suffix}`

  await page.goto(`/${creds.store_id}/sellers`)
  await page.getByRole('button', { name: /add seller/i }).click()
  await page.locator('#name').fill(sellerName)
  await page.getByRole('button', { name: /create seller/i }).click()
  await expect(page.getByRole('heading', { name: sellerName })).toBeVisible({ timeout: 15_000 })

  await page
    .getByRole('button', { name: /^invite$/i })
    .first()
    .click()
  await page.locator('#invite-email').fill(`e2e-packaging-${suffix}@example.com`)

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

test.describe('seller packaging', () => {
  // Creating a seller, inviting, accepting, then walking two panel pages does
  // not fit the suite's default budget — the preamble alone is four round
  // trips before this spec's own subject starts.
  test.slow()

  test('a seller records the box they ship in and the requirement completes', async ({
    page,
    browser,
  }) => {
    const { context, sellerPage } = await signInAsNewSeller(page, browser)

    try {
      const boxName = `E2E Mailer ${Date.now()}`

      // Navigated by clicking rather than by a built URL: acceptance lands on
      // the panel root and the seller id only appears in the path once the
      // panel has resolved which seller this user acts for. A hand-built path
      // races that and sends requests carrying no seller header.
      // "Setup" is what the panel calls the onboarding checklist in its nav
      // and its heading.
      const goToSetup = async () => {
        await sellerPage.getByRole('link', { name: /setup/i }).first().click()
        await expect(sellerPage.getByRole('heading', { name: /^setup$/i })).toBeVisible({
          timeout: 20_000,
        })
      }

      // The shipping-box requirement starts outstanding: a new seller has
      // recorded nothing to ship in.
      await goToSetup()
      await expect(sellerPage.getByText(/shipping box/i).first()).toBeVisible({ timeout: 20_000 })

      // Recording it: the page is reachable from settings, and a fully
      // measured default box is what the requirement asks for.
      await sellerPage
        .getByRole('link', { name: /^settings$/i })
        .first()
        .click()
      await sellerPage
        .getByRole('link', { name: /package types/i })
        .first()
        .click()
      await expect(sellerPage.getByRole('button', { name: /add package type/i })).toBeVisible({
        timeout: 20_000,
      })

      await sellerPage.getByRole('button', { name: /add package type/i }).click()
      await sellerPage.locator('#package-type-name').fill(boxName)
      await sellerPage.locator('#package-type-length').fill('30')
      await sellerPage.locator('#package-type-width').fill('20')
      await sellerPage.locator('#package-type-height').fill('15')
      await sellerPage.locator('#package-type-weight').fill('0.4')
      // A Switch renders as role=switch; the id is on the control, not a
      // clickable input.
      await sellerPage.getByRole('switch', { name: /default box/i }).click()
      await sellerPage.getByRole('button', { name: /^save$/i }).click()

      // It is the seller's own row afterwards, marked as their default.
      await expect(sellerPage.getByText(boxName)).toBeVisible({ timeout: 20_000 })

      // Which is what turns the requirement complete — the same evaluator the
      // operator reads, so this is the whole point of the feature.
      //
      // Reloaded rather than navigated: the checklist was fetched before the
      // box existed, and the packaging page has no reason to invalidate
      // another page's query, so clicking back to it would assert against the
      // cached answer.
      await goToSetup()
      await sellerPage.reload()
      await expect(sellerPage.getByRole('heading', { name: /^setup$/i })).toBeVisible({
        timeout: 20_000,
      })
      await expect(sellerPage.getByText(/1 of 7 done/i)).toBeVisible({ timeout: 20_000 })
    } finally {
      await context.close()
    }
  })
})
