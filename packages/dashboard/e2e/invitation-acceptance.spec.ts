import { expect, test } from '@playwright/test'
import {
  adminApiSession,
  adminRequest,
  escapeRegex,
  invitationAcceptancePath,
  login,
} from './helpers'

test.describe('invitation lifecycle', () => {
  test('admin invites a teammate and the invitee signs up via the link', async ({
    page,
    browser,
  }) => {
    const creds = await login(page)
    const inviteeEmail = `e2e-invitee-${Date.now()}@example.com`

    await page.goto(`/${creds.store_id}/settings/staff`)
    await expect(page.getByText(/^staff$/i).first()).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /invite teammate/i }).click()
    await expect(page.getByText(/invite teammate/i).first()).toBeVisible()

    await page.getByLabel(/email/i).fill(inviteeEmail)
    await page.getByLabel(/role/i).click()
    await page.getByRole('option').first().click()

    // API wait justified per CLAUDE.md: the acceptance link is normally
    // emailed, and the copy action puts it on the clipboard, so there's no DOM
    // signal to pull it from.
    const [createResponse] = await Promise.all([
      page.waitForResponse(
        (res) =>
          res.url().includes('/api/v3/admin/invitations') &&
          res.request().method() === 'POST' &&
          res.status() === 201,
        { timeout: 15_000 },
      ),
      page.getByRole('button', { name: /send invitation/i }).click(),
    ])
    const invitation = (await createResponse.json()) as { id: string }
    const acceptancePath = await invitationAcceptancePath(
      page,
      creds,
      `/api/v3/admin/invitations/${invitation.id}`,
    )
    expect(acceptancePath).toMatch(/\/accept-invitation\//)

    await page.getByRole('button', { name: /user menu/i }).click()
    await page.getByRole('menuitem', { name: /log out/i }).click()
    await expect(page).toHaveURL(/\/login/, { timeout: 15_000 })

    // Fresh context so the admin's refresh cookie doesn't leak into the invitee session.
    const inviteeContext = await browser.newContext()
    const inviteePage = await inviteeContext.newPage()
    try {
      await inviteePage.goto(acceptancePath)
      await expect(inviteePage.getByText(new RegExp(`join ${creds.store_name}`, 'i'))).toBeVisible({
        timeout: 15_000,
      })
      await expect(inviteePage.getByLabel(/email/i)).toHaveValue(inviteeEmail)

      await inviteePage.getByLabel(/first name/i).fill('Pat')
      await inviteePage.getByLabel(/last name/i).fill('Carlson')
      await inviteePage.getByLabel(/^password$/i).fill('e2e-password-123')
      await inviteePage.getByLabel(/confirm password/i).fill('e2e-password-123')
      await inviteePage.getByRole('button', { name: /create account & accept/i }).click()

      await expect(inviteePage).not.toHaveURL(/\/login/, { timeout: 15_000 })
      await expect(inviteePage).not.toHaveURL(/\/accept-invitation/, { timeout: 15_000 })
    } finally {
      await inviteeContext.close()
    }
  })

  test('someone signed in as another account is asked to sign out instead of being redirected', async ({
    page,
  }) => {
    const session = await login(page)
    const inviteeEmail = `e2e-invitee-${Date.now()}@example.com`
    const roles = await adminRequest<{ data: { id: string }[] }>(page, session, 'get', '/roles')
    const invitation = await adminRequest<{ id: string }>(page, session, 'post', '/invitations', {
      email: inviteeEmail,
      role_id: roles.data[0].id,
    })
    const acceptancePath = await invitationAcceptancePath(
      page,
      session,
      `/api/v3/admin/invitations/${invitation.id}`,
    )

    await page.goto(acceptancePath)
    await expect(
      page.getByText(new RegExp(`signed in as ${escapeRegex(session.admin_email)}`, 'i')),
    ).toBeVisible({
      timeout: 15_000,
    })
    await expect(page).toHaveURL(/\/accept-invitation\//)

    await page.getByRole('button', { name: /sign out/i }).click()
    await expect(page.getByLabel(/email/i)).toHaveValue(inviteeEmail, { timeout: 15_000 })
    await expect(page.getByRole('button', { name: /create account & accept/i })).toBeVisible()

    await adminRequest(page, await adminApiSession(page), 'delete', `/invitations/${invitation.id}`)
  })

  test('someone signed in as the invited account accepts with one click', async ({
    page,
    browser,
  }) => {
    const session = await login(page)
    const email = `e2e-returning-${Date.now()}@example.com`
    const roles = await adminRequest<{ data: { id: string }[] }>(page, session, 'get', '/roles')
    const invite = async () => {
      const invitation = await adminRequest<{ id: string }>(page, session, 'post', '/invitations', {
        email,
        role_id: roles.data[0].id,
      })
      const path = await invitationAcceptancePath(
        page,
        session,
        `/api/v3/admin/invitations/${invitation.id}`,
      )
      return { id: invitation.id, path }
    }

    const inviteeContext = await browser.newContext()
    const inviteePage = await inviteeContext.newPage()
    try {
      // An account that left the store: it exists and is signed in, but holds
      // no role here. Accepting through the API plants its session cookie.
      const first = await invite()
      const accepted = await inviteePage.request.post(
        `/api/v3/admin/auth/invitations/${first.id}/accept`,
        {
          data: {
            token: new URL(first.path, 'http://localhost').searchParams.get('token'),
            password: 'e2e-password-123',
            password_confirmation: 'e2e-password-123',
          },
        },
      )
      expect(accepted.ok(), await accepted.text()).toBeTruthy()
      const { user } = (await accepted.json()) as { user: { id: string } }
      await adminRequest(page, session, 'delete', `/admin_users/${user.id}`)

      const second = await invite()
      await inviteePage.goto(second.path)
      await expect(
        inviteePage.getByText(new RegExp(`signed in as ${escapeRegex(email)}`, 'i')),
      ).toBeVisible({
        timeout: 15_000,
      })
      await expect(inviteePage.getByLabel(/password/i)).toHaveCount(0)

      await inviteePage.getByRole('button', { name: /^accept invitation$/i }).click()
      await expect(inviteePage).toHaveURL(new RegExp(`/${session.store_id}`), { timeout: 15_000 })
      // Permissions fetched before the role existed would leave the sidebar bare.
      await expect(inviteePage.getByRole('link', { name: /^products$/i })).toBeVisible({
        timeout: 15_000,
      })
    } finally {
      await inviteeContext.close()
    }
  })

  test('shows an error for an invalid token', async ({ page }) => {
    await page.goto('/accept-invitation/inv_doesnotexist?token=bogus-token-here')
    await expect(page.getByText(/invitation not found/i)).toBeVisible({ timeout: 15_000 })
  })
})
