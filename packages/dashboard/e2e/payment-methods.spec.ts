import { expect, type Page, test } from '@playwright/test'
import {
  adminRequest,
  gotoIndex,
  login,
  openRowMenu,
  rowButton,
  saveCustomFieldInSheet,
  withCustomFieldDefinition,
} from './helpers'

const PAYMENT_METHODS_PATH = (storeId: string) => `/${storeId}/settings/payment-methods`
const CTA = /add payment method/i

async function selectProvider(page: Page, label: string) {
  await page.locator('#type').click()
  await page.getByRole('option', { name: label }).click()
}

// Tests run serially against a shared DB.
test.describe.configure({ mode: 'serial' })

test.describe('payment methods', () => {
  test('lists payment methods', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PAYMENT_METHODS_PATH(creds.store_id), CTA)
  })

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

  test('deletes a payment method', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PAYMENT_METHODS_PATH(creds.store_id), CTA)

    const name = `E2E Delete PM ${Date.now()}`

    await page.getByRole('button', { name: /add payment method/i }).click()
    await selectProvider(page, 'Check')
    await page.locator('#name').fill(name)
    await page.getByRole('button', { name: /create payment method/i }).click()
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete payment method\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })

  test('creates a payment method with provider settings, keeping its secret on edit', async ({
    page,
  }) => {
    const creds = await login(page)
    await gotoIndex(page, PAYMENT_METHODS_PATH(creds.store_id), CTA)

    const name = `E2E Bogus ${Date.now()}`

    await page.getByRole('button', { name: /add payment method/i }).click()
    await expect(page.getByRole('heading', { name: /add payment method/i })).toBeVisible()

    await selectProvider(page, 'Bogus')
    await page.locator('#name').fill(name)
    await page.locator('#preference-dummy_key').fill('E2EPUBLIC')
    await page.locator('#preference-dummy_secret_key').fill('e2e-secret-9876')
    await page.getByRole('button', { name: /create payment method/i }).click()

    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    // The installed provider's settings come back on edit: the plain one as
    // typed, the secret only as a mask of its last characters.
    await rowButton(page, name).click()
    await expect(page.locator('#preference-dummy_key')).toHaveValue('E2EPUBLIC', {
      timeout: 15_000,
    })
    const secret = page.locator('#preference-dummy_secret_key')
    await expect(secret).toHaveText(/^•+9876$/)

    // Saving without touching the secret keeps it.
    const updated = `${name} (updated)`
    await page.locator('#name').fill(updated)
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(rowButton(page, updated)).toBeVisible({ timeout: 15_000 })

    await page.reload()
    await rowButton(page, updated).click()
    await expect(page.locator('#preference-dummy_key')).toHaveValue('E2EPUBLIC', {
      timeout: 15_000,
    })
    await expect(secret).toHaveText(/^•+9876$/)
    await page.keyboard.press('Escape')

    // An installed provider stays in the picker — a second record is how a
    // store runs a second account — and says how many the store has.
    await page.getByRole('button', { name: /add payment method/i }).click()
    await page.locator('#type').click()
    await expect(page.getByRole('option', { name: /^Bogus · \d+ installed$/ })).toBeVisible()
  })

  test('adds checkout conditions to a payment method', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PAYMENT_METHODS_PATH(creds.store_id), CTA)

    const name = `E2E Conditions ${Date.now()}`
    await page.getByRole('button', { name: /add payment method/i }).click()
    await selectProvider(page, 'Check')
    await page.locator('#name').fill(name)
    await page.getByRole('button', { name: /create payment method/i }).click()
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    await expect(page.getByText(/no conditions/i)).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /add condition/i }).click()
    await page.getByRole('menuitem', { name: 'Order total' }).click()
    await page.getByLabel('Minimum order total (USD)').fill('5000')

    await page.getByRole('button', { name: /add condition/i }).click()
    await page.getByRole('menuitem', { name: 'Company' }).click()

    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByRole('heading', { name })).toHaveCount(0, { timeout: 15_000 })

    await page.reload()
    await rowButton(page, name).click()
    await expect(page.getByLabel('Minimum order total (USD)')).toHaveValue('5000.00', {
      timeout: 15_000,
    })
    await expect(page.getByRole('switch', { name: /turn company on or off/i })).toBeChecked()

    // Switching a condition off keeps it, but stops it applying.
    await page.getByRole('switch', { name: /turn company on or off/i }).click()
    // Removing one drops it.
    await page
      .getByText('Order total', { exact: true })
      .locator('xpath=ancestor::div[contains(@class,"border")][1]')
      .getByRole('button', { name: /^delete$/i })
      .click()
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByRole('heading', { name })).toHaveCount(0, { timeout: 15_000 })

    const methods = await adminRequest<{ data: { id: string; name: string }[] }>(
      page,
      creds,
      'get',
      '/payment_methods?limit=100',
    )
    const method = methods.data.find((candidate) => candidate.name === name)
    const rules = await adminRequest<{ data: { type: string; active: boolean }[] }>(
      page,
      creds,
      'get',
      `/payment_methods/${method?.id}/rules`,
    )
    expect(rules.data).toEqual([expect.objectContaining({ type: 'company_rule', active: false })])
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

  // An existing method: saving only a custom field leaves the method itself
  // untouched, so the shared fixture stays as it was.
  test('saves a custom field with the payment method', async ({ page }) => {
    const creds = await login(page)
    await withCustomFieldDefinition(page, creds, 'payment_method', async (label) => {
      const methods = await adminRequest<{ data: { id: string }[] }>(
        page,
        creds,
        'get',
        '/payment_methods?limit=1',
      )
      const url = `${PAYMENT_METHODS_PATH(creds.store_id)}?edit=${methods.data[0].id}`
      await page.goto(url)
      await saveCustomFieldInSheet(page, url, label, 'NET30')
    })
  })
})
