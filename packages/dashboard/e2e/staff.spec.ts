import { resolve } from 'node:path'
import { expect, type Page, test } from '@playwright/test'
import {
  addTeammate,
  adminRequest,
  escapeRegex,
  login,
  openRowMenu,
  TEAMMATE_PASSWORD,
} from './helpers'
import { API_GEM_DIR, runRailsBootstrap } from './rails'

const railsEnv = {
  ...process.env,
  RAILS_ENV: 'test',
  DATABASE_URL: `sqlite3:${resolve(API_GEM_DIR, 'spec/dummy/db/spree_test_e2e.sqlite3')}`,
}

// Moves an invitation's expiry, standing in for the days that pass between
// sending it and pressing Resend.
function setInvitationExpiry(email: string, rubyTime: string) {
  runRailsBootstrap(
    `Spree::Invitation.find_by!(email: '${email}').update_columns(expires_at: ${rubyTime})
    puts({ ok: true }.to_json)`,
    railsEnv,
  )
}

const STAFF_PATH = (storeId: string) => `/${storeId}/settings/staff`

async function inviteFromDialog(page: Page, email: string) {
  await page.getByRole('button', { name: /invite teammate/i }).click()
  await page.locator('#invite-email').fill(email)
  await page.locator('#invite-role').click()
  await page.getByRole('option').first().click()
  await page.getByRole('button', { name: /send invitation/i }).click()
  await expect(page.getByRole('row').filter({ hasText: email })).toBeVisible({ timeout: 15_000 })
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

    setInvitationExpiry(email, '1.hour.from_now')
    await page.reload()
    const row = page.getByRole('row').filter({ hasText: email })
    await expect(row.getByText(/in about 1 hour/i)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, email)
    await page.getByRole('menuitem', { name: /^resend$/i }).click()
    await expect(page.getByText(/invitation resent/i)).toBeVisible({ timeout: 15_000 })
    await expect(row.getByText(/in 14 days/i)).toBeVisible({ timeout: 15_000 })
  })

  test('refuses to resend an expired invitation and says why', async ({ page }) => {
    const creds = await login(page)
    await page.goto(STAFF_PATH(creds.store_id))

    const email = `e2e-resend-expired-${Date.now()}@example.com`
    await inviteFromDialog(page, email)
    setInvitationExpiry(email, '1.hour.ago')
    await page.reload()

    await openRowMenu(page, email)
    await page.getByRole('menuitem', { name: /^resend$/i }).click()
    await expect(page.getByText(/this invitation has expired/i)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(/invitation resent/i)).toHaveCount(0)
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
      await login(teammate, { email, password: TEAMMATE_PASSWORD })
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
