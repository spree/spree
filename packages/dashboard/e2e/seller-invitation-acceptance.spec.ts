import { expect, type Page, test } from '@playwright/test'
import {
  adminRequest,
  deleteSeededRecords,
  type E2ELoginSession,
  escapeRegex,
  FIXTURE_SELLER_USER_EMAIL,
  invitationAcceptancePath,
  login,
  SELLER_PANEL,
  seedRecord,
  sellerLogin,
} from './helpers'

// The seller panel is its own app on its own origin (see playwright.config.ts),
// so this spec drives two: the operator's dashboard through `baseURL`, and the
// panel by absolute URL.

/** A new seller with one pending invitation, and the panel link that accepts it. */
async function inviteToNewSeller(page: Page, session: E2ELoginSession, email: string) {
  const seller = await seedRecord(page, session, '/sellers', {
    name: `E2E Seller ${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
  })
  await adminRequest(page, session, 'post', `/sellers/${seller.id}/invite`, { email })
  const { data } = await adminRequest<{ data: { id: string }[] }>(
    page,
    session,
    'get',
    `/sellers/${seller.id}/invitations`,
  )
  const path = await invitationAcceptancePath(
    page,
    session,
    `/api/v3/admin/sellers/${seller.id}/invitations/${data[0].id}`,
  )
  return { seller, invitationId: data[0].id, url: `${SELLER_PANEL}${path}` }
}

test.describe('seller invitation lifecycle', () => {
  test.afterEach(async ({ page }) => {
    await deleteSeededRecords(page)
  })

  test('someone signed in as another seller account is asked to sign out', async ({
    page,
    browser,
  }) => {
    const session = await login(page)
    const inviteeEmail = `e2e-seller-invitee-${Date.now()}@example.com`
    const { url } = await inviteToNewSeller(page, session, inviteeEmail)

    const panelContext = await browser.newContext()
    const panel = await panelContext.newPage()
    try {
      await sellerLogin(panel)
      await panel.goto(url)
      await expect(
        panel.getByText(new RegExp(`signed in as ${escapeRegex(FIXTURE_SELLER_USER_EMAIL)}`, 'i')),
      ).toBeVisible({ timeout: 20_000 })

      await panel.getByRole('button', { name: /sign out/i }).click()
      await expect(panel.getByLabel(/email/i)).toHaveValue(inviteeEmail, { timeout: 20_000 })
      await expect(panel.getByRole('button', { name: /create account & accept/i })).toBeVisible()
    } finally {
      await panelContext.close()
    }
  })

  test('someone signed in as the invited account accepts with one click', async ({
    page,
    browser,
  }) => {
    const session = await login(page)
    const email = `e2e-seller-returning-${Date.now()}@example.com`
    const first = await inviteToNewSeller(page, session, email)

    const panelContext = await browser.newContext()
    const panel = await panelContext.newPage()
    try {
      // An account that already runs one seller, signed in to the panel:
      // accepting through the API plants its session cookie.
      const accepted = await panel.request.post(
        `${SELLER_PANEL}/api/v3/seller/auth/invitations/${first.invitationId}/accept`,
        {
          data: {
            token: new URL(first.url).searchParams.get('token'),
            password: 'e2e-password-123',
            password_confirmation: 'e2e-password-123',
            first_name: 'Robin',
            last_name: 'Returning',
          },
        },
      )
      expect(accepted.ok(), await accepted.text()).toBeTruthy()

      const second = await inviteToNewSeller(page, session, email)
      await panel.goto(second.url)
      await expect(
        panel.getByText(new RegExp(`signed in as ${escapeRegex(email)}`, 'i')),
      ).toBeVisible({ timeout: 20_000 })
      await expect(panel.getByLabel(/password/i)).toHaveCount(0)

      await panel.getByRole('button', { name: /^accept invitation$/i }).click()
      await expect(panel).toHaveURL(new RegExp(`/${second.seller.id}$`), { timeout: 20_000 })
      await expect(panel.getByText(/selling/i).first()).toBeVisible({ timeout: 20_000 })
    } finally {
      await panelContext.close()
    }
  })

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
    // than shown, so no DOM signal carries it. The new invitation's id comes
    // off the team card's own refetch; its link is then fetched with the
    // login's access token.
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

    const { data } = (await listResponse.json()) as { data: Array<{ id: string }> }
    const acceptancePath = await invitationAcceptancePath(
      page,
      creds,
      `${new URL(listResponse.url()).pathname}/${data[0].id}`,
    )
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

      // The settings rail is shared from dashboard-core, whose strings the
      // panel has to carry too — keys defined only in the operator's bundle
      // render as their own name here.
      await inviteePage.goto(`${SELLER_PANEL}${new URL(inviteePage.url()).pathname}/settings`)
      await expect(inviteePage.getByRole('heading', { name: /^settings$/i })).toBeVisible({
        timeout: 20_000,
      })
      await expect(inviteePage.getByText(/admin\.settings_page/)).toHaveCount(0)
    } finally {
      await inviteeContext.close()
    }
  })
})
