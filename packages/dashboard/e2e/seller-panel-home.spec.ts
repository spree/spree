import { expect, test } from '@playwright/test'
import {
  FIXTURE_LEDGER_SELLER,
  FIXTURE_SELLER_PASSWORD,
  FIXTURE_SELLER_USER_EMAIL,
  FIXTURE_SELLER_WRITER_EMAIL,
  SELLER_PANEL,
  sellerLogin,
} from './helpers'

test.describe('seller panel — signing in', () => {
  test('signs in with the form and lands on the seller home', async ({ page }) => {
    await page.goto(`${SELLER_PANEL}/login`)
    await page.getByLabel(/^email$/i).fill(FIXTURE_SELLER_USER_EMAIL)
    await page.getByLabel(/^password$/i).fill(FIXTURE_SELLER_PASSWORD)
    await page.getByRole('button', { name: /^sign in$/i }).click()

    await expect(page).toHaveURL(/\/sel_[^/]+$/, { timeout: 20_000 })
    await expect(
      page.getByRole('heading', { name: `Hello, ${FIXTURE_LEDGER_SELLER}` }),
    ).toBeVisible()
  })

  test('refuses a wrong password', async ({ page }) => {
    await page.goto(`${SELLER_PANEL}/login`)
    await page.getByLabel(/^email$/i).fill(FIXTURE_SELLER_USER_EMAIL)
    await page.getByLabel(/^password$/i).fill('not-the-password')
    await page.getByRole('button', { name: /^sign in$/i }).click()

    await expect(page.getByText(/did not match a seller account/i)).toBeVisible({
      timeout: 15_000,
    })
    await expect(page).toHaveURL(/\/login/)
  })

  test('sends a password reset link', async ({ page }) => {
    await page.goto(`${SELLER_PANEL}/login`)
    await page.getByRole('link', { name: /forgot your password/i }).click()

    await page.getByLabel(/^email$/i).fill(FIXTURE_SELLER_USER_EMAIL)
    await page.getByRole('button', { name: /send reset link/i }).click()

    await expect(page.getByRole('heading', { name: /check your email/i })).toBeVisible({
      timeout: 15_000,
    })
  })

  test('signs out back to the sign-in page', async ({ page }) => {
    await sellerLogin(page)

    await page.getByRole('button', { name: /user menu/i }).click()
    await page.getByRole('menuitem', { name: /sign out|log out/i }).click()

    await expect(page).toHaveURL(/\/login/, { timeout: 15_000 })
    // The session is gone, not just the page: going back in asks again.
    await page.goto(SELLER_PANEL)
    await expect(page).toHaveURL(/\/login/, { timeout: 15_000 })
  })
})

test.describe('seller panel — home', () => {
  // `sellerLogin` opens the panel with a session but no remembered seller —
  // the cold start where the sidebar used to stay empty, because permissions
  // were fetched before a seller was chosen and never again.
  test('shows where the seller stands, and each section is a click away', async ({ page }) => {
    await sellerLogin(page)

    await expect(page.getByText(/^status$/i)).toBeVisible()
    await expect(page.getByText(/^approved$/i).first()).toBeVisible()
    await expect(page.getByText(/^team members$/i)).toBeVisible()

    for (const [link, heading] of [
      [/^products$/i, /^products$/i],
      [/^orders$/i, /^orders$/i],
      [/^earnings$/i, /^earnings$/i],
      [/^payouts$/i, /^payouts$/i],
    ] as const) {
      await page.getByRole('link', { name: link }).first().click()
      await expect(page.getByRole('heading', { name: heading, level: 1 })).toBeVisible({
        timeout: 15_000,
      })
    }
  })
})

test.describe('seller panel — setup', () => {
  test('accepting the marketplace terms ticks that step off', async ({ page }) => {
    await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page
      .getByRole('link', { name: /^setup/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /^setup$/i })).toBeVisible({
      timeout: 15_000,
    })

    const step = page.getByRole('button', { name: /accept terms/i })
    await expect(step).toBeVisible({ timeout: 15_000 })
    // Opens on the first outstanding step, which is usually this one.
    if ((await step.getAttribute('aria-expanded')) !== 'true') await step.click()
    await page.getByRole('button', { name: /accept the terms/i }).click()

    await expect(page.getByText(/terms accepted/i)).toBeVisible({ timeout: 15_000 })
    await expect(step.getByText(/^done$/i)).toBeVisible({ timeout: 15_000 })
  })
})
