import { expect, test } from '@playwright/test'
import {
  FIXTURE_LEDGER_OWED_AMOUNT,
  FIXTURE_LEDGER_PAYOUT_AMOUNT,
  FIXTURE_LEDGER_SELLER,
  login,
} from './helpers'

const TRANSFERS_PATH = (storeId: string) => `/${storeId}/sellers/transfers`
const PAYOUTS_PATH = (storeId: string) => `/${storeId}/sellers/payouts`

test.describe('seller ledger', () => {
  test('lists what a seller earned', async ({ page }) => {
    const creds = await login(page)
    await page.goto(TRANSFERS_PATH(creds.store_id))

    await expect(page.getByRole('link', { name: FIXTURE_LEDGER_SELLER })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText('$120.00').first()).toBeVisible()
  })

  // A seller checking a figure wants the sale behind it, so the order cell is
  // a link rather than text. The same column exists on both panels.
  test('links an earning to the order that produced it', async ({ page }) => {
    const creds = await login(page)
    await page.goto(TRANSFERS_PATH(creds.store_id))

    const orderLink = page
      .getByRole('row')
      .filter({ hasText: FIXTURE_LEDGER_SELLER })
      .getByRole('link', { name: /^R\d+$/ })
      .first()
    await expect(orderLink).toBeVisible({ timeout: 15_000 })

    await orderLink.click()

    await expect(page).toHaveURL(/\/orders\/or_/, { timeout: 15_000 })
  })

  // The queue an operator works on payout day: the built-in provider records
  // what to send and waits to be told the bank transfer went out.
  test('marks a payout as paid, with the reference it went out under', async ({ page }) => {
    const creds = await login(page)
    await page.goto(PAYOUTS_PATH(creds.store_id))

    // Its own payout, so completing it cannot change what another spec reads.
    const owed = page
      .getByRole('row')
      .filter({ hasText: `$${Number(FIXTURE_LEDGER_OWED_AMOUNT).toFixed(2)}` })
    await expect(owed).toBeVisible({ timeout: 15_000 })

    const reference = `BACS-${Date.now()}`
    await owed.getByRole('button', { name: /actions/i }).click()
    await page.getByRole('menuitem', { name: /mark as paid/i }).click()

    await expect(page.getByRole('heading', { name: /mark this payout as paid/i })).toBeVisible()
    await page.getByLabel(/reference/i).fill(reference)
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /mark as paid/i })
      .click()

    await expect(page.getByText(reference)).toBeVisible({ timeout: 15_000 })
    await expect(owed.getByText(/completed/i)).toBeVisible({ timeout: 15_000 })
  })

  // The itemisation is what makes a settlement auditable — a figure on a bank
  // statement has to trace back to the sales behind it.
  test('a payout itemises the earnings it covers', async ({ page }) => {
    const creds = await login(page)
    await page.goto(PAYOUTS_PATH(creds.store_id))

    // The settled payout, picked by its amount: the seller has more than one
    // row here, so the seller name alone names both.
    const row = page
      .getByRole('row')
      .filter({ hasText: `$${Number(FIXTURE_LEDGER_PAYOUT_AMOUNT).toFixed(2)}` })
    await expect(row).toBeVisible({ timeout: 15_000 })

    // The date cell is the payout's own link; the seller cell goes to the
    // seller. Both live on the row, so this picks the one under test.
    await row.locator('[data-payout-id]').first().click()

    await expect(page.getByText(/covers 1 earning/i)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('heading', { name: '$120.00' })).toBeVisible()
  })
})
