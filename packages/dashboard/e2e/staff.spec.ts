import { expect, type Page, request, test } from '@playwright/test'
import {
  type E2ELoginSession,
  escapeRegex,
  invitationAcceptancePath,
  login,
  openRowMenu,
} from './helpers'

const STAFF_PATH = (storeId: string) => `/${storeId}/settings/staff`

async function inviteFromDialog(page: Page, email: string) {
  await page.getByRole('button', { name: /invite teammate/i }).click()
  await page.locator('#invite-email').fill(email)
  await page.locator('#invite-role').click()
  await page.getByRole('option').first().click()
  await page.getByRole('button', { name: /send invitation/i }).click()
  await expect(page.getByRole('row').filter({ hasText: email })).toBeVisible({ timeout: 15_000 })
}

/**
 * Puts a second teammate on the store through the API: an invitation, then
 * its acceptance. Accepting signs the invitee in, so it happens in a request
 * context of its own — sharing the page's would swap the admin's session
 * cookie for the invitee's.
 */
async function addTeammate(page: Page, session: E2ELoginSession, email: string) {
  const headers = { Authorization: `Bearer ${session.accessToken}` }
  const roles = await page.request.get('/api/v3/admin/roles', { headers }).then((res) => res.json())
  const created = await page.request.post('/api/v3/admin/invitations', {
    headers,
    data: { email, role_id: roles.data[0].id },
  })
  expect(created.status(), await created.text()).toBe(201)
  const invitation = (await created.json()) as { id: string }

  const acceptance = new URL(
    await invitationAcceptancePath(page, session, `/api/v3/admin/invitations/${invitation.id}`),
    'http://localhost',
  )
  const invitee = await request.newContext({ baseURL: new URL(page.url()).origin })
  try {
    const accepted = await invitee.post(`/api/v3/admin/auth/invitations/${invitation.id}/accept`, {
      data: {
        token: acceptance.searchParams.get('token'),
        password: 'e2e-password-123',
        password_confirmation: 'e2e-password-123',
        first_name: 'Robin',
        last_name: 'Teammate',
      },
    })
    expect(accepted.ok(), await accepted.text()).toBeTruthy()
  } finally {
    await invitee.dispose()
  }
}

test.describe('staff', () => {
  test('lists the signed-in admin as a member', async ({ page }) => {
    const creds = await login(page)
    await page.goto(STAFF_PATH(creds.store_id))

    await expect(
      page.getByRole('row', { name: new RegExp(escapeRegex(creds.admin_email), 'i') }),
    ).toBeVisible({ timeout: 15_000 })
  })

  test('an invitation needs a role', async ({ page }) => {
    const creds = await login(page)
    await page.goto(STAFF_PATH(creds.store_id))

    await page.getByRole('button', { name: /invite teammate/i }).click()
    await page.locator('#invite-email').fill(`e2e-no-role-${Date.now()}@example.com`)
    await page.getByRole('button', { name: /send invitation/i }).click()

    await expect(page.getByRole('alert').filter({ hasText: /pick a role/i })).toBeVisible()
  })

  test('resends a pending invitation', async ({ page }) => {
    const creds = await login(page)
    await page.goto(STAFF_PATH(creds.store_id))

    const email = `e2e-resend-${Date.now()}@example.com`
    await inviteFromDialog(page, email)

    await openRowMenu(page, email)
    await page.getByRole('menuitem', { name: /^resend$/i }).click()
    await expect(page.getByText(/invitation resent/i)).toBeVisible({ timeout: 15_000 })
  })

  test('revokes a pending invitation after confirming', async ({ page }) => {
    const creds = await login(page)
    await page.goto(STAFF_PATH(creds.store_id))

    const email = `e2e-revoke-${Date.now()}@example.com`
    await inviteFromDialog(page, email)

    await openRowMenu(page, email)
    await page.getByRole('menuitem', { name: /^revoke$/i }).click()
    await expect(page.getByRole('heading', { name: /revoke invitation\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^revoke$/i })
      .click()

    await expect(page.getByRole('row').filter({ hasText: email })).toHaveCount(0, {
      timeout: 15_000,
    })
  })

  test('renames a teammate and then removes them from the store', async ({ page }) => {
    const session = await login(page)
    const email = `e2e-teammate-${Date.now()}@example.com`
    await addTeammate(page, session, email)

    await page.goto(STAFF_PATH(session.store_id))
    await expect(page.getByRole('row').filter({ hasText: email })).toBeVisible({
      timeout: 15_000,
    })

    await openRowMenu(page, email)
    await page.getByRole('menuitem', { name: /^edit$/i }).click()
    await page.locator('#staff-first-name').fill('Morgan')
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(
      page
        .getByRole('row')
        .filter({ hasText: email })
        .getByText(/morgan/i),
    ).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, email)
    await page.getByRole('menuitem', { name: /remove from staff/i }).click()
    await expect(page.getByRole('heading', { name: /remove from store\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^remove$/i })
      .click()

    await expect(page.getByRole('row').filter({ hasText: email })).toHaveCount(0, {
      timeout: 15_000,
    })
  })
})
