import { expect, type Page, test } from '@playwright/test'
import {
  adminRequest,
  type E2ELoginSession,
  login,
  saveCustomFieldInSheet,
  withCustomFieldDefinition,
} from './helpers'

const PAYMENTS_PATH = (storeId: string) => `/${storeId}/settings/payment-methods`

type PaymentMethodRecord = { id: string; name: string; position: number }

async function openPayments(page: Page, storeId: string) {
  await page.goto(PAYMENTS_PATH(storeId))
  await expect(page.getByRole('heading', { name: /^payment providers$/i })).toBeVisible({
    timeout: 15_000,
  })
}

/** A payment method's row, provider or manual, by its name. */
function methodRow(page: Page, name: string) {
  return page.locator(`[data-payment-method="${name}"]`)
}

/** Deletes the method open in the edit sheet, through its confirmation. */
async function deleteFromSheet(page: Page) {
  await page
    .getByRole('dialog')
    .getByRole('button', { name: /^delete$/i })
    .click()
  await expect(page.getByRole('heading', { name: /delete payment method\?/i })).toBeVisible()
  await page
    .getByRole('button', { name: /^delete$/i })
    .last()
    .click()
}

async function seedCheck(page: Page, creds: E2ELoginSession, name: string) {
  return adminRequest<PaymentMethodRecord>(page, creds, 'post', '/payment_methods', {
    type: 'check',
    name,
    active: true,
    storefront_visible: true,
  })
}

// The lifecycle tests install providers through the pickers, which offer each
// one once per store, so they run in order against the shared database and
// each removes what it added.
test.describe.configure({ mode: 'serial' })

test.describe('payments', () => {
  test('shows providers, manual methods and when payments are taken', async ({ page }) => {
    const creds = await login(page)
    await openPayments(page, creds.store_id)

    await expect(page.getByRole('heading', { name: /^manual payment methods$/i })).toBeVisible()
    await expect(page.getByRole('heading', { name: /^payment capture$/i })).toBeVisible()
    // Core ships one outside provider (Bogus) and seeds store credit, a
    // method the store handles itself.
    await expect(methodRow(page, 'Bogus')).toBeVisible()
    // It only simulates payments, and says so.
    await expect(methodRow(page, 'Bogus').getByText(/^test gateway$/i)).toBeVisible()
    await expect(methodRow(page, 'Store Credit')).toBeVisible()

    // Both settings moved off the store settings page.
    await page.goto(`/${creds.store_id}/settings/store`)
    await expect(page.getByRole('heading', { name: /^inventory$/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(/when to charge customers/i)).toHaveCount(0)
    await expect(page.getByText(/tax by shipping address/i)).toHaveCount(0)
  })

  test('sets up a provider from its row, keeping its secret on edit', async ({ page }) => {
    const creds = await login(page)
    await openPayments(page, creds.store_id)

    const name = `E2E Bogus ${Date.now()}`
    await methodRow(page, 'Bogus')
      .getByRole('button', { name: /^connect$/i })
      .click()
    await expect(page.getByRole('heading', { name: /add payment method/i })).toBeVisible()

    await page.locator('#name').fill(name)
    await page.locator('#preference-dummy_key').fill('E2EPUBLIC')
    await page.locator('#preference-dummy_secret_key').fill('e2e-secret-9876')
    await page.getByRole('button', { name: /create payment method/i }).click()

    // Set up, the provider's row carries the method's own name.
    const row = methodRow(page, name)
    await expect(row).toBeVisible({ timeout: 15_000 })
    await expect(methodRow(page, 'Bogus')).toHaveCount(0)

    // The plain setting comes back as typed, the secret only as a mask.
    await row.getByRole('button', { name: /^configure$/i }).click()
    await expect(page.locator('#preference-dummy_key')).toHaveValue('E2EPUBLIC', {
      timeout: 15_000,
    })
    const secret = page.locator('#preference-dummy_secret_key')
    await expect(secret).toHaveText(/^•+9876$/)

    // Saving without touching the secret keeps it.
    const updated = `${name} (updated)`
    await page.locator('#name').fill(updated)
    await page.getByRole('button', { name: /^save$/i }).click()
    const updatedRow = methodRow(page, updated)
    await expect(updatedRow).toBeVisible({ timeout: 15_000 })

    await page.reload()
    await updatedRow.getByRole('button', { name: /^configure$/i }).click()
    await expect(secret).toHaveText(/^•+9876$/, { timeout: 15_000 })

    // Deleting it from its sheet offers the provider for setup again.
    await deleteFromSheet(page)
    await expect(updatedRow).toHaveCount(0, { timeout: 15_000 })
    await expect(methodRow(page, 'Bogus')).toBeVisible()
  })

  test('adds a manual method, edits and deletes it', async ({ page }) => {
    const creds = await login(page)
    await openPayments(page, creds.store_id)

    const name = `E2E Check ${Date.now()}`
    const updated = `${name} (updated)`

    await page.getByRole('button', { name: /add manual method/i }).click()
    await expect(page.getByRole('heading', { name: /add payment method/i })).toBeVisible()
    // Only methods the store handles itself: outside providers are set up
    // from their rows.
    await page.locator('#type').click()
    await expect(page.getByRole('option', { name: 'Check' })).toBeVisible()
    await expect(page.getByRole('option', { name: 'Bogus' })).toHaveCount(0)
    await page.getByRole('option', { name: 'Check' }).click()
    await page.locator('#name').fill(name)
    await page.getByRole('button', { name: /create payment method/i }).click()

    const row = methodRow(page, name)
    await expect(row).toBeVisible({ timeout: 15_000 })

    await row.getByRole('button', { name: /^configure$/i }).click()
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
    await page.locator('#name').fill(updated)
    await page.getByRole('button', { name: /^save$/i }).click()
    const updatedRow = methodRow(page, updated)
    await expect(updatedRow).toBeVisible({ timeout: 15_000 })

    await updatedRow.getByRole('button', { name: /^configure$/i }).click()
    await expect(page.getByRole('heading', { name: updated })).toBeVisible({ timeout: 15_000 })
    await deleteFromSheet(page)
    await expect(updatedRow).toHaveCount(0, { timeout: 15_000 })
  })

  test('orders the methods checkout offers', async ({ page }) => {
    const creds = await login(page)
    const stamp = Date.now()
    const first = await seedCheck(page, creds, `E2E Order ${stamp} A`)
    const second = await seedCheck(page, creds, `E2E Order ${stamp} B`)

    try {
      await openPayments(page, creds.store_id)
      await page.getByRole('button', { name: /^checkout order$/i }).click()
      const sheet = page.getByRole('dialog')
      await expect(sheet.getByRole('heading', { name: /^checkout order$/i })).toBeVisible()

      const rowA = sheet.getByRole('listitem').filter({ hasText: first.name })
      const rowB = sheet.getByRole('listitem').filter({ hasText: second.name })
      await expect(rowB).toBeVisible({ timeout: 15_000 })

      // dnd-kit starts a drag only after the pointer moves 5px, so the move
      // is made in steps rather than one jump.
      const target = await rowA.boundingBox()
      if (!target) throw new Error('could not resolve the first row')
      await rowB.getByLabel(/drag to reorder/i).hover()
      await page.mouse.down()
      await page.mouse.move(target.x + target.width / 2, target.y - 4, { steps: 8 })
      await page.mouse.move(target.x + target.width / 2, target.y + 2, { steps: 4 })
      await page.mouse.up()

      await expect(async () => {
        const { data } = await adminRequest<{ data: PaymentMethodRecord[] }>(
          page,
          creds,
          'get',
          '/payment_methods?limit=100',
        )
        const position = (id: string) => data.find((method) => method.id === id)?.position ?? 0
        expect(position(second.id)).toBeLessThan(position(first.id))
      }).toPass({ timeout: 15_000 })
    } finally {
      await adminRequest(page, creds, 'delete', `/payment_methods/${first.id}`)
      await adminRequest(page, creds, 'delete', `/payment_methods/${second.id}`)
    }
  })

  test('saves when payments are taken', async ({ page }) => {
    const creds = await login(page)
    const store = await adminRequest<{ capture_method: string }>(page, creds, 'get', '/store')

    try {
      await openPayments(page, creds.store_id)
      const manually = page.getByRole('radio', { name: /^manually/i })
      await manually.click()
      await page.getByRole('button', { name: /^save$/i }).click()
      await expect(page.getByText(/store settings updated/i)).toBeVisible({ timeout: 15_000 })
      await expect(page.getByRole('button', { name: /^save$/i })).toHaveCount(0)

      await page.reload()
      await expect(manually).toBeChecked({ timeout: 15_000 })
    } finally {
      await adminRequest(page, creds, 'patch', '/store', { capture_method: store.capture_method })
    }
  })

  test('switches tax to the billing address on the Taxes page', async ({ page }) => {
    const creds = await login(page)
    const store = await adminRequest<{ tax_using_ship_address: boolean }>(
      page,
      creds,
      'get',
      '/store',
    )

    try {
      await page.goto(`/${creds.store_id}/settings/taxes`)
      const toggle = page.getByRole('switch', { name: /tax by shipping address/i })
      await expect(toggle).toBeChecked({ checked: store.tax_using_ship_address, timeout: 15_000 })

      await toggle.click()
      await expect(page.getByText(/store settings updated/i)).toBeVisible({ timeout: 15_000 })

      await page.reload()
      await expect(toggle).toBeChecked({ checked: !store.tax_using_ship_address, timeout: 15_000 })
    } finally {
      await adminRequest(page, creds, 'patch', '/store', {
        tax_using_ship_address: store.tax_using_ship_address,
      })
    }
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
      const url = `${PAYMENTS_PATH(creds.store_id)}?edit=${methods.data[0].id}`
      await page.goto(url)
      await saveCustomFieldInSheet(page, url, label, 'NET30')
    })
  })
})
