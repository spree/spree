import { expect, test } from '@playwright/test'
import { login } from './helpers'

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

    // API wait justified per CLAUDE.md: `acceptance_url` is normally
    // emailed, not surfaced in the admin UI, so there's no DOM signal to
    // pull the link from.
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
    const invitation = (await createResponse.json()) as { acceptance_url: string }
    expect(invitation.acceptance_url).toMatch(/\/accept-invitation\//)
    // Tolerate either path-only (test env, admin_url unset) or absolute URL.
    const acceptancePath = invitation.acceptance_url.replace(/^https?:\/\/[^/]+/, '')

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

  test('shows an error for an invalid token', async ({ page }) => {
    await page.goto('/accept-invitation/inv_doesnotexist?token=bogus-token-here')
    await expect(page.getByText(/invitation not found/i)).toBeVisible({ timeout: 15_000 })
  })
})
