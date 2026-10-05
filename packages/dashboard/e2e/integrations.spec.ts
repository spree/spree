import { expect, type Page, test } from '@playwright/test'
import { login } from './helpers'

const INTEGRATIONS_PATH = (storeId: string) => `/${storeId}/settings/integrations`

// Seeds its own payment method rather than toggling a shared one. The custom
// payment source type is hidden from the add-provider picker, so creating it
// cannot starve payment-methods.spec.ts of a provider it installs.
async function seedPaymentMethod(page: Page, storeId: string, accessToken: string, name: string) {
  const res = await page.request.post('/api/v3/admin/payment_methods', {
    headers: { 'X-Spree-Store-Id': storeId, Authorization: `Bearer ${accessToken}` },
    data: { type: 'custom_payment_source_method', name, active: true },
  })
  if (!res.ok()) {
    throw new Error(`Failed to seed payment method "${name}": ${res.status()} ${await res.text()}`)
  }
  return ((await res.json()) as { id: string }).id
}

async function deletePaymentMethod(page: Page, storeId: string, accessToken: string, id: string) {
  await page.request.delete(`/api/v3/admin/payment_methods/${id}`, {
    headers: { 'X-Spree-Store-Id': storeId, Authorization: `Bearer ${accessToken}` },
  })
}

function paymentMethodCard(page: Page, name: string) {
  const toggle = page.getByRole('switch', { name: `Turn ${name} on or off` })
  return { toggle, card: page.locator('[data-slot="card"]').filter({ has: toggle }) }
}

test.describe('integrations', () => {
  // The test app installs no provider gems, but payment providers ship with
  // core — so the gallery always lists them next to any service integrations.
  test('lists payment providers alongside integrations', async ({ page }) => {
    const creds = await login(page)
    await page.goto(INTEGRATIONS_PATH(creds.store_id))

    await expect(page.getByRole('heading', { name: /^integrations$/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByRole('heading', { name: /^payments$/i })).toBeVisible()
    await expect(page.getByRole('link', { name: /manage payment methods/i })).toBeVisible()
  })

  test('switches a payment method off and back on from its card', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Toggle PM ${Date.now()}`
    const id = await seedPaymentMethod(page, creds.store_id, creds.accessToken, name)

    try {
      await page.goto(`${INTEGRATIONS_PATH(creds.store_id)}?tab=payments`)
      const { toggle, card } = paymentMethodCard(page, name)
      await expect(toggle).toBeChecked({ timeout: 15_000 })

      await toggle.click()
      await expect(toggle).not.toBeChecked()
      await expect(card.getByText(/^disabled$/i)).toBeVisible()

      // Survives a reload, so the change was saved rather than only shown.
      await page.reload()
      await expect(toggle).not.toBeChecked({ timeout: 15_000 })

      await toggle.click()
      await expect(toggle).toBeChecked()
      await page.reload()
      await expect(toggle).toBeChecked({ timeout: 15_000 })
      await expect(card.getByText(/^active$/i)).toBeVisible()
    } finally {
      await deletePaymentMethod(page, creds.store_id, creds.accessToken, id)
    }
  })

  // The switch is optimistic: it moves before the server answers, which a
  // UI-only assertion cannot tell apart from a completed save. Holding the
  // request open is what proves both halves — moved early, reverted on failure.
  test('moves the switch at once and reverts it when the save fails', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Failing Toggle PM ${Date.now()}`
    const id = await seedPaymentMethod(page, creds.store_id, creds.accessToken, name)

    try {
      await page.goto(`${INTEGRATIONS_PATH(creds.store_id)}?tab=payments`)
      const { toggle, card } = paymentMethodCard(page, name)
      await expect(toggle).toBeChecked({ timeout: 15_000 })

      let releaseSave: () => void = () => {}
      const saveHeld = new Promise<void>((resolve) => {
        releaseSave = resolve
      })
      await page.route(`**/api/v3/admin/payment_methods/${id}`, async (route) => {
        if (route.request().method() !== 'PATCH') return route.fallback()
        await saveHeld
        await route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({ error: { code: 'internal_error', message: 'Server error' } }),
        })
      })

      await toggle.click()
      await expect(toggle).not.toBeChecked()
      await expect(card.getByText(/^disabled$/i)).toBeVisible()

      releaseSave()
      await expect(toggle).toBeChecked({ timeout: 15_000 })
      await expect(card.getByText(/^active$/i)).toBeVisible()
    } finally {
      await page.unrouteAll({ behavior: 'ignoreErrors' })
      await deletePaymentMethod(page, creds.store_id, creds.accessToken, id)
    }
  })

  // A second click while the first save is still open must win, even though
  // the first save finishes later — otherwise the older value overwrites it.
  test('saves the last choice when the switch is clicked again during a save', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Racing Toggle PM ${Date.now()}`
    const id = await seedPaymentMethod(page, creds.store_id, creds.accessToken, name)

    try {
      await page.goto(`${INTEGRATIONS_PATH(creds.store_id)}?tab=payments`)
      const { toggle } = paymentMethodCard(page, name)
      await expect(toggle).toBeChecked({ timeout: 15_000 })

      let releaseFirstSave: () => void = () => {}
      const firstSaveHeld = new Promise<void>((resolve) => {
        releaseFirstSave = resolve
      })
      let releaseSecondSave: () => void = () => {}
      const secondSaveHeld = new Promise<void>((resolve) => {
        releaseSecondSave = resolve
      })
      let saves = 0
      await page.route(`**/api/v3/admin/payment_methods/${id}`, async (route) => {
        if (route.request().method() !== 'PATCH') return route.fallback()
        saves += 1
        await (saves === 1 ? firstSaveHeld : secondSaveHeld)
        await route.fallback()
      })

      await toggle.click()
      await expect(toggle).not.toBeChecked()
      await toggle.click()
      await expect(toggle).toBeChecked()

      // Once the first save lands the list is refetched holding its value
      // (off). The switch must keep showing the latest choice regardless.
      const listRefetched = page.waitForResponse(
        (res) => res.request().method() === 'GET' && /\/payment_methods\?/.test(res.url()),
      )
      releaseFirstSave()
      await expect.poll(() => saves, { timeout: 15_000 }).toBe(2)
      // Let the refetched list reach the card before checking it; while the
      // second save is held, a card that dropped the latest choice stays off.
      await (await listRefetched).finished()
      await page.evaluate(
        () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))),
      )
      await expect(toggle).toBeChecked()

      releaseSecondSave()

      // The second save is forwarded, not awaited, by the route; wait for the
      // server to hold the final choice before reloading to read it back.
      await expect
        .poll(
          async () => {
            const res = await page.request.get(`/api/v3/admin/payment_methods/${id}`, {
              headers: {
                'X-Spree-Store-Id': creds.store_id,
                Authorization: `Bearer ${creds.accessToken}`,
              },
            })
            return ((await res.json()) as { active: boolean }).active
          },
          { timeout: 15_000 },
        )
        .toBe(true)

      await page.unrouteAll({ behavior: 'wait' })
      await page.reload()
      await expect(toggle).toBeChecked({ timeout: 15_000 })
    } finally {
      await page.unrouteAll({ behavior: 'ignoreErrors' })
      await deletePaymentMethod(page, creds.store_id, creds.accessToken, id)
    }
  })
})
