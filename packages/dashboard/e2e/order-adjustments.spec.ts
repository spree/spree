import { expect, type Page, test } from '@playwright/test'
import { createPlacedOrder, login } from './helpers'

/** An order page section, found by its heading. */
function section(page: Page, heading: RegExp) {
  return page
    .locator('[data-slot="section"]')
    .filter({ has: page.getByRole('heading', { name: heading }) })
    .first()
}

test.describe('order discounts and fees', () => {
  test('adds a manual discount and a fee, listed in their tables', async ({ page }) => {
    const creds = await login(page)
    const order = await createPlacedOrder(page, creds.accessToken, { ship: false })
    await page.goto(`/${creds.store_id}/orders/${order.id}`)

    const suffix = Date.now()
    const discountLabel = `E2E goodwill ${suffix}`
    const feeLabel = `E2E handling ${suffix}`

    const discounts = section(page, /^discounts/i)
    await expect(discounts.getByText(/no discounts on this order yet/i)).toBeVisible({
      timeout: 15_000,
    })
    await discounts.getByRole('button', { name: /add discount/i }).click()
    let dialog = page.getByRole('dialog')
    await dialog.locator('#discount-label').fill(discountLabel)
    await dialog.locator('#discount-value').fill('5')
    await dialog.getByRole('button', { name: /^add discount$/i }).click()
    await expect(dialog).toBeHidden({ timeout: 15_000 })

    const discountRow = discounts.getByRole('row').filter({ hasText: discountLabel })
    await expect(discountRow).toBeVisible({ timeout: 15_000 })
    await expect(discountRow).toContainText('5.00')

    const fees = section(page, /^fees/i)
    await fees.getByRole('button', { name: /add fee/i }).click()
    dialog = page.getByRole('dialog')
    await dialog.locator('#fee-label').fill(feeLabel)
    await dialog.locator('#fee-amount').fill('3')
    await dialog.getByRole('button', { name: /^add fee$/i }).click()
    await expect(dialog).toBeHidden({ timeout: 15_000 })

    const feeRow = fees.getByRole('row').filter({ hasText: feeLabel })
    await expect(feeRow).toBeVisible({ timeout: 15_000 })
    await expect(feeRow).toContainText('3.00')

    // Each row carries its own menu; removing the fee empties its table.
    await feeRow.getByRole('button', { name: /actions/i }).click()
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()
    await expect(fees.getByText(/no fees on this order yet/i)).toBeVisible({ timeout: 15_000 })
  })
})
