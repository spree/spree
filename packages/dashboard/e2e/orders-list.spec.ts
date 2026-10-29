import { expect, type Page, test } from '@playwright/test'
import {
  addRecordFilter,
  addTextFilter,
  adminRequest,
  createPlacedOrder,
  type E2ELoginSession,
  FIXTURE_PROMO_SKU,
  login,
  narrowQuickFilter,
  searchList,
  sortList,
} from './helpers'

const ORDERS_PATH = (storeId: string) => `/${storeId}/orders`
const SEARCH = /search by number/i

/**
 * Two placed orders only this test owns: a shipped single item and an
 * unshipped three-item order, billed to names that carry a shared stamp.
 */
async function seedOrders(page: Page, session: E2ELoginSession, largeLocale?: string) {
  const stamp = `${Date.now()}`
  const lastName = `Listtest${stamp}`
  const small = {
    firstName: `Alda${stamp}`,
    ...(await createPlacedOrder(page, session.accessToken, {
      quantity: 1,
      firstName: `Alda${stamp}`,
      lastName,
    })),
  }
  const large = {
    firstName: `Bruno${stamp}`,
    ...(await createPlacedOrder(page, session.accessToken, {
      quantity: 3,
      ship: false,
      firstName: `Bruno${stamp}`,
      lastName,
      locale: largeLocale,
    })),
  }

  return { lastName, small, large }
}

async function openOrders(page: Page, storeId: string, columns?: string[]) {
  await page.goto(`${ORDERS_PATH(storeId)}${columns ? `?columns=${columns.join(',')}` : ''}`)
  await expect(page.getByRole('heading', { name: /^orders$/i })).toBeVisible({ timeout: 15_000 })
}

const row = (page: Page, number: string) => page.getByRole('row').filter({ hasText: number })

test.describe('orders list', () => {
  test('searches by order number and by billing name', async ({ page }) => {
    const session = await login(page)
    const { small, large } = await seedOrders(page, session)
    await openOrders(page, session.store_id)

    await searchList(page, SEARCH, small.number)
    await expect(row(page, small.number)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, large.number)).toBeHidden()

    await searchList(page, SEARCH, large.firstName)
    await expect(row(page, large.number)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, small.number)).toBeHidden()
  })

  test('filters by billing first name', async ({ page }) => {
    const session = await login(page)
    const { small, large } = await seedOrders(page, session)
    await openOrders(page, session.store_id)

    await addTextFilter(page, /^first name$/i, /^contains$/i, small.firstName)

    await expect(row(page, small.number)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, large.number)).toBeHidden()
  })

  test('filters by fulfillment status', async ({ page }) => {
    const session = await login(page)
    const { lastName, small, large } = await seedOrders(page, session)
    await openOrders(page, session.store_id)
    await addTextFilter(page, /^last name$/i, /^contains$/i, lastName)
    await expect(row(page, small.number)).toBeVisible({ timeout: 15_000 })

    await narrowQuickFilter(page, /^fulfillment/i, /^unfulfilled$/i)

    await expect(row(page, large.number)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, small.number)).toBeHidden()
  })

  test('filters by total', async ({ page }) => {
    const session = await login(page)
    const { lastName, small, large } = await seedOrders(page, session)
    await openOrders(page, session.store_id)
    await addTextFilter(page, /^last name$/i, /^contains$/i, lastName)
    await expect(row(page, small.number)).toBeVisible({ timeout: 15_000 })

    await addTextFilter(page, /^total$/i, /^greater than$/i, small.total)

    await expect(row(page, large.number)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, small.number)).toBeHidden()
  })

  test('filters by SKU', async ({ page }) => {
    const session = await login(page)
    const { small } = await seedOrders(page, session)
    await openOrders(page, session.store_id)
    await addTextFilter(page, /^first name$/i, /^contains$/i, small.firstName)
    await expect(row(page, small.number)).toBeVisible({ timeout: 15_000 })

    await addTextFilter(page, /^sku$/i, /^contains$/i, 'NO-SUCH-SKU')
    await expect(row(page, small.number)).toBeHidden({ timeout: 15_000 })

    await page
      .getByRole('button', { name: /remove filter/i })
      .last()
      .click()
    await addTextFilter(page, /^sku$/i, /^contains$/i, FIXTURE_PROMO_SKU)
    await expect(row(page, small.number)).toBeVisible({ timeout: 15_000 })
  })

  test('sorts by total', async ({ page }) => {
    const session = await login(page)
    const { lastName, small, large } = await seedOrders(page, session)
    await openOrders(page, session.store_id)
    await addTextFilter(page, /^last name$/i, /^contains$/i, lastName)
    await expect(row(page, small.number)).toBeVisible({ timeout: 15_000 })

    const firstRow = page.getByRole('row').nth(1)
    await sortList(page, /^total$/i, 'descending')
    await expect(firstRow).toContainText(large.number, { timeout: 15_000 })

    await sortList(page, /^total$/i, 'ascending')
    await expect(firstRow).toContainText(small.number, { timeout: 15_000 })
  })

  test('shows and filters by market and locale', async ({ page }) => {
    const session = await login(page)
    // `de` is a locale the seeded US market offers (see global-setup).
    const { lastName, small, large } = await seedOrders(page, session, 'de')
    const markets = await adminRequest<{ data: { name: string; currency: string }[] }>(
      page,
      session,
      'get',
      '/markets?limit=100',
    )
    const usMarket = markets.data.find((market) => market.currency === 'USD')?.name as string
    await openOrders(page, session.store_id, ['number', 'market', 'locale'])
    await addTextFilter(page, /^last name$/i, /^contains$/i, lastName)

    await expect(row(page, small.number)).toContainText(usMarket, { timeout: 15_000 })
    await expect(
      row(page, large.number).getByRole('cell', { name: 'DE — German', exact: true }),
    ).toBeVisible()

    await addRecordFilter(page, /^locale$/i, 'German')
    await expect(row(page, large.number)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, small.number)).toBeHidden()

    await page
      .getByRole('button', { name: /remove filter/i })
      .last()
      .click()
    await addRecordFilter(page, /^market$/i, 'Europe')
    await expect(row(page, small.number)).toBeHidden({ timeout: 15_000 })
    await expect(row(page, large.number)).toBeHidden()
  })
})
