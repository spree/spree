import { type Browser, expect, type Page, test } from '@playwright/test'
import {
  addNewOrderItem,
  addTeammate,
  adminRequest,
  deleteSeededRecords,
  FIXTURE_PROMO_PRODUCT,
  FIXTURE_PROMO_SKU,
  login,
  section,
  seedRecord,
  TEAMMATE_PASSWORD,
} from './helpers'

const ROLE_ENDPOINT = /\/api\/v3\/admin\/roles$/

/** What the Order manager role template ticks. */
const ORDER_MANAGER_PERMISSIONS = [
  'write_orders',
  'write_payments',
  'write_fulfillments',
  'write_refunds',
  'write_gift_cards',
  'write_store_credits',
  'read_customers',
  'read_products',
]

/** Opens the new-order page as the teammate, in a browser context of their own. */
async function asTeammate(
  browser: Browser,
  page: Page,
  storeId: string,
  email: string,
  run: (teammate: Page) => Promise<void>,
) {
  const context = await browser.newContext({ baseURL: new URL(page.url()).origin })
  try {
    const teammate = await context.newPage()
    await login(teammate, { email, password: TEAMMATE_PASSWORD })
    await teammate.goto(`/${storeId}/orders/new`)
    await expect(teammate.getByRole('heading', { name: /new order/i })).toBeVisible({
      timeout: 15_000,
    })
    await run(teammate)
  } finally {
    await context.close()
  }
}

// Adding an item to an order searches the catalog, so a role made from the
// Order manager template has to be able to find products without being able
// to change them.
test.describe('order manager permissions', () => {
  test('a teammate with the Order manager template adds a product to a new order', async ({
    page,
    browser,
  }) => {
    const session = await login(page)
    const stamp = Date.now()
    const email = `e2e-order-manager-${stamp}@example.com`

    await page.goto(`/${session.store_id}/settings/roles`)
    await page.getByRole('button', { name: /add role/i }).click()
    const sheet = page.getByRole('dialog')
    await sheet.getByRole('button', { name: /^order manager$/i }).click()
    await expect(sheet.getByRole('checkbox', { name: /view products/i })).toBeChecked()
    await expect(sheet.getByRole('checkbox', { name: /manage products/i })).not.toBeChecked()
    await page.locator('#role-name').fill(`e2e-order-manager-${stamp}`)

    // The role's id is shown nowhere, and the invitation needs it.
    const created = page.waitForResponse(
      (response) =>
        response.request().method() === 'POST' &&
        ROLE_ENDPOINT.test(new URL(response.url()).pathname),
    )
    await sheet.getByRole('button', { name: /^save$/i }).click()
    const role = (await (await created).json()) as { id: string }
    await expect(sheet).toHaveCount(0, { timeout: 15_000 })

    await addTeammate(page, session, email, role.id)

    await asTeammate(browser, page, session.store_id, email, async (teammate) => {
      await addNewOrderItem(teammate, FIXTURE_PROMO_PRODUCT)
      await expect(
        teammate.getByRole('spinbutton', {
          name: new RegExp(`^quantity of ${FIXTURE_PROMO_PRODUCT}`, 'i'),
        }),
      ).toHaveValue('1')
    })
  })

  // A role made before the template included products still cannot search,
  // and the picker says why instead of reporting no matches.
  test('tells a teammate who cannot view products why the search is unavailable', async ({
    page,
    browser,
  }) => {
    const session = await login(page)
    const stamp = Date.now()
    const email = `e2e-orders-no-products-${stamp}@example.com`
    const role = await adminRequest<{ id: string }>(page, session, 'post', '/roles', {
      name: `e2e-orders-no-products-${stamp}`,
      permissions: ['write_orders', 'read_customers'],
    })
    await addTeammate(page, session, email, role.id)

    await asTeammate(browser, page, session.store_id, email, async (teammate) => {
      await teammate
        .getByRole('button', { name: /^add product$/i })
        .first()
        .click()
      const picker = teammate.getByRole('dialog', { name: /add line item/i })
      await expect(picker.getByText(/your role cannot view products/i)).toBeVisible()
      await expect(picker.getByPlaceholder(/product name or sku/i)).toBeDisabled()
    })
  })

  test.describe('adding a payment', () => {
    test.afterEach(async ({ page }) => deleteSeededRecords(page))

    // The payment methods are configured under Settings, which the template
    // leaves out; the add-payment dialog still has to list them.
    test('a teammate with the Order manager permissions adds a payment to an order', async ({
      page,
      browser,
    }) => {
      const session = await login(page)
      const stamp = Date.now()
      const email = `e2e-order-manager-payment-${stamp}@example.com`
      const methodName = `E2E Bank transfer ${stamp}`
      await seedRecord(page, session, '/payment_methods', {
        type: 'check',
        name: methodName,
        active: true,
      })
      const variants = await adminRequest<{ data: { id: string }[] }>(
        page,
        session,
        'get',
        `/variants?q[sku_eq]=${FIXTURE_PROMO_SKU}`,
      )
      const order = await adminRequest<{ id: string }>(page, session, 'post', '/orders', {
        email: `e2e-order-manager-order-${stamp}@example.com`,
        items: [{ variant_id: variants.data[0].id, quantity: 1 }],
      })
      const role = await adminRequest<{ id: string }>(page, session, 'post', '/roles', {
        name: `e2e-order-manager-payments-${stamp}`,
        permissions: ORDER_MANAGER_PERMISSIONS,
      })
      await addTeammate(page, session, email, role.id)

      const context = await browser.newContext({ baseURL: new URL(page.url()).origin })
      try {
        const teammate = await context.newPage()
        await login(teammate, { email, password: TEAMMATE_PASSWORD })
        await teammate.goto(`/${session.store_id}/orders/${order.id}`)
        const payments = section(teammate, /^payments/i)
        await payments.getByRole('button', { name: /^add$/i }).click({ timeout: 15_000 })
        const dialog = teammate.getByRole('dialog')
        await dialog.locator('#pay-method').click()
        await teammate.getByRole('option', { name: methodName }).click()
        await dialog.getByRole('button', { name: /^add$/i }).click()
        await expect(dialog).toBeHidden()
        await expect(payments.locator('tr').filter({ hasText: methodName })).toHaveCount(1)
      } finally {
        await context.close()
      }
    })
  })
})
