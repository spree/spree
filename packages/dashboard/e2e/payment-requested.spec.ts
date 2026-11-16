import { expect, type Page, test } from '@playwright/test'
import {
  adminRequest,
  type E2ELoginSession,
  FIXTURE_BOGUS_GATEWAY,
  FIXTURE_REQUESTED_CAPTURE_ORDER_EMAIL,
  FIXTURE_REQUESTED_VOID_ORDER_EMAIL,
  login,
} from './helpers'

// A provider such as Adyen accepts a capture, void or refund and reports the
// outcome later by webhook. The seeded Bogus gateway answers that way, and its
// webhook takes a plain outcome naming the record's reference.

type RequestedPayment = {
  id: string
  payment_method_id: string
  response_code: string
  capture_events?: { transaction_id: string | null }[]
}

async function openOrder(page: Page, email: string) {
  const creds = await login(page)
  const session: E2ELoginSession = { ...creds, store_id: creds.comma_store_id }
  const orders = await adminRequest<{ data: { id: string }[] }>(
    page,
    session,
    'get',
    `/orders?q[email_eq]=${encodeURIComponent(email)}`,
  )
  const orderId = orders.data[0].id
  await page.goto(`/${creds.comma_store_id}/orders/${orderId}`)
  return { session, orderId }
}

async function paymentOf(page: Page, session: E2ELoginSession, orderId: string) {
  const payments = await adminRequest<{ data: RequestedPayment[] }>(
    page,
    session,
    'get',
    `/orders/${orderId}/payments?expand=capture_events`,
  )
  return payments.data[0]
}

async function postOutcome(page: Page, paymentMethodId: string, outcome: Record<string, string>) {
  const res = await page.request.post(`/api/v3/webhooks/payments/${paymentMethodId}`, {
    data: outcome,
  })
  expect(res.ok(), `webhook: ${await res.text()}`).toBeTruthy()
}

const paymentRow = (page: Page) => page.locator('tr').filter({ hasText: FIXTURE_BOGUS_GATEWAY })

// The outcome is handled by a background job, so the page is reloaded until
// it shows.
async function expectAfterReload(page: Page, assertion: () => Promise<void>) {
  await expect(async () => {
    await page.reload()
    await assertion()
  }).toPass({ timeout: 30_000 })
}

async function openActions(page: Page) {
  await paymentRow(page)
    .getByRole('button', { name: /^actions$/i })
    .click({ timeout: 15_000 })
}

async function openPaymentDetails(page: Page) {
  await openActions(page)
  await page.getByRole('menuitem', { name: 'View details' }).click()
  return page.getByRole('dialog')
}

async function confirmAction(page: Page, name: RegExp) {
  await page
    .getByRole('alertdialog')
    .or(page.getByRole('dialog'))
    .getByRole('button', { name })
    .click()
}

test.describe('a payment waiting on its provider', () => {
  test('captures and refunds once the provider answers', async ({ page }) => {
    const { session, orderId } = await openOrder(page, FIXTURE_REQUESTED_CAPTURE_ORDER_EMAIL)

    await openActions(page)
    await page.getByRole('menuitem', { name: 'Capture' }).click()
    await confirmAction(page, /^capture$/i)

    await expect(paymentRow(page).getByText('Capture requested')).toBeVisible({ timeout: 15_000 })
    await openActions(page)
    await expect(page.getByRole('menuitem', { name: 'View details' })).toBeVisible()
    await expect(page.getByRole('menuitem', { name: 'Capture' })).toHaveCount(0)
    await expect(page.getByRole('menuitem', { name: 'Void' })).toHaveCount(0)
    await page.keyboard.press('Escape')

    const payment = await paymentOf(page, session, orderId)
    await postOutcome(page, payment.payment_method_id, {
      action: 'capture_succeeded',
      reference: payment.capture_events?.[0]?.transaction_id ?? '',
    })
    await expectAfterReload(page, async () => {
      await expect(paymentRow(page).getByText('completed')).toBeVisible({ timeout: 3_000 })
    })

    const refund = await adminRequest<{ transaction_id: string; status: string }>(
      page,
      session,
      'post',
      `/orders/${orderId}/refunds`,
      { payment_id: payment.id, amount: '5.00' },
    )
    expect(refund.status).toBe('requested')

    await page.reload()
    let dialog = await openPaymentDetails(page)
    await expect(dialog.getByTestId('payment-refund-row').getByText('Requested')).toBeVisible()
    await page.keyboard.press('Escape')

    await postOutcome(page, payment.payment_method_id, {
      action: 'refund_failed',
      reference: refund.transaction_id,
      reason: 'Account closed',
    })
    await expectAfterReload(page, async () => {
      dialog = await openPaymentDetails(page)
      const row = dialog.getByTestId('payment-refund-row')
      await expect(row.getByText('Failed')).toBeVisible({ timeout: 3_000 })
      await expect(row.getByText('Reason: Account closed')).toBeVisible()
    })
  })

  test('voids once the provider answers', async ({ page }) => {
    const { session, orderId } = await openOrder(page, FIXTURE_REQUESTED_VOID_ORDER_EMAIL)

    await openActions(page)
    await page.getByRole('menuitem', { name: 'Void' }).click()
    await confirmAction(page, /^void$/i)

    await expect(paymentRow(page).getByText('Void requested')).toBeVisible({ timeout: 15_000 })

    const payment = await paymentOf(page, session, orderId)
    await postOutcome(page, payment.payment_method_id, {
      action: 'void_succeeded',
      reference: payment.response_code,
    })
    await expectAfterReload(page, async () => {
      await expect(paymentRow(page).getByText(/^void$/)).toBeVisible({ timeout: 3_000 })
    })
  })
})
