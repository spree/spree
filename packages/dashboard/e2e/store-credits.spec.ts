import { expect, type Page, test } from '@playwright/test'
import { escapeRegex, FIXTURE_PROMO_CUSTOMER_EMAIL, login } from './helpers'

const STORE_CREDITS_PATH = (storeId: string) => `/${storeId}/loyalty/store-credits`

/** Issues a credit to the fixture customer, the way the customer page does. */
async function issueStoreCredit(page: Page, accessToken: string, memo: string) {
  const headers = { Authorization: `Bearer ${accessToken}` }
  const customers = await page.request
    .get('/api/v3/admin/customers', {
      headers,
      params: { 'q[email_eq]': FIXTURE_PROMO_CUSTOMER_EMAIL },
    })
    .then((res) => res.json())
  const created = await page.request.post(
    `/api/v3/admin/customers/${customers.data[0].id}/store_credits`,
    { headers, data: { amount: 40, currency: 'USD', memo } },
  )
  expect(created.status(), await created.text()).toBe(201)
}

test.describe('store credits', () => {
  test('lists issued credit beside what the store still owes', async ({ page }) => {
    const creds = await login(page)
    const memo = `E2E goodwill ${Date.now()}`
    await issueStoreCredit(page, creds.accessToken, memo)

    await page.goto(STORE_CREDITS_PATH(creds.store_id))
    await expect(page.getByText(/^outstanding$/i).first()).toBeVisible({ timeout: 15_000 })

    await page.getByRole('searchbox').fill(memo)
    const row = page.getByRole('row').filter({ hasText: memo })
    await expect(row).toHaveCount(1, { timeout: 15_000 })
    await expect(row.getByText(FIXTURE_PROMO_CUSTOMER_EMAIL)).toBeVisible()
    await expect(row.getByText('$40.00').first()).toBeVisible()
  })

  test('opens a credit and follows it to the customer', async ({ page }) => {
    const creds = await login(page)
    const memo = `E2E refund credit ${Date.now()}`
    await issueStoreCredit(page, creds.accessToken, memo)

    await page.goto(STORE_CREDITS_PATH(creds.store_id))
    await page.getByRole('searchbox').fill(memo)
    await page
      .getByRole('button', {
        name: new RegExp(`${escapeRegex(FIXTURE_PROMO_CUSTOMER_EMAIL)}.*${escapeRegex(memo)}`),
      })
      .click()

    const sheet = page.getByRole('dialog')
    await expect(sheet.getByText(memo)).toBeVisible({ timeout: 15_000 })
    await expect(sheet.getByRole('heading', { name: /^ledger$/i })).toBeVisible()

    await sheet.getByRole('link', { name: /open customer profile/i }).click()
    await expect(page).toHaveURL(/\/customers\/cust_/, { timeout: 15_000 })
    await expect(page.getByText(FIXTURE_PROMO_CUSTOMER_EMAIL).first()).toBeVisible()
  })
})
