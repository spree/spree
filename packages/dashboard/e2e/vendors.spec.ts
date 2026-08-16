import { expect, type Page, test } from '@playwright/test'
import { escapeRegex, gotoIndex, login, openRowMenu } from './helpers'

const VENDORS_PATH = (storeId: string) => `/${storeId}/vendors`
const CTA = /add vendor/i

/** The vendor name cell is a link to the detail page, not a sheet trigger. */
function rowLink(page: Page, name: string) {
  return page.getByRole('link', { name: new RegExp(`^${escapeRegex(name)}$`) })
}

/** Scopes an Edit button to its own card — the page has more than one. */
function cardEdit(page: Page, title: RegExp) {
  return page
    .locator('[data-slot="card"]')
    .filter({ has: page.getByText(title) })
    .getByRole('button', { name: /^edit$/i })
}

/** Creating a vendor lands on its profile page. */
async function createVendor(page: Page, name: string) {
  await page.getByRole('button', { name: CTA }).click()
  await expect(page.getByRole('heading', { name: /new vendor/i })).toBeVisible()

  await page.locator('#name').fill(name)
  await page.getByRole('button', { name: /create vendor/i }).click()

  await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
}

test.describe('vendors', () => {
  test('lists vendors', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, VENDORS_PATH(creds.store_id), CTA)
  })

  // The page is a profile you read, not a form you land in.
  test('shows the profile without dropping into an edit form', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, VENDORS_PATH(creds.store_id), CTA)

    const name = `E2E Vendor ${Date.now()}`
    await createVendor(page, name)

    await expect(page.getByText(/^pending$/i).first()).toBeVisible()
    await expect(page.getByText(/at a glance/i)).toBeVisible()
    // Nothing is editable until an Edit button is pressed.
    await expect(page.locator('#vendor-name')).toHaveCount(0)
    await expect(page.locator('#minimum_payout_amount')).toHaveCount(0)

    // Nobody has been invited yet, so inviting is the only move offered.
    await expect(page.getByRole('button', { name: /^invite$/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /^approve$/i })).toHaveCount(0)
  })

  test('shows placeholders for details the vendor has not filled in', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, VENDORS_PATH(creds.store_id), CTA)

    await createVendor(page, `E2E Blank Vendor ${Date.now()}`)

    await expect(page.getByText(/has not written a description/i)).toBeVisible()
    await expect(page.getByText(/not provided/i).first()).toBeVisible()
  })

  test('invites someone to run the vendor', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, VENDORS_PATH(creds.store_id), CTA)

    const name = `E2E Invite Vendor ${Date.now()}`
    await createVendor(page, name)

    await page.getByRole('button', { name: /^invite$/i }).click()
    await expect(page.getByRole('heading', { name: /invite vendor/i })).toBeVisible()

    await page.locator('#invite-email').fill(`seller-${Date.now()}@example.com`)
    await page.getByRole('button', { name: /send invitation/i }).click()

    await expect(page.getByText(/^invited$/i).first()).toBeVisible({ timeout: 15_000 })
    // Re-inviting stays available; a vendor waiting to accept can be chased.
    await expect(page.getByRole('button', { name: /send again/i })).toBeVisible()
  })

  test('edits the profile through its sheet', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, VENDORS_PATH(creds.store_id), CTA)

    const name = `E2E Profile Vendor ${Date.now()}`
    await createVendor(page, name)

    await page
      .getByRole('button', { name: /^edit$/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /edit profile/i })).toBeVisible()

    await page.locator('#vendor-contact-email').fill('updated@example.com')
    await page.getByRole('button', { name: /^save$/i }).click()

    // Back to the read view, showing the new value.
    await expect(page.getByRole('heading', { name: /edit profile/i })).toHaveCount(0, {
      timeout: 15_000,
    })
    await expect(page.getByText('updated@example.com').first()).toBeVisible({ timeout: 15_000 })
  })

  test('edits the payout settings through their own sheet', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, VENDORS_PATH(creds.store_id), CTA)

    const name = `E2E Payout Vendor ${Date.now()}`
    await createVendor(page, name)

    await cardEdit(page, /payouts and tax/i).click()
    await expect(page.getByRole('heading', { name: /edit payouts and tax/i })).toBeVisible()

    await page.locator('#payouts_schedule_interval').click()
    await page.getByRole('option', { name: /^weekly$/i }).click()
    await page.locator('#minimum_payout_amount').fill('25.0')
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByRole('heading', { name: /edit payouts and tax/i })).toHaveCount(0, {
      timeout: 15_000,
    })
    await expect(page.getByText(/^weekly$/i).first()).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText('25.0')).toBeVisible()
  })

  // Each sheet sends only its own fields, so saving one must not roll back
  // what the other just wrote.
  test('saving the profile leaves the payout settings alone', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, VENDORS_PATH(creds.store_id), CTA)

    const name = `E2E Isolation Vendor ${Date.now()}`
    await createVendor(page, name)

    await cardEdit(page, /payouts and tax/i).click()
    await page.locator('#minimum_payout_amount').fill('40.0')
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText('40.0')).toBeVisible({ timeout: 15_000 })

    await page
      .getByRole('button', { name: /^edit$/i })
      .first()
      .click()
    await page.locator('#vendor-billing-email').fill('billing@example.com')
    await page.getByRole('button', { name: /^save$/i }).click()

    await page.reload()
    await expect(page.getByText('billing@example.com').first()).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText('40.0')).toBeVisible()
  })

  test('deletes a vendor from the list', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, VENDORS_PATH(creds.store_id), CTA)

    const name = `E2E Delete Vendor ${Date.now()}`
    await createVendor(page, name)

    await page.goto(VENDORS_PATH(creds.store_id))
    await expect(rowLink(page, name)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete vendor\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowLink(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
