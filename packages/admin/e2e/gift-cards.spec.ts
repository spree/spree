import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const GIFT_CARDS_PATH = (storeId: string) => `/${storeId}/promotions/gift-cards`
const CTA = /new gift card/i

async function createGiftCard(
  page: Page,
  attrs: { amount: string; code?: string; expiresAt?: string },
) {
  await page.getByRole('button', { name: /new gift card/i }).click()
  await expect(page.getByRole('heading', { name: /new gift card/i })).toBeVisible()

  if (attrs.code) await page.locator('#code').fill(attrs.code)
  await page.locator('#amount').fill(attrs.amount)
  // Note: expires_at is a `<StoreDatePicker>` (button + popover), not a native
  // input — can't be `.fill()`ed. Specs needing an expiry should drive the
  // picker UI instead of passing `expiresAt` here.

  await page.getByRole('button', { name: /create gift card/i }).click()
}

test.describe('gift cards', () => {
  test('lists gift cards', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, GIFT_CARDS_PATH(creds.store_id), CTA)
  })

  test('creates a gift card with an auto-generated code', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, GIFT_CARDS_PATH(creds.store_id), CTA)

    // Per-test unique amount so leftover rows from earlier tests don't
    // satisfy this assertion accidentally (suite is serial — see CLAUDE.md).
    const cents = (Date.now() % 9000) + 100
    const amount = (cents / 100).toFixed(2)
    await createGiftCard(page, { amount })

    // Auto-generated code is uppercase hex; just confirm a row with the
    // freshly-issued amount appears in the table.
    const re = new RegExp(`\\$${amount.replace('.', '\\.')}`)
    await expect(page.getByText(re).first()).toBeVisible({ timeout: 15_000 })
  })

  test('creates a gift card with a custom code and edits it', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, GIFT_CARDS_PATH(creds.store_id), CTA)

    const code = `E2E${Date.now().toString().slice(-6)}`
    await createGiftCard(page, { amount: '50.00', code })

    await expect(rowButton(page, code)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, code).click()
    await expect(page.getByRole('heading', { name: code })).toBeVisible({ timeout: 15_000 })

    await page.locator('#amount').fill('75.00')
    await page.getByRole('button', { name: /^save$/i }).click()

    // Reopen the row to verify the new amount stuck.
    await expect(page.getByText(/\$75\.00/).first()).toBeVisible({ timeout: 15_000 })
  })

  test('bulk-issues a batch when quantity > 1', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, GIFT_CARDS_PATH(creds.store_id), CTA)

    const prefix = `E2EB${Date.now().toString().slice(-6)}`

    await page.getByRole('button', { name: /new gift card/i }).click()
    await expect(page.getByRole('heading', { name: /new gift card/i })).toBeVisible()

    // Quantity > 1 flips the sheet into batch mode — the Code field
    // relabels to Prefix and the customer picker disappears.
    await page.locator('#quantity').fill('3')
    await expect(page.getByText(/^prefix$/i).first()).toBeVisible()
    await page.locator('#code').fill(prefix)
    await page.locator('#amount').fill('20.00')

    await page.getByRole('button', { name: /create 3 gift cards/i }).click()

    // Three cards generated with the prefix should now be in the list.
    await expect(page.getByText(new RegExp(prefix, 'i')).first()).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a gift card', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, GIFT_CARDS_PATH(creds.store_id), CTA)

    const code = `E2EDEL${Date.now().toString().slice(-6)}`
    await createGiftCard(page, { amount: '10.00', code })
    await expect(rowButton(page, code)).toBeVisible({ timeout: 15_000 })

    // Delete now lives on the row-action kebab.
    await openRowMenu(page, code)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete gift card\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, code)).toHaveCount(0, { timeout: 15_000 })
  })
})
