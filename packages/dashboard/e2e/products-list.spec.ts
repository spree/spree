import { expect, type Page, test } from '@playwright/test'
import {
  addRecordFilter,
  addTextFilter,
  adminRequest,
  deleteSeededRecords,
  type E2ELoginSession,
  FIXTURE_PROMO_TAXON,
  gotoIndex,
  login,
  narrowQuickFilter,
  searchList,
  seedRecord,
  sortList,
} from './helpers'

const PRODUCTS_PATH = (storeId: string) => `/${storeId}/products`
const CTA = /add product/i
const SEARCH = /^search…$/i

/**
 * Three products only this test owns, told apart from the rest of the
 * catalog by a shared stamp in their names.
 */
async function seedProducts(page: Page, session: E2ELoginSession) {
  const stamp = `${Date.now()}`
  const categories = await adminRequest<{ data: { id: string }[] }>(
    page,
    session,
    'get',
    `/categories?q[name_eq]=${encodeURIComponent(FIXTURE_PROMO_TAXON)}`,
  )
  const create = (name: string, status: string, amount: string, extra: object = {}) =>
    seedRecord<{ id: string; default_variant_id: string }>(page, session, '/products', {
      name,
      status,
      prices: [{ amount, currency: 'USD' }],
      ...extra,
    })

  const cheap = { name: `E2E List Cheap ${stamp}`, sku: `E2E-LIST-${stamp}` }
  const pricey = { name: `E2E List Pricey ${stamp}` }
  const draft = { name: `E2E List Draft ${stamp}` }

  const created = await create(cheap.name, 'active', '5.00', {
    category_ids: [categories.data[0].id],
  })
  await adminRequest(
    page,
    session,
    'patch',
    `/products/${created.id}/variants/${created.default_variant_id}`,
    { sku: cheap.sku },
  )
  await create(pricey.name, 'active', '500.00')
  await create(draft.name, 'draft', '50.00')

  return { stamp, cheap, pricey, draft }
}

const row = (page: Page, name: string) => page.getByRole('row').filter({ hasText: name })

test.describe('products list', () => {
  test.afterEach(({ page }) => deleteSeededRecords(page))

  test('searches by name and by SKU', async ({ page }) => {
    const session = await login(page)
    const { stamp, cheap, pricey, draft } = await seedProducts(page, session)
    await gotoIndex(page, PRODUCTS_PATH(session.store_id), CTA)

    await searchList(page, SEARCH, stamp)
    for (const product of [cheap, pricey, draft]) {
      await expect(row(page, product.name)).toBeVisible({ timeout: 15_000 })
    }

    await searchList(page, SEARCH, cheap.sku)
    await expect(row(page, cheap.name)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, pricey.name)).toBeHidden()
  })

  test('shows how many units are in stock', async ({ page }) => {
    const session = await login(page)
    const locations = await adminRequest<{ data: { id: string }[] }>(
      page,
      session,
      'get',
      '/stock_locations',
    )
    const name = `Stocked ${Date.now()}`
    await seedRecord(page, session, '/products', {
      name,
      status: 'active',
      prices: [{ amount: '10.00', currency: 'USD' }],
      variants: [
        {
          options: [],
          track_inventory: true,
          stock_levels: [
            { stock_location_id: locations.data[0].id, count_on_hand: 7, backorderable: false },
          ],
        },
      ],
    })

    await gotoIndex(page, PRODUCTS_PATH(session.store_id), CTA)
    await searchList(page, SEARCH, name)
    await expect(row(page, name).getByText(/^7 in stock$/i)).toBeVisible({ timeout: 15_000 })
  })

  test('filters by status', async ({ page }) => {
    const session = await login(page)
    const { stamp, cheap, draft } = await seedProducts(page, session)
    await gotoIndex(page, PRODUCTS_PATH(session.store_id), CTA)
    await searchList(page, SEARCH, stamp)
    await expect(row(page, cheap.name)).toBeVisible({ timeout: 15_000 })

    await narrowQuickFilter(page, /^status/i, /^draft$/i)

    await expect(row(page, draft.name)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, cheap.name)).toBeHidden()
  })

  test('filters by price', async ({ page }) => {
    const session = await login(page)
    const { stamp, cheap, pricey } = await seedProducts(page, session)
    await gotoIndex(page, PRODUCTS_PATH(session.store_id), CTA)
    await searchList(page, SEARCH, stamp)
    await expect(row(page, cheap.name)).toBeVisible({ timeout: 15_000 })

    await addTextFilter(page, /^price$/i, /^greater than$/i, '100')

    await expect(row(page, pricey.name)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, cheap.name)).toBeHidden()
  })

  test('filters by category', async ({ page }) => {
    const session = await login(page)
    const { stamp, cheap, pricey } = await seedProducts(page, session)
    await gotoIndex(page, PRODUCTS_PATH(session.store_id), CTA)
    await searchList(page, SEARCH, stamp)
    await expect(row(page, pricey.name)).toBeVisible({ timeout: 15_000 })

    await addRecordFilter(page, /^categories$/i, FIXTURE_PROMO_TAXON)

    await expect(row(page, cheap.name)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, pricey.name)).toBeHidden()
  })

  test('sorts by price', async ({ page }) => {
    const session = await login(page)
    const { stamp, cheap, pricey } = await seedProducts(page, session)
    await gotoIndex(page, PRODUCTS_PATH(session.store_id), CTA)
    await searchList(page, SEARCH, stamp)
    await expect(row(page, cheap.name)).toBeVisible({ timeout: 15_000 })

    const firstRow = page.getByRole('row').nth(1)
    await sortList(page, /^price$/i, 'descending')
    await expect(firstRow).toContainText(pricey.name, { timeout: 15_000 })

    await sortList(page, /^price$/i, 'ascending')
    await expect(firstRow).toContainText(cheap.name, { timeout: 15_000 })
  })

  test('switches every table to compact rows and remembers the choice', async ({ page }) => {
    const creds = await login(page)
    await page.goto(PRODUCTS_PATH(creds.store_id))

    // A product's row, not the loading placeholder the table shows first.
    const firstRow = page
      .locator('tbody tr')
      .filter({ has: page.locator('[data-slot="thumbnail"]') })
      .first()
    await expect(firstRow).toBeVisible({ timeout: 15_000 })
    const comfortable = (await firstRow.boundingBox())?.height ?? 0

    await page.getByRole('button', { name: /^columns$/i }).click()
    await page.getByRole('menuitemradio', { name: /^compact$/i }).click()
    await expect(page.getByRole('menuitemradio', { name: /^compact$/i })).toBeChecked()
    await page.keyboard.press('Escape')

    await expect
      .poll(async () => (await firstRow.boundingBox())?.height ?? 0)
      .toBeLessThan(comfortable)

    // A per-browser preference: it survives a reload and reaches other lists.
    await page.goto(`/${creds.store_id}/orders`)
    await expect(page.locator('html')).toHaveAttribute('data-table-density', 'compact')

    await page.getByRole('button', { name: /^columns$/i }).click()
    await page.getByRole('menuitemradio', { name: /^comfortable$/i }).click()
    await expect(page.locator('html')).not.toHaveAttribute('data-table-density', 'compact')
  })
})
