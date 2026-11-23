import { expect, type Page, test } from '@playwright/test'
import {
  escapeRegex,
  FIXTURE_LEDGER_PRODUCT_IN_REVIEW,
  FIXTURE_LEDGER_RETURNS_LOCATION,
  FIXTURE_LEDGER_SELLER,
  fillAddressForm,
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

/** One titled section of the seller page, to scope rows and buttons to it. */
function section(page: Page, title: RegExp) {
  return page.locator('section').filter({ has: page.getByRole('heading', { name: title }) })
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
    // The header says what the status means.
    await expect(page.getByText(/nobody has been invited yet/i)).toBeVisible()
    await expect(page.getByText(/taking orders as usual/i)).toBeVisible()
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

  test('adds a team member to an approved seller and copies their link', async ({ page }) => {
    await page.context().grantPermissions(['clipboard-read', 'clipboard-write'])
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)
    await rowLink(page, FIXTURE_LEDGER_SELLER).click()
    await expect(page.getByRole('heading', { name: FIXTURE_LEDGER_SELLER })).toBeVisible()

    // An approved seller is past the lifecycle invite, so the team card's is the only one.
    await page.getByRole('button', { name: /^invite$/i }).click()
    await expect(page.getByRole('heading', { name: /invite team member/i })).toBeVisible()

    const email = `teammate-${Date.now()}@example.com`
    await page.locator('#invite-email').fill(email)
    await page.getByRole('button', { name: /send invitation/i }).click()

    await expect(page.getByText(email)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(/^approved$/i).first()).toBeVisible()

    await openRowMenu(page, email)
    await page.getByRole('menuitem', { name: /copy invitation link/i }).click()
    await expect(page.getByText(/invitation link copied/i)).toBeVisible()
    expect(await page.evaluate(() => navigator.clipboard.readText())).toMatch(
      /\/accept-invitation\//,
    )
  })

  test('edits the profile in place', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    const name = `E2E Profile Seller ${Date.now()}`
    await createSeller(page, name)

    // The images open a dialog of their own.
    await page.getByRole('button', { name: /^edit logo$/i }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByRole('heading', { name: /^edit logo$/i })).toBeVisible()
    await dialog.getByRole('button', { name: /^cancel$/i }).click()
    await expect(dialog).toHaveCount(0)

    await page.getByRole('button', { name: /^edit profile$/i }).click()
    const editor = page.getByRole('form', { name: /edit profile/i })
    await expect(editor).toBeVisible()
    // The images and the emails each have their own pencil.
    await expect(page.locator('#seller-contact-email')).toHaveCount(0)
    await expect(page.getByText(/^cover photo$/i)).toHaveCount(0)

    const renamed = `${name} Renamed`
    await editor.locator('#seller-name').fill(renamed)
    await editor.getByRole('button', { name: /^save$/i }).click()

    // Back to the read view, showing the new value.
    await expect(editor).toHaveCount(0, { timeout: 15_000 })
    await expect(page.getByRole('heading', { name: renamed }).first()).toBeVisible({
      timeout: 15_000,
    })
  })

  test('edits the contact details in place', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    await createSeller(page, `E2E Contact Seller ${Date.now()}`)

    await cardEdit(page, /^contact$/i)
      .first()
      .click()
    const editor = page.getByRole('form', { name: /edit contact/i })
    await expect(editor).toBeVisible()
    // Only the contact fields: the profile has its own pencil.
    await expect(page.locator('#seller-name')).toHaveCount(0)

    // Nothing to save until something changes.
    await expect(editor.getByRole('button', { name: /^save$/i })).toBeDisabled()
    await editor.locator('#seller-contact-email').fill('updated@example.com')
    await editor.getByRole('button', { name: /^save$/i }).click()

    await expect(editor).toHaveCount(0, { timeout: 15_000 })
    await expect(page.getByText('updated@example.com').first()).toBeVisible({ timeout: 15_000 })

    // Leaving with a change asks first, and discarding keeps what was saved.
    await cardEdit(page, /^contact$/i)
      .first()
      .click()
    await editor.locator('#seller-contact-email').fill('discarded@example.com')
    await editor.getByRole('button', { name: /^cancel$/i }).click()
    await page
      .getByRole('dialog')
      .filter({ hasText: /unsaved changes/i })
      .getByRole('button', { name: /^discard$/i })
      .click()
    await expect(editor).toHaveCount(0)
    await expect(page.getByText('discarded@example.com')).toHaveCount(0)
    await expect(page.getByText('updated@example.com').first()).toBeVisible()
  })

  test("opens the seller's stock locations from their page", async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)
    await rowLink(page, FIXTURE_LEDGER_SELLER).click()

    // The page lists them in its own section, and a row opens the location's
    // editor over the seller page rather than going to settings.
    const sellerUrl = page.url()
    await page.getByRole('button', { name: FIXTURE_LEDGER_RETURNS_LOCATION }).click()
    const sheet = page.getByRole('dialog')
    await expect(sheet.getByRole('heading', { name: FIXTURE_LEDGER_RETURNS_LOCATION })).toBeVisible(
      {
        timeout: 15_000,
      },
    )
    expect(page.url()).toBe(sellerUrl)
    await page.keyboard.press('Escape')
    await expect(sheet).toHaveCount(0)
  })

  // What the seller sells and what waits on the operator, on their own page.
  test('reviews a product and shows the seller orders on their page', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)
    await rowLink(page, FIXTURE_LEDGER_SELLER).click()

    // The products list's own table, narrowed to the seller.
    const products = section(page, /^products/i)
    const row = products.getByRole('row').filter({ hasText: FIXTURE_LEDGER_PRODUCT_IN_REVIEW })
    await expect(row).toBeVisible({ timeout: 15_000 })

    // Approved in place: the row goes live.
    await row.getByRole('button', { name: /^approve$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^approve$/i })
      .click()
    await expect(row.getByText(/^active$/i)).toBeVisible({ timeout: 15_000 })
    await expect(row.getByRole('button', { name: /^approve$/i })).toHaveCount(0)

    // The orders list's own table, narrowed to the seller's placed orders.
    const orders = section(page, /^orders/i)
    await expect(
      orders.getByRole('row').filter({ hasText: 'e2e-ledger@example.com' }).first(),
    ).toBeVisible({ timeout: 15_000 })
  })

  // The returns address is the returns location's own, and the API writes it
  // there: no second location appears.
  test('edits the returns address on the seller page', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)
    const name = `E2E Returns Seller ${Date.now()}`
    await createSeller(page, name)

    const returns = page
      .locator('[data-slot="card"]')
      .filter({ has: page.getByText(/^contact$/i) })
      .locator('div')
      .filter({ has: page.getByRole('heading', { name: /^returns address$/i }) })
      .last()
    await returns.getByRole('button', { name: /^edit$/i }).click()

    const dialog = page.getByRole('dialog')
    await dialog.locator('#addr-co').fill('Sparks Returns')
    await fillAddressForm(page, {
      address1: '9 Returns Lane',
      city: 'Leeds',
      postalCode: 'LS1 1AA',
      country: 'United Kingdom',
    })
    await dialog.getByRole('button', { name: /^save$/i }).click()

    await expect(dialog).toHaveCount(0, { timeout: 15_000 })
    await expect(page.getByText('9 Returns Lane')).toBeVisible({ timeout: 15_000 })
    // Written onto the seller's one location rather than a new one: the
    // stock locations section lists it, now with the city.
    await expect(page.getByRole('button', { name: new RegExp(escapeRegex(name)) })).toHaveCount(1)
    await expect(page.getByRole('button', { name: /leeds/i })).toBeVisible()
  })

  test('edits the payout settings in place', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    const name = `E2E Payout Seller ${Date.now()}`
    await createSeller(page, name)

    await cardEdit(page, /payouts and tax/i).click()
    const editor = page.getByRole('form', { name: /edit payouts and tax/i })
    await expect(editor).toBeVisible()

    await editor.locator('#payouts_schedule_interval').click()
    await page.getByRole('option', { name: /^weekly$/i }).click()
    await editor.locator('#minimum_payout_amount').fill('25.0')
    await editor.getByRole('button', { name: /^save$/i }).click()

    await expect(editor).toHaveCount(0, { timeout: 15_000 })
    await expect(page.getByText(/^weekly$/i).first()).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText('25.0')).toBeVisible()
  })

  // Each card sends only its own fields, so saving one must not roll back
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

  test('puts a seller on holiday and ends it', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, SELLERS_PATH(creds.store_id), CTA)

    await createSeller(page, `E2E Holiday Seller ${Date.now()}`)

    await cardEdit(page, /^holiday mode$/i).click()
    const editor = page.getByRole('form', { name: /holiday mode/i })
    await editor.locator('#seller-holiday-mode-until').click()
    const calendar = page.getByRole('dialog')
    // The 15th of next month is always in the future.
    await calendar.getByRole('button', { name: /next month/i }).click()
    await calendar.getByRole('gridcell', { name: '15' }).click()
    await page.keyboard.press('Escape')
    await editor.getByRole('button', { name: /^save$/i }).click()

    await expect(editor).toHaveCount(0, { timeout: 15_000 })
    await expect(page.getByText(/this seller is away/i)).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /^end holiday mode$/i }).click()
    await expect(page.getByText(/taking orders as usual/i)).toBeVisible({ timeout: 15_000 })
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
