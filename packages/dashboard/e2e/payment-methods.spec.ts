import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const PAYMENT_METHODS_PATH = (storeId: string) => `/${storeId}/settings/payment-methods`
const CTA = /add payment method/i

async function selectProvider(page: Page, label: string) {
  await page.locator('#type').click()
  await page.getByRole('option', { name: label }).click()
}

// Each provider can only be installed once per store (the "types" endpoint
// filters out already-installed providers from the picker). Tests run
// serially against a shared DB, so each lifecycle test claims a different
// provider so they don't starve each other.
test.describe.configure({ mode: 'serial' })

test.describe('payment methods', () => {
  test('lists payment methods', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PAYMENT_METHODS_PATH(creds.store_id), CTA)
  })

  // Runs BEFORE the lifecycle tests so both providers it switches between are
  // still in the dropdown (the lifecycle tests below consume them).
  test('swaps the preferences editor when the provider changes', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PAYMENT_METHODS_PATH(creds.store_id), CTA)

    await page.getByRole('button', { name: /add payment method/i }).click()
    await expect(page.getByRole('heading', { name: /add payment method/i })).toBeVisible()

    // Bogus has two `preference` fields (`dummy_key` + `dummy_secret_key`).
    // Check has none. Picking each in turn proves the preferences panel
    // swaps with the provider — the core UX promise of the create flow.
    await selectProvider(page, 'Bogus')
    await expect(page.getByText(/dummy key/i).first()).toBeVisible({ timeout: 5_000 })
    await expect(page.getByText(/dummy secret key/i).first()).toBeVisible()

    await selectProvider(page, 'Check')
    await expect(page.getByText(/dummy key/i)).toHaveCount(0)
    await expect(page.getByText(/dummy secret key/i)).toHaveCount(0)
  })

  test('creates a new payment method (Bogus provider)', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PAYMENT_METHODS_PATH(creds.store_id), CTA)

    const name = `E2E Bogus ${Date.now()}`

    await page.getByRole('button', { name: /add payment method/i }).click()
    await expect(page.getByRole('heading', { name: /add payment method/i })).toBeVisible()

    await selectProvider(page, 'Bogus')
    await page.locator('#name').fill(name)
    await page.getByRole('button', { name: /create payment method/i }).click()

    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
  })

  test('edits a payment method', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PAYMENT_METHODS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const original = `E2E Edit PM ${suffix}`
    const updated = `${original} (updated)`

    await page.getByRole('button', { name: /add payment method/i }).click()
    await selectProvider(page, 'Check')
    await page.locator('#name').fill(original)
    await page.getByRole('button', { name: /create payment method/i }).click()
    await expect(rowButton(page, original)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, original).click()
    await expect(page.getByRole('heading', { name: original })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#name')).toHaveValue(original)

    await page.locator('#name').fill(updated)
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(rowButton(page, updated)).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a payment method', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PAYMENT_METHODS_PATH(creds.store_id), CTA)

    const name = `E2E Delete PM ${Date.now()}`

    await page.getByRole('button', { name: /add payment method/i }).click()
    await selectProvider(page, 'Custom Payment Source Method')
    await page.locator('#name').fill(name)
    await page.getByRole('button', { name: /create payment method/i }).click()
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    // Delete now lives on the row-action kebab.
    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete payment method\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
