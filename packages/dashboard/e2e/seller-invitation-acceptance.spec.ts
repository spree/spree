import { expect, test } from '@playwright/test'
import { login } from './helpers'

// The seller panel is its own app on its own origin (see playwright.config.ts),
// so this spec drives two: the operator's dashboard through `baseURL`, and the
// panel by absolute URL.
const SELLER_PANEL = `http://localhost:${process.env.E2E_SELLER_VITE_PORT || '5175'}`

test.describe('seller invitation lifecycle', () => {
  test('an invited seller accepts and lands in their own panel', async ({ page, browser }) => {
    const creds = await login(page)
    const suffix = Date.now()
    const sellerName = `E2E Seller ${suffix}`
    const inviteeEmail = `e2e-seller-${suffix}@example.com`

    await page.goto(`/${creds.store_id}/sellers`)
    await page.getByRole('button', { name: /add seller/i }).click()
    await page.locator('#name').fill(sellerName)
    await page.getByRole('button', { name: /create seller/i }).click()
    await expect(page.getByRole('heading', { name: sellerName })).toBeVisible({ timeout: 15_000 })

    await page
      .getByRole('button', { name: /invite/i })
      .first()
      .click()
    await page.locator('#invite-email').fill(inviteeEmail)

    // API wait justified per CLAUDE.md: the acceptance link is emailed rather
    // than shown, so no DOM signal carries it. Read off the team card's own
    // refetch, which the SPA makes with its access token — a bare
    // `page.request` call carries no session, since the token is held in
    // memory rather than in a cookie.
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

    // The invitation appears on the seller's team card once it is sent.
    await expect(page.getByText(inviteeEmail)).toBeVisible({ timeout: 15_000 })

    const { data } = (await listResponse.json()) as { data: Array<{ acceptance_url: string }> }
    const acceptancePath = data[0].acceptance_url.replace(/^https?:\/\/[^/]+/, '')
    expect(acceptancePath).toMatch(/\/accept-invitation\//)

    // A fresh context so the operator's refresh cookie never reaches the panel.
    const inviteeContext = await browser.newContext()
    const inviteePage = await inviteeContext.newPage()
    try {
      await inviteePage.goto(`${SELLER_PANEL}${acceptancePath}`)
      await expect(inviteePage.getByLabel(/^password$/i)).toBeVisible({ timeout: 20_000 })

      await inviteePage.getByLabel(/first name/i).fill('Pat')
      await inviteePage.getByLabel(/last name/i).fill('Carlson')
      await inviteePage.getByLabel(/^password$/i).fill('e2e-password-123')
      await inviteePage.getByLabel(/confirm password/i).fill('e2e-password-123')
      await inviteePage.getByRole('button', { name: /accept|create account|join/i }).click()

      // Accepting signs them in and leaves the invitation page on its own —
      // without that, the form sits there and the obvious next move is to
      // submit again, against an invitation that has now been consumed.
      await expect(inviteePage).not.toHaveURL(/accept-invitation/, { timeout: 20_000 })

      // And the panel is usable. Asserted on the home page's own content
      // rather than the seller's name in the sidebar: that name comes from the
      // session payload and renders even when every request is refused, which
      // is exactly what a role carrying no permission keys looks like.
      await expect(inviteePage.getByText(/selling/i).first()).toBeVisible({ timeout: 20_000 })
      await expect(inviteePage.getByText(/something went wrong/i)).toHaveCount(0)
    } finally {
      await inviteeContext.close()
    }
  })
})
