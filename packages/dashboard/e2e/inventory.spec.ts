import { expect, test } from '@playwright/test'
import {
  createInTransitTransfer,
  FIXTURE_INVENTORY_RESERVED,
  FIXTURE_INVENTORY_SKU,
  FIXTURE_TRANSFER_DESTINATION,
  FIXTURE_TRANSFER_SOURCE,
  login,
} from './helpers'

const INVENTORY_PATH = (storeId: string) => `/${storeId}/inventory`

/**
 * The Inventory page reads five figures off each stock level. Two of them —
 * reserved and incoming — are counters kept by the workflows that change
 * them, so the page is checked against the two things that move them a
 * merchant can see: a checkout holding units, and a transfer on its way.
 */
test.describe('inventory', () => {
  test('shows what is held and what is on its way, per location', async ({ page }) => {
    const creds = await login(page)
    const shipped = 7
    await createInTransitTransfer(page, creds.accessToken, {
      sku: FIXTURE_INVENTORY_SKU,
      quantity: shipped,
    })

    await page.goto(INVENTORY_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^inventory$/i })).toBeVisible({
      timeout: 15_000,
    })

    await page.getByPlaceholder(/search sku or product/i).fill(FIXTURE_INVENTORY_SKU)

    // One row per shelf: the destination holds three for a checkout and has
    // seven in the van; the source has neither.
    const destinationRow = page
      .getByRole('row')
      .filter({ hasText: FIXTURE_INVENTORY_SKU })
      .filter({ hasText: FIXTURE_TRANSFER_DESTINATION })
    await expect(destinationRow).toBeVisible({ timeout: 15_000 })
    await expect(destinationRow.getByRole('cell').nth(4)).toHaveText(
      String(FIXTURE_INVENTORY_RESERVED),
    )
    await expect(destinationRow.getByRole('button', { name: /add incoming stock/i })).toHaveText(
      String(shipped),
    )

    const sourceRow = page
      .getByRole('row')
      .filter({ hasText: FIXTURE_INVENTORY_SKU })
      .filter({ hasText: FIXTURE_TRANSFER_SOURCE })
    await expect(sourceRow.getByRole('cell').nth(4)).toHaveText('0')
    await expect(sourceRow.getByRole('button', { name: /add incoming stock/i })).toHaveText('0')
  })

  test('corrects the on-hand count in place', async ({ page }) => {
    const creds = await login(page)

    await page.goto(INVENTORY_PATH(creds.store_id))
    await page.getByPlaceholder(/search sku or product/i).fill(FIXTURE_INVENTORY_SKU)

    const destinationRow = page
      .getByRole('row')
      .filter({ hasText: FIXTURE_INVENTORY_SKU })
      .filter({ hasText: FIXTURE_TRANSFER_DESTINATION })
    const onHand = destinationRow.getByRole('button', { name: /edit on-hand count/i })
    await expect(onHand).toBeVisible({ timeout: 15_000 })
    const before = Number.parseInt((await onHand.innerText()).trim(), 10)

    // Adjust by: five more, counted in.
    await onHand.click()
    await page.getByLabel(/how to change the count/i).click()
    await page.getByRole('option', { name: /adjust by/i }).click()
    await page.getByLabel(/^amount$/i).fill('5')
    await page.getByLabel(/^reason$/i).click()
    await page.getByRole('option', { name: /^count$/i }).click()
    await page.getByRole('button', { name: /^apply$/i }).click()

    await expect(onHand).toHaveText(String(before + 5), { timeout: 15_000 })

    // Set to: back where it was, so the run leaves the fixture as it found it.
    await onHand.click()
    await page.getByLabel(/^amount$/i).fill(String(before))
    await page.getByRole('button', { name: /^apply$/i }).click()

    await expect(onHand).toHaveText(String(before), { timeout: 15_000 })
  })
})
