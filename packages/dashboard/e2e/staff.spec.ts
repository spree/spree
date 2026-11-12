import { expect, type Page, request, test } from '@playwright/test'
import {
  adminRequest,
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
async function addTeammate(page: Page, session: E2ELoginSession, email: string, roleId?: string) {
  const headers = { Authorization: `Bearer ${session.accessToken}` }
  const roles = await page.request.get('/api/v3/admin/roles', { headers }).then((res) => res.json())
  const created = await page.request.post('/api/v3/admin/invitations', {
    headers,
    data: { email, role_id: roleId ?? roles.data[0].id },
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

  // Accepting the invitation signs the teammate in, so the sheet has a
  // session to list as well as who sent the invitation.
  test("shows a teammate's status, inviter and sessions", async ({ page }) => {
    const session = await login(page)
    const email = `e2e-details-${Date.now()}@example.com`
    await addTeammate(page, session, email)
    const staff = await adminRequest<{
      data: Array<{ email: string; full_name: string | null }>
    }>(page, session, 'get', '/admin_users')
    const admin = staff.data.find((user) => user.email === session.admin_email)
    const inviterLabel = admin?.full_name || session.admin_email

    await page.goto(STAFF_PATH(session.store_id))
    const row = page.getByRole('row').filter({ hasText: email })
    await expect(row.getByText(/^active$/i)).toBeVisible({ timeout: 15_000 })
    await expect(row.getByText(/ago$/)).toBeVisible()

    await openRowMenu(page, email)
    await page.getByRole('menuitem', { name: /view details/i }).click()

    const sheet = page.getByRole('dialog')
    await expect(sheet.getByRole('heading', { name: /robin teammate/i })).toBeVisible()
    await expect(sheet.getByText(new RegExp(escapeRegex(inviterLabel), 'i'))).toBeVisible({
      timeout: 15_000,
    })
    const sessions = sheet.getByRole('listitem')
    await expect(sessions).toHaveCount(1)
    await expect(sessions.getByText(/ago$/)).toBeVisible()
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

  // Every teammate reads the store's markets and channels — the dashboard's
  // currencies and languages come from the markets — while the settings pages
  // that change them stay with the roles that may.
  test('a teammate limited to orders gets market currencies but no settings', async ({
    page,
    browser,
  }) => {
    const session = await login(page)
    const role = await adminRequest<{ id: string }>(page, session, 'post', '/roles', {
      name: `E2E Orders Only ${Date.now()}`,
      permissions: ['read_orders'],
    })
    const email = `e2e-orders-only-${Date.now()}@example.com`
    await addTeammate(page, session, email, role.id)

    const context = await browser.newContext({ baseURL: new URL(page.url()).origin })
    try {
      const teammate = await context.newPage()
      await login(teammate, { email, password: 'e2e-password-123' })
      await teammate.goto(`/${session.store_id}/orders`)
      // The Orders link only renders once the teammate's permissions have
      // loaded, so the Settings check below cannot pass on an empty sidebar.
      await expect(teammate.getByRole('link', { name: /^orders$/i })).toBeVisible({
        timeout: 15_000,
      })
      await expect(teammate.getByRole('link', { name: /^settings$/i })).toHaveCount(0)

      await teammate.getByRole('button', { name: /add filter/i }).click()
      await teammate
        .locator('[data-slot="filter-panel-item"]')
        .getByText(/^currency$/i)
        .click()
      await expect(teammate.getByRole('button', { name: /^USD$/ })).toBeVisible()
      await expect(teammate.getByRole('button', { name: /^EUR$/ })).toBeVisible()
    } finally {
      await context.close()
    }
  })
})
