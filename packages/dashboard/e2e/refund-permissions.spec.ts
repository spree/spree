import { expect, request, test } from '@playwright/test'
import { adminRequest, createPlacedOrder, invitationAcceptancePath, login } from './helpers'

// Paying a customer back takes the refunds permission, so a teammate whose
// role handles orders but not refunds must not be offered it.
test.describe('refund permissions', () => {
  test('hides the refund choice from staff without the refunds permission', async ({ page }) => {
    const session = await login(page)
    const order = await createPlacedOrder(page, session.accessToken, { ship: false })
    const stamp = Date.now()
    const password = 'e2e-password-123'
    const email = `e2e-orders-only-${stamp}@example.com`

    const role = await adminRequest<{ id: string }>(page, session, 'post', '/roles', {
      name: `e2e-orders-only-${stamp}`,
      permissions: ['read_orders', 'write_orders', 'read_customers', 'read_products'],
    })
    const invitation = await adminRequest<{ id: string }>(page, session, 'post', '/invitations', {
      email,
      role_id: role.id,
    })
    const acceptance = new URL(
      await invitationAcceptancePath(page, session, `/api/v3/admin/invitations/${invitation.id}`),
      'http://localhost',
    )
    const invitee = await request.newContext({ baseURL: new URL(page.url()).origin })
    try {
      const accepted = await invitee.post(
        `/api/v3/admin/auth/invitations/${invitation.id}/accept`,
        {
          data: {
            token: acceptance.searchParams.get('token'),
            password,
            password_confirmation: password,
            first_name: 'Robin',
            last_name: 'Teammate',
          },
        },
      )
      expect(accepted.ok(), await accepted.text()).toBeTruthy()
    } finally {
      await invitee.dispose()
    }

    // The admin, who may refund, is offered the choice when cancelling.
    await page.goto(`/${session.store_id}/orders/${order.id}`)
    await page.getByRole('button', { name: /more actions/i }).click()
    await page.getByRole('menuitem', { name: /cancel order/i }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByRole('checkbox', { name: /refund the customer/i })).toBeVisible({
      timeout: 15_000,
    })
    await page.keyboard.press('Escape')

    // The teammate is not.
    await login(page, { email, password })
    await page.goto(`/${session.store_id}/orders/${order.id}`)
    await page.getByRole('button', { name: /more actions/i }).click()
    await page.getByRole('menuitem', { name: /cancel order/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible({ timeout: 15_000 })
    await expect(
      page.getByRole('dialog').getByRole('checkbox', { name: /refund the customer/i }),
    ).toHaveCount(0)
  })
})
