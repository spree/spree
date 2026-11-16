import { expect, request, test } from '@playwright/test'
import {
  addNewOrderItem,
  adminRequest,
  FIXTURE_PROMO_PRODUCT,
  invitationAcceptancePath,
  login,
} from './helpers'

// Adding an item to an order searches the catalog, so a role made from the
// Order manager template has to be able to find products without being able
// to change them.
test.describe('order manager permissions', () => {
  test('a teammate with the Order manager template adds a product to a new order', async ({
    page,
  }) => {
    const session = await login(page)
    const stamp = Date.now()
    const password = 'e2e-password-123'
    const email = `e2e-order-manager-${stamp}@example.com`
    const roleName = `e2e-order-manager-${stamp}`

    await page.goto(`/${session.store_id}/settings/roles`)
    await page.getByRole('button', { name: /add role/i }).click()
    const sheet = page.getByRole('dialog')
    await sheet.getByRole('button', { name: /^order manager$/i }).click()
    await expect(sheet.getByRole('checkbox', { name: /view products/i })).toBeChecked()
    await expect(sheet.getByRole('checkbox', { name: /manage products/i })).not.toBeChecked()
    await page.locator('#role-name').fill(roleName)

    // The role's id is not shown anywhere, and the invitation needs it.
    const created = page.waitForResponse(
      (response) => response.request().method() === 'POST' && /\/roles$/.test(response.url()),
    )
    await sheet.getByRole('button', { name: /^save$/i }).click()
    const role = (await (await created).json()) as { id: string }
    await expect(sheet).toHaveCount(0, { timeout: 15_000 })

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

    await login(page, { email, password })
    await page.goto(`/${session.store_id}/orders/new`)
    await expect(page.getByRole('heading', { name: /new order/i })).toBeVisible({
      timeout: 15_000,
    })

    await addNewOrderItem(page, FIXTURE_PROMO_PRODUCT)

    await expect(
      page.getByRole('spinbutton', {
        name: new RegExp(`^quantity of ${FIXTURE_PROMO_PRODUCT}`, 'i'),
      }),
    ).toHaveValue('1')
  })
})
