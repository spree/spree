import { expect, type Page, test } from '@playwright/test'
import { deleteCatalogPickerProducts, login, seedCatalogPickerProducts } from './helpers'

/**
 * The "Add a product" sheet on a purchase order — the one surface where a
 * merchant puts several SKUs on a document in one pass.
 *
 * Two things shipped broken here because no spec ever opened the sheet: a
 * multi-select added only one of the products picked, and reopening the sheet
 * showed an empty list over a cache that still held every result. Both are
 * invisible to a spec that only checks the button exists, so these drive the
 * sheet itself.
 *
 * The purchase order is the subject rather than the transfer because its
 * picker offers the whole catalogue — a transfer filters by the warehouse it
 * leaves from, which would narrow the list to the one stocked fixture SKU.
 */

/** Enough products to tell "added them all" apart from "added the last one". */
const PICKED = 3

test.describe('inventory line picker', () => {
  let productIds: string[] = []
  let prefix = ''

  test.beforeEach(async ({ page }) => {
    const creds = await login(page)
    // Unique per test: the suite runs serially against one database, and a
    // shared name would let an earlier run's rows widen the match count this
    // spec asserts on.
    prefix = `E2E PO Picker ${Date.now()}`
    productIds = await seedCatalogPickerProducts(
      page,
      creds.store_id,
      prefix,
      creds.accessToken,
      PICKED,
    )
    await page.goto(`/${creds.store_id}/purchase-orders/new`)
    await expect(page.getByRole('heading', { name: /new purchase order/i })).toBeVisible({
      timeout: 15_000,
    })
  })

  test.afterEach(async ({ page }) => {
    if (productIds.length === 0) return
    const creds = await login(page)
    await deleteCatalogPickerProducts(page, creds.store_id, creds.accessToken, productIds).catch(
      () => undefined,
    )
    productIds = []
  })

  test('adds every product picked in one pass, not just one of them', async ({ page }) => {
    await openPicker(page)
    await searchFor(page, prefix)

    // Check each row individually: this is the multi-select that used to
    // collapse to a single line.
    for (let index = 1; index <= PICKED; index += 1) {
      await page.getByRole('button', { name: productName(prefix, index) }).click()
    }

    const sheet = page.getByRole('dialog')
    await expect(sheet.getByText(`${PICKED} selected`)).toBeVisible()
    await sheet.getByRole('button', { name: new RegExp(`^add ${PICKED}$`, 'i') }).click()

    // Every picked product reaches the document, each as its own line.
    await expect(sheet).toBeHidden()
    for (let index = 1; index <= PICKED; index += 1) {
      await expect(page.getByText(productName(prefix, index))).toBeVisible()
    }
    await expect(quantityInputs(page)).toHaveCount(PICKED)
  })

  test('still lists products when the sheet is reopened', async ({ page }) => {
    // Deliberately unsearched, both times. Reopening on the *same* query is
    // what broke: the cached page came back unchanged, so the sheet had
    // nothing new to react to and showed "no results" over a full cache.
    // Typing a different search on the second pass hides the bug, because a
    // new query fetches afresh.
    await openPicker(page)
    await expect(anyResult(page).first()).toBeVisible({ timeout: 15_000 })

    // Leave without picking anything — the close path is what used to empty
    // the list for good.
    await closeSheet(page)

    await openPicker(page)

    // The results come back rather than the sheet claiming there are none.
    await expect(anyResult(page).first()).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(/no results found/i)).toHaveCount(0)
  })

  test('still lists products when the sheet is reopened after a search', async ({ page }) => {
    // The searched reopen. This path survived the bug on its own — retyping a
    // query the cache has not seen refetches, which repopulated the list — so
    // it is here to keep the search-and-reopen path working, not to reproduce
    // the fault. The unsearched reopen above is the one that catches it.
    await openPicker(page)
    await searchFor(page, prefix)

    await closeSheet(page)

    await openPicker(page)
    await searchFor(page, prefix)

    await expect(page.getByText(/no results found/i)).toHaveCount(0)
    for (let index = 1; index <= PICKED; index += 1) {
      await expect(page.getByRole('button', { name: productName(prefix, index) })).toBeVisible()
    }
  })

  test('reopening after adding offers the rest and keeps the lines already added', async ({
    page,
  }) => {
    await openPicker(page)
    await searchFor(page, prefix)
    await page.getByRole('button', { name: productName(prefix, 1) }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^add 1$/i })
      .click()
    await expect(page.getByRole('dialog')).toBeHidden()

    // Reopening after a confirm is the path a merchant takes to add a product
    // they forgot; the sheet has to come back usable. Unsearched on purpose —
    // the confirm path cleared the box, so this is the query the cache holds.
    await openPicker(page)
    await expect(anyResult(page).first()).toBeVisible({ timeout: 15_000 })
    await searchFor(page, prefix)

    // What is already on the order is offered as added rather than pickable.
    await expect(
      page.getByRole('button', { name: productName(prefix, 1) }).getByText(/^added$/i),
    ).toBeVisible()

    await page.getByRole('button', { name: productName(prefix, 2) }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^add 1$/i })
      .click()

    // The second product joins the first instead of replacing it.
    await expect(page.getByRole('dialog')).toBeHidden()
    await expect(page.getByText(productName(prefix, 1))).toBeVisible()
    await expect(page.getByText(productName(prefix, 2))).toBeVisible()
    await expect(quantityInputs(page)).toHaveCount(2)
  })
})

/** Any row in the picker list, whatever the catalogue happens to hold. */
function anyResult(page: Page) {
  return page.getByRole('dialog').getByRole('button', { name: /SKU/ })
}

/** Leave the sheet without picking anything. */
async function closeSheet(page: Page) {
  await page
    .getByRole('dialog')
    .getByRole('button', { name: /^cancel$/i })
    .click()
  await expect(page.getByRole('dialog')).toBeHidden()
}

function productName(prefix: string, index: number) {
  return `${prefix} ${String(index).padStart(2, '0')}`
}

/** The order has no lines yet, so the empty state carries the only add button. */
async function openPicker(page: Page) {
  await page
    .getByRole('button', { name: /add a product/i })
    .first()
    .click()
  await expect(
    page.getByRole('dialog').getByRole('heading', { name: /add products/i }),
  ).toBeVisible()
}

/** Narrow to this spec's own fixtures — the catalogue holds other products. */
async function searchFor(page: Page, query: string) {
  await page.getByRole('dialog').getByRole('searchbox').fill(query)
  await expect(page.getByRole('button', { name: productName(query, 1) })).toBeVisible({
    timeout: 15_000,
  })
}

/** One per line on the document; the quantity cell every line renders. */
function quantityInputs(page: Page) {
  return page.getByRole('spinbutton', { name: /^ordered$/i })
}
