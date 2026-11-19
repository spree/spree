import { expect, type Page, test } from '@playwright/test'
import {
  FIXTURE_SELLER_WRITER_EMAIL,
  openRowMenu,
  rowButton,
  sellerLogin,
  waitForToastsToClear,
} from './helpers'

// Everything here edits the seller it signs in as, so it signs in as the
// panel seller rather than the ledger seller the read-only specs look at.

/** The page's Save, in its header. */
function save(page: Page) {
  return page.getByRole('button', { name: /^save$/i }).first()
}

test.describe('seller panel — profile', () => {
  test('edits the description, and it survives a reload', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page.goto(`${home}/settings/profile`)
    await expect(page.getByRole('heading', { name: /^profile$/i, level: 1 })).toBeVisible({
      timeout: 15_000,
    })
    // The storefront address is the marketplace's to change, and the
    // operator's media library is not the seller's to browse.
    await expect(page.locator('#seller-slug')).toHaveCount(0)
    await expect(page.getByRole('button', { name: /choose from library/i })).toHaveCount(0)
    await expect(page.getByText(/^cover photo$/i)).toBeVisible()
    // Opening the page is not a change.
    await expect(save(page)).toBeDisabled()

    const about = `Hand-thrown ceramics ${Date.now()}`
    await page.locator('#seller-about').click()
    await page.keyboard.press('ControlOrMeta+A')
    await page.locator('#seller-about').pressSequentially(about)
    await save(page).click()
    await expect(page.getByText(/profile saved/i)).toBeVisible({ timeout: 15_000 })

    await page.reload()
    await expect(page.getByText(about)).toBeVisible({ timeout: 15_000 })
  })

  test('sends the old profile address to settings', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page.goto(`${home}/profile`)
    await expect(page).toHaveURL(/\/settings\/profile$/, { timeout: 15_000 })
  })
})

test.describe('seller panel — general settings', () => {
  test('edits the contact email, and it survives a reload', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page.goto(`${home}/settings/general`)
    await expect(page.getByRole('heading', { name: /^general$/i, level: 1 })).toBeVisible({
      timeout: 15_000,
    })

    const email = `hello-${Date.now()}@panel-seller.test`
    await page.locator('#seller-contact-email').fill(email)
    await save(page).click()
    await expect(page.getByText(/profile saved/i)).toBeVisible({ timeout: 15_000 })

    await page.reload()
    await expect(page.locator('#seller-contact-email')).toHaveValue(email, { timeout: 15_000 })
  })

  test('turns holiday mode on and ends it', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page.goto(`${home}/settings/general`)

    await page.locator('#seller-holiday-mode-until').click()
    const calendar = page.getByRole('dialog')
    // The 15th of next month is always in the future.
    await calendar.getByRole('button', { name: /next month/i }).click()
    await calendar.getByRole('gridcell', { name: '15' }).click()
    await page.keyboard.press('Escape')
    await save(page).click()
    await expect(page.getByText(/profile saved/i)).toBeVisible({ timeout: 15_000 })
    await waitForToastsToClear(page)

    await page.reload()
    const clear = page.getByRole('button', { name: /^clear date$/i })
    await expect(clear).toBeVisible({ timeout: 15_000 })

    await clear.click()
    await save(page).click()
    await expect(page.getByText(/profile saved/i)).toBeVisible({ timeout: 15_000 })
    await page.reload()
    await expect(page.locator('#seller-contact-email')).toBeVisible({ timeout: 15_000 })
    await expect(clear).toHaveCount(0)
  })
})

test.describe('seller panel — taxes', () => {
  test('lists tax registrations under settings', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page.goto(`${home}/settings`)
    await page
      .getByRole('link', { name: /^taxes/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /^taxes$/i, level: 1 })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(/tax remitted by/i).first()).toBeVisible()
  })
})

test.describe('seller panel — policies', () => {
  test('writes a policy, edits it and deletes it', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page.goto(`${home}/settings/policies`)
    await expect(page.getByRole('heading', { name: /^policies$/i, level: 1 })).toBeVisible({
      timeout: 15_000,
    })

    const name = `E2E Returns ${Date.now()}`
    await page.getByRole('button', { name: /add policy/i }).click()
    await page.locator('#policy-name').fill(name)
    await page.locator('#policy-body').click()
    await page.locator('#policy-body').pressSequentially('Returns within 30 days.')
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    await expect(page.locator('#policy-name')).toHaveValue(name, { timeout: 15_000 })
    await page.locator('#policy-name').fill(`${name} (updated)`)
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()
    await expect(rowButton(page, `${name} (updated)`)).toBeVisible({ timeout: 15_000 })

    await waitForToastsToClear(page)
    await openRowMenu(page, `${name} (updated)`)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()
    await expect(rowButton(page, `${name} (updated)`)).toHaveCount(0, { timeout: 15_000 })
  })
})

test.describe('seller panel — stock locations', () => {
  test('adds a location of the seller’s own', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page.goto(`${home}/settings/stock-locations`)

    const name = `E2E Studio ${Date.now()}`
    await page.getByRole('button', { name: /add stock location/i }).click({ timeout: 15_000 })
    await page.locator('#name').fill(name)
    await page.getByRole('button', { name: /create stock location/i }).click()

    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
  })
})

test.describe('seller panel — team', () => {
  test('keeps the last member, and invites and revokes a colleague', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page.goto(`${home}/settings/team`)
    await expect(page.getByRole('heading', { name: /^your team$/i })).toBeVisible({
      timeout: 15_000,
    })

    // A seller nobody can sign in to can only be reopened by the operator, so
    // the only member cannot be removed.
    await openRowMenu(page, FIXTURE_SELLER_WRITER_EMAIL)
    await expect(page.getByRole('menuitem', { name: /^remove$/i })).toBeDisabled()
    await page.keyboard.press('Escape')

    const email = `e2e-colleague-${Date.now()}@example.com`
    await page.getByRole('button', { name: /invite member/i }).click()
    await page.locator('#invite-email').fill(email)
    await page.getByRole('button', { name: /send invitation/i }).click()
    await expect(page.getByRole('row').filter({ hasText: email })).toBeVisible({
      timeout: 15_000,
    })

    await waitForToastsToClear(page)
    await openRowMenu(page, email)
    await page.getByRole('menuitem', { name: /^revoke$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^revoke$/i })
      .click()
    await expect(page.getByRole('row').filter({ hasText: email })).toHaveCount(0, {
      timeout: 15_000,
    })
  })
})

test.describe('seller panel — settings', () => {
  // The settings index is the phone and tablet way into settings; a desktop
  // screen goes straight to a section, with the rail beside it.
  test('each settings card opens its page', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page.goto(`${home}/settings`)

    await page
      .getByRole('main')
      .getByRole('link', { name: /^policies/i })
      .click({ timeout: 15_000 })
    await expect(page).toHaveURL(/\/settings\/policies/)
    await expect(page.getByRole('heading', { name: /^policies$/i, level: 1 })).toBeVisible({
      timeout: 15_000,
    })
  })
})
