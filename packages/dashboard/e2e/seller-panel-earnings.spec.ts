import { expect, type Page, test } from '@playwright/test'
import { sellerLogin } from './helpers'

// The seeded ledger seller has one placed order, one settled earning of
// $120.00 against it, and payouts of $120.00 and $75.00 (see global-setup.ts).
// These screens are read-only, so nothing here changes what another spec reads.

async function openSection(page: Page, link: RegExp, heading: RegExp) {
  await page.getByRole('link', { name: link }).first().click()
  await expect(page.getByRole('heading', { name: heading, level: 1 })).toBeVisible({
    timeout: 15_000,
  })
}

test.describe('seller panel — orders and earnings', () => {
  test('lists the seller’s order and opens it with what it earned', async ({ page }) => {
    await sellerLogin(page)
    await openSection(page, /^orders$/i, /^orders$/i)

    const order = page.getByRole('button', { name: /^R\d+/ }).first()
    await expect(order).toBeVisible({ timeout: 15_000 })
    const number = ((await order.textContent()) ?? '').match(/R\d+/)?.[0] ?? ''
    await order.click()

    await expect(page.getByRole('heading', { name: number, level: 1 })).toBeVisible({
      timeout: 15_000,
    })
    const earnings = page
      .locator('[data-slot="card"]')
      .filter({ has: page.getByText(/^what you earned$/i) })
    await expect(earnings.getByText('$120.00').first()).toBeVisible()
    await expect(earnings.getByRole('link', { name: /view payout/i })).toBeVisible()
  })

  test('shows the balance and the sale behind it', async ({ page }) => {
    await sellerLogin(page)
    await openSection(page, /^earnings$/i, /^earnings$/i)

    await expect(page.getByText(/owed to you \(usd\)/i)).toBeVisible({ timeout: 15_000 })
    const earned = page.getByRole('term').filter({ hasText: /^earned$/i })
    await expect(earned.locator('xpath=following-sibling::dd[1]')).toHaveText('$120.00')
    const sale = page.getByRole('row').filter({ hasText: /sale/i }).filter({ hasText: '$120.00' })
    await expect(sale.first()).toBeVisible({ timeout: 15_000 })
    // The order cell links to the sale, the same as on the operator's side.
    await sale
      .first()
      .getByRole('link', { name: /^R\d+$/ })
      .click()
    await expect(page).toHaveURL(/\/orders\/or_/, { timeout: 15_000 })
  })

  test('lists payouts and opens one to see the earnings it covers', async ({ page }) => {
    await sellerLogin(page)
    await openSection(page, /^payouts$/i, /^payouts$/i)

    const payout = page.getByRole('row').filter({ hasText: '$120.00' }).first()
    await expect(payout).toBeVisible({ timeout: 15_000 })
    await payout.getByRole('button').first().click()

    await expect(page).toHaveURL(/\/payouts\/[a-z]+_/, { timeout: 15_000 })
    await expect(page.getByText(/covers 1 earning/i)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('link', { name: /^R\d+$/ }).first()).toBeVisible()
  })
})
