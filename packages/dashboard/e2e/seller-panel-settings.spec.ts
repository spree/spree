import { expect, test } from '@playwright/test'
import {
  FIXTURE_SELLER_WRITER_EMAIL,
  openRowMenu,
  rowButton,
  sellerLogin,
  waitForToastsToClear,
} from './helpers'

// Everything here edits the seller it signs in as, so it signs in as the
// panel seller rather than the ledger seller the read-only specs look at.

test.describe('seller panel — profile', () => {
  test('edits the description and contact email, and they survive a reload', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page.goto(`${home}/profile`)

    const email = `hello-${Date.now()}@panel-seller.test`
    await page
      .getByRole('button', { name: /^edit$/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /edit your profile/i })).toBeVisible()
    await page.locator('#about').fill('Hand-thrown ceramics from a two-person studio.')
    await page.locator('#contact_email').fill(email)
    await page.getByRole('button', { name: /save changes/i }).click()
    await expect(page.getByText(/profile saved/i)).toBeVisible({ timeout: 15_000 })

    await page.reload()
    await expect(page.getByText('Hand-thrown ceramics from a two-person studio.')).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(email)).toBeVisible()
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
  test('each settings card opens its page', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page.goto(`${home}/settings`)

    await page
      .getByRole('main')
      .getByRole('link', { name: /^policies/i })
      .last()
      .click({ timeout: 15_000 })
    await expect(page).toHaveURL(/\/settings\/policies/)
    await expect(page.getByRole('heading', { name: /^policies$/i, level: 1 })).toBeVisible({
      timeout: 15_000,
    })
  })
})
