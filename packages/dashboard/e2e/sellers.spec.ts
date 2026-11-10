import { expect, type Page, test } from '@playwright/test'
import {
  escapeRegex,
  FIXTURE_LEDGER_RETURNS_LOCATION,
  FIXTURE_LEDGER_SELLER,
  gotoIndex,
  login,
  openRowMenu,
  saveCustomFieldOnCard,
  withCustomFieldDefinition,
} from './helpers'

const SELLERS_PATH = (storeId: string) => `/${storeId}/sellers`
const CTA = /add seller/i

/** The seller name cell is a link to the detail page, not a sheet trigger. */
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

/** Creating a seller lands on its profile page. */
async function createSeller(page: Page, name: string) {
  await page.getByRole('button', { name: CTA }).click()
  await expect(page.getByRole('heading', { name: /new seller/i })).toBeVisible()

  await page.locator('#name').fill(name)
  await page.getByRole('button', { name: /create seller/i }).click()

  await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
}

test.describe('sellers', () => {
  test('lists sellers', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)
  })

  test('back from a new seller lands on the list', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    const name = `E2E Back Seller ${Date.now()}`
    await page.getByRole('button', { name: CTA }).click()
    await page.locator('#name').fill(name)
    await page.getByRole('button', { name: /create seller/i }).click()
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /^back$/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/sellers(?:\\?|$)`), {
      timeout: 15_000,
    })
    await expect(page.getByRole('heading', { name: /new seller/i })).toHaveCount(0)
    await expect(rowLink(page, name)).toBeVisible({ timeout: 15_000 })
  })

  // The page is a profile you read, not a form you land in.
  test('shows the profile without dropping into an edit form', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    const name = `E2E Seller ${Date.now()}`
    await createSeller(page, name)

    await expect(page.getByText(/^pending$/i).first()).toBeVisible()
    await expect(page.getByText(/at a glance/i)).toBeVisible()
    // Nothing is editable until an Edit button is pressed.
    await expect(page.locator('#seller-name')).toHaveCount(0)
    await expect(page.locator('#minimum_payout_amount')).toHaveCount(0)

    // Nobody has been invited yet, so inviting is the only move offered. The
    // team card offers its own Invite, so this names the header's.
    await expect(page.getByRole('button', { name: /^invite$/i }).first()).toBeVisible()
    await expect(page.getByRole('button', { name: /^approve$/i })).toHaveCount(0)
  })

  test('shows placeholders for details the seller has not filled in', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    await createSeller(page, `E2E Blank Seller ${Date.now()}`)

    await expect(page.getByText(/has not written a description/i)).toBeVisible()
    await expect(page.getByText(/not provided/i).first()).toBeVisible()
  })

  test('invites someone to run the seller', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    const name = `E2E Invite Seller ${Date.now()}`
    await createSeller(page, name)

    await page
      .getByRole('button', { name: /^invite$/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /invite seller/i })).toBeVisible()

    await page.locator('#invite-email').fill(`seller-${Date.now()}@example.com`)
    await page.getByRole('button', { name: /send invitation/i }).click()

    await expect(page.getByText(/^invited$/i).first()).toBeVisible({ timeout: 15_000 })
    // Re-inviting stays available; a seller waiting to accept can be chased.
    await expect(page.getByRole('button', { name: /send again/i })).toBeVisible()
  })

  test('edits the profile through its sheet', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    const name = `E2E Profile Seller ${Date.now()}`
    await createSeller(page, name)

    await page
      .getByRole('button', { name: /^edit$/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /edit profile/i })).toBeVisible()
    // The emails belong to the contact card's own sheet.
    await expect(page.locator('#seller-contact-email')).toHaveCount(0)

    const renamed = `${name} Renamed`
    await page.locator('#seller-name').fill(renamed)
    await page.getByRole('button', { name: /^save$/i }).click()

    // Back to the read view, showing the new value.
    await expect(page.getByRole('heading', { name: /edit profile/i })).toHaveCount(0, {
      timeout: 15_000,
    })
    await expect(page.getByRole('heading', { name: renamed }).first()).toBeVisible({
      timeout: 15_000,
    })
  })

  test('edits the contact details through their own sheet', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    await createSeller(page, `E2E Contact Seller ${Date.now()}`)

    await cardEdit(page, /^contact$/i)
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /edit contact/i })).toBeVisible()
    // Only the contact fields: the profile has its own sheet.
    await expect(page.locator('#seller-name')).toHaveCount(0)

    await page.locator('#seller-contact-email').fill('updated@example.com')
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByRole('heading', { name: /edit contact/i })).toHaveCount(0, {
      timeout: 15_000,
    })
    await expect(page.getByText('updated@example.com').first()).toBeVisible({ timeout: 15_000 })
  })

  test("opens the seller's stock locations from their page", async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)
    await rowLink(page, FIXTURE_LEDGER_SELLER).click()

    await page
      .locator('[data-slot="card"]')
      .filter({ hasText: /at a glance/i })
      .getByRole('link', { name: /^view$/i })
      .click()

    await expect(page).toHaveURL(/settings\/stock-locations\?.*view=sellers/)
    await expect(page.getByRole('tab', { name: /^sellers' locations$/i })).toHaveAttribute(
      'aria-selected',
      'true',
      { timeout: 15_000 },
    )
    await expect(page.getByRole('button', { name: FIXTURE_LEDGER_RETURNS_LOCATION })).toBeVisible({
      timeout: 15_000,
    })
    // Narrowed to this seller: every row names them.
    for (const row of await page
      .getByRole('row')
      .filter({ has: page.locator('td') })
      .all()) {
      await expect(row).toContainText(FIXTURE_LEDGER_SELLER)
    }
  })

  test('opens the stock location a returns address comes from', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)
    await rowLink(page, FIXTURE_LEDGER_SELLER).click()

    // The returns address is the location's own, so its edit opens that
    // location rather than a dialog on the seller.
    await expect(page.getByText('1 Returns Way')).toBeVisible({ timeout: 15_000 })
    await page
      .locator('[data-slot="card"]')
      .filter({ has: page.getByText(/^contact$/i) })
      .getByRole('link', { name: /^edit$/i })
      .click()
    await expect(page).toHaveURL(/\/settings\/stock-locations\?.*edit=/, { timeout: 15_000 })
    await expect(
      page.getByRole('dialog').getByRole('heading', { name: FIXTURE_LEDGER_RETURNS_LOCATION }),
    ).toBeVisible({ timeout: 15_000 })
  })

  test('edits the payout settings through their own sheet', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    const name = `E2E Payout Seller ${Date.now()}`
    await createSeller(page, name)

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
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    const name = `E2E Isolation Seller ${Date.now()}`
    await createSeller(page, name)

    await cardEdit(page, /payouts and tax/i).click()
    await page.locator('#minimum_payout_amount').fill('40.0')
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText('40.0')).toBeVisible({ timeout: 15_000 })

    await cardEdit(page, /^contact$/i)
      .first()
      .click()
    await page.locator('#seller-billing-email').fill('billing@example.com')
    await page.getByRole('button', { name: /^save$/i }).click()

    await page.reload()
    await expect(page.getByText('billing@example.com').first()).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText('40.0')).toBeVisible()
  })

  test('deletes a seller from the list', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    const name = `E2E Delete Seller ${Date.now()}`
    await createSeller(page, name)

    await page.goto(SELLERS_PATH(creds.store_id))
    await expect(rowLink(page, name)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete seller\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowLink(page, name)).toHaveCount(0, { timeout: 15_000 })
  })

  test('records a custom field on the seller', async ({ page }) => {
    const creds = await login(page)
    await withCustomFieldDefinition(page, creds, 'seller', async (label) => {
      await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)
      await createSeller(page, `E2E Custom Field Seller ${Date.now()}`)
      await saveCustomFieldOnCard(page, label, 'Tier A')
    })
  })
})
