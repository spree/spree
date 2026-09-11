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

  test('opens a purchase order with the row already on it', async ({ page }) => {
    const creds = await login(page)

    await page.goto(INVENTORY_PATH(creds.store_id))
    await page.getByPlaceholder(/search sku or product/i).fill(FIXTURE_INVENTORY_SKU)

    const row = page
      .getByRole('row')
      .filter({ hasText: FIXTURE_INVENTORY_SKU })
      .filter({ hasText: FIXTURE_TRANSFER_DESTINATION })
    await expect(row).toBeVisible({ timeout: 15_000 })

    await row.getByRole('button', { name: /add incoming stock/i }).click()
    await page.getByRole('link', { name: /create purchase order/i }).click()

    // The form opens with that SKU on it and the warehouse it was short at.
    await expect(page.getByRole('heading', { name: /new purchase order/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(FIXTURE_INVENTORY_SKU)).toBeVisible()
    await expect(page.getByText(FIXTURE_TRANSFER_DESTINATION)).toBeVisible()
  })

  // Both controls live in the toolbar rather than behind Add filter. The
  // stock status is a multi-select scope, which sends one query parameter per
  // value — the shape that first came back a 400.
  test('narrows the list by stock status and location', async ({ page }) => {
    const creds = await login(page)

    await page.goto(INVENTORY_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^inventory$/i })).toBeVisible({
      timeout: 15_000,
    })
    await page.getByPlaceholder(/search sku or product/i).fill(FIXTURE_INVENTORY_SKU)

    // The fixture SKU is held at the destination, so a checkout is holding
    // units there and the row survives a "reserved" filter.
    const destinationRow = page
      .getByRole('row')
      .filter({ hasText: FIXTURE_INVENTORY_SKU })
      .filter({ hasText: FIXTURE_TRANSFER_DESTINATION })
    await expect(destinationRow).toBeVisible({ timeout: 15_000 })

    // Every state starts selected, so narrowing means unchecking the rest.
    const statusFilter = page.getByRole('button', { name: /stock status/i })
    await statusFilter.click()
    for (const name of [/^in stock$/i, /^out of stock$/i, /^incoming$/i]) {
      await page.getByRole('menuitemcheckbox', { name }).click()
    }
    await page.keyboard.press('Escape')

    await expect(statusFilter).toContainText('1/4')
    await expect(destinationRow).toBeVisible({ timeout: 15_000 })

    // The location filter lists every warehouse rather than asking the
    // operator to type one; narrow it to the one holding none of this SKU.
    await page.getByRole('button', { name: /^location/i }).click()
    for (const name of [FIXTURE_TRANSFER_DESTINATION, 'Shop location']) {
      await page.getByRole('menuitemcheckbox', { name }).click()
    }
    await page.keyboard.press('Escape')

    await expect(destinationRow).toBeHidden({ timeout: 15_000 })
  })

  // The five figures are definitions, not words: a merchant who cannot tell
  // reserved from on orders is the reason the hints exist.
  test('explains what each figure counts', async ({ page }) => {
    const creds = await login(page)

    await page.goto(INVENTORY_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^inventory$/i })).toBeVisible({
      timeout: 15_000,
    })

    await page.getByRole('button', { name: /units held by customers who are in checkout/i }).hover()

    await expect(
      page.getByText(/units held by customers who are in checkout right now/i).last(),
    ).toBeVisible({ timeout: 15_000 })
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

  // A shelf list has to hold still: the rows a merchant is working through
  // must not rearrange under the pointer, and correcting one figure is no
  // reason to refetch the other twenty-four.
  test('leaves the rest of the list alone when one count is corrected', async ({ page }) => {
    const listRequests: string[] = []
    page.on('request', (request) => {
      if (/\/stock_levels\?/.test(request.url())) listRequests.push(request.url())
    })

    const creds = await login(page)
    await page.goto(INVENTORY_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^inventory$/i })).toBeVisible({
      timeout: 15_000,
    })

    const productNames = () => page.getByRole('row').locator('td:first-child').allInnerTexts()

    // Snapshot only once real rows have replaced the loading skeletons,
    // otherwise "before" is a list of empty cells and the comparison is
    // meaningless.
    const onHand = page.getByRole('button', { name: /edit on-hand count/i }).first()
    await expect(onHand).toBeVisible({ timeout: 15_000 })
    await expect
      .poll(async () => (await productNames()).filter(Boolean).length, { timeout: 15_000 })
      .toBeGreaterThan(0)

    const orderBefore = await productNames()
    const fetchesBefore = listRequests.length

    const before = Number.parseInt((await onHand.innerText()).trim(), 10)
    await onHand.click()
    await page.getByLabel(/^amount$/i).fill(String(before + 1))
    await page.getByRole('button', { name: /^apply$/i }).click()
    await expect(onHand).toHaveText(String(before + 1), { timeout: 15_000 })

    expect(await productNames()).toEqual(orderBefore)
    expect(listRequests.length).toBe(fetchesBefore)

    // Leave the fixture as it was found.
    await onHand.click()
    await page.getByLabel(/^amount$/i).fill(String(before))
    await page.getByRole('button', { name: /^apply$/i }).click()
    await expect(onHand).toHaveText(String(before), { timeout: 15_000 })
  })
})
