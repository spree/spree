import { expect, type Page, test } from '@playwright/test'
import {
  addListFilter,
  addTextFilter,
  adminRequest,
  type E2ELoginSession,
  gotoIndex,
  login,
  searchList,
  sortList,
} from './helpers'

const CUSTOMERS_PATH = (storeId: string) => `/${storeId}/customers`
const CTA = /new customer/i
const SEARCH = /search by email or name/i

/**
 * Two customers only this test owns, sharing a stamped last name: one
 * subscribed to the newsletter with a phone number, one neither.
 */
async function seedCustomers(page: Page, session: E2ELoginSession) {
  const stamp = `${Date.now()}`
  const lastName = `Listtest${stamp}`
  const subscriber = {
    email: `a-list-${stamp}@example.com`,
    first_name: 'Ada',
    last_name: lastName,
    phone: `555${stamp.slice(-7)}`,
    accepts_email_marketing: true,
  }
  const other = {
    email: `b-list-${stamp}@example.com`,
    first_name: 'Ben',
    last_name: lastName,
    accepts_email_marketing: false,
  }
  await adminRequest(page, session, 'post', '/customers', subscriber)
  await adminRequest(page, session, 'post', '/customers', other)

  return { lastName, subscriber, other }
}

const row = (page: Page, email: string) => page.getByRole('row').filter({ hasText: email })

test.describe('customers list', () => {
  test('searches by name and by email', async ({ page }) => {
    const session = await login(page)
    const { lastName, subscriber, other } = await seedCustomers(page, session)
    await gotoIndex(page, CUSTOMERS_PATH(session.store_id), CTA)

    await searchList(page, SEARCH, lastName)
    await expect(row(page, subscriber.email)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, other.email)).toBeVisible()

    await searchList(page, SEARCH, other.email)
    await expect(row(page, other.email)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, subscriber.email)).toBeHidden()
  })

  test('filters by newsletter subscription', async ({ page }) => {
    const session = await login(page)
    const { lastName, subscriber, other } = await seedCustomers(page, session)
    await gotoIndex(page, CUSTOMERS_PATH(session.store_id), CTA)
    await searchList(page, SEARCH, lastName)
    await expect(row(page, other.email)).toBeVisible({ timeout: 15_000 })

    await addListFilter(page, /^newsletter$/i, /^yes$/i)

    await expect(row(page, subscriber.email)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, other.email)).toBeHidden()
  })

  test('filters by phone', async ({ page }) => {
    const session = await login(page)
    const { lastName, subscriber, other } = await seedCustomers(page, session)
    await gotoIndex(page, CUSTOMERS_PATH(session.store_id), CTA)
    await searchList(page, SEARCH, lastName)
    await expect(row(page, other.email)).toBeVisible({ timeout: 15_000 })

    await addTextFilter(page, /^phone$/i, /^contains$/i, subscriber.phone.slice(-7))

    await expect(row(page, subscriber.email)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, other.email)).toBeHidden()
  })

  test('sorts by email', async ({ page }) => {
    const session = await login(page)
    const { lastName, subscriber, other } = await seedCustomers(page, session)
    await gotoIndex(page, CUSTOMERS_PATH(session.store_id), CTA)
    await searchList(page, SEARCH, lastName)
    await expect(row(page, other.email)).toBeVisible({ timeout: 15_000 })

    const firstRow = page.getByRole('row').nth(1)
    await sortList(page, /^email$/i, 'descending')
    await expect(firstRow).toContainText(other.email, { timeout: 15_000 })

    await sortList(page, /^email$/i, 'ascending')
    await expect(firstRow).toContainText(subscriber.email, { timeout: 15_000 })
  })
})
