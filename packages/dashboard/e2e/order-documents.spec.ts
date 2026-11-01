import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import { expect, type Locator, type Page, test } from '@playwright/test'
import { addListFilter, createPlacedOrder, login, SELLER_PANEL, sellerLogin } from './helpers'

const FIXTURES = path.join(path.dirname(fileURLToPath(import.meta.url)), 'fixtures')
const INVOICE_PDF = path.join(FIXTURES, 'test-invoice.pdf')
const OTHER_DOCUMENT = path.join(FIXTURES, 'test-image.png')

function documentsCard(page: Page): Locator {
  return page
    .locator('[data-slot="card"]')
    .filter({ has: page.locator('[data-slot="card-title"]', { hasText: /^documents$/i }) })
}

/** Picks the file and waits for the upload itself, not just the filename. */
async function attach(sheet: Locator, file: string) {
  await sheet.locator('input[type="file"]').setInputFiles(file)
  await expect(sheet.getByText(/uploading/i)).toBeHidden({ timeout: 30_000 })
}

async function uploadInvoice(
  page: Page,
  { number, kind, total }: { number: string; kind?: RegExp; total: string },
) {
  await documentsCard(page)
    .getByRole('button', { name: /upload invoice/i })
    .click()
  const sheet = page.getByRole('dialog')
  await attach(sheet, INVOICE_PDF)
  if (kind) {
    await sheet.locator('#invoice-kind').click()
    await page.getByRole('option', { name: kind }).click()
  }
  await sheet.locator('#invoice-number').fill(number)
  await sheet.locator('#invoice-issued-on').click()
  await sheet.getByRole('gridcell', { name: '15' }).first().click()
  await sheet.locator('#invoice-total').fill(total)
  await sheet.getByRole('button', { name: /^upload$/i }).click()
}

/** Turns the store's automatic invoice emails on or off from its settings page. */
async function setInvoiceEmails(page: Page, storeId: string, on: boolean) {
  await page.goto(`/${storeId}/settings/store`)
  const toggle = page.getByRole('switch', { name: /email new invoices to customers/i })
  await expect(toggle).toBeVisible({ timeout: 15_000 })
  if ((await toggle.isChecked()) === on) return

  await toggle.click()
  await page.getByRole('button', { name: /^save$/i }).click()
  await expect(page.getByText(/settings updated/i).first()).toBeVisible({ timeout: 15_000 })
}

test.describe('order documents', () => {
  test('uploads an invoice, lists it across the store, and deletes it while unsent', async ({
    page,
  }) => {
    // Several page loads: settings, the order, the store-wide list and back.
    test.slow()
    const session = await login(page)
    const order = await createPlacedOrder(page, session.accessToken, { ship: false })
    const number = `FV/${Date.now()}`

    await page.goto(`/${session.store_id}/orders/${order.id}`)
    await expect(documentsCard(page)).toBeVisible({ timeout: 15_000 })
    await expect(documentsCard(page).getByText(/no invoices yet/i)).toBeVisible()

    // The store emails new invoices by default, so turn that off first: an
    // invoice that has been sent can no longer be deleted.
    await setInvoiceEmails(page, session.store_id, false)

    await page.goto(`/${session.store_id}/orders/${order.id}`)
    await uploadInvoice(page, { number, total: order.total })

    const row = documentsCard(page).getByRole('listitem').filter({ hasText: number })
    await expect(row).toBeVisible({ timeout: 15_000 })
    await expect(row.getByText(/^invoice$/i)).toBeVisible()

    // The store-wide list, for accountants.
    await page.goto(`/${session.store_id}/invoices`)
    await expect(page.getByRole('link', { name: number })).toBeVisible({ timeout: 15_000 })

    await page.goto(`/${session.store_id}/orders/${order.id}`)
    await row.getByRole('button', { name: /actions/i }).click()
    await page.getByRole('menuitem', { name: /delete/i }).click()
    await expect(page.getByRole('heading', { name: /delete invoice\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()
    await expect(row).toBeHidden({ timeout: 15_000 })

    await setInvoiceEmails(page, session.store_id, true)
  })

  test('refuses a credit note with a positive total', async ({ page }) => {
    const session = await login(page)
    const order = await createPlacedOrder(page, session.accessToken, { ship: false })

    await page.goto(`/${session.store_id}/orders/${order.id}`)
    await expect(documentsCard(page)).toBeVisible({ timeout: 15_000 })
    await uploadInvoice(page, { number: `CN/${Date.now()}`, kind: /credit note/i, total: '10.00' })

    await expect(page.getByRole('dialog').getByText(/zero or negative/i)).toBeVisible()
  })

  test('adds another document and shows it to the customer', async ({ page }) => {
    const session = await login(page)
    const order = await createPlacedOrder(page, session.accessToken, { ship: false })
    const label = `Specification ${Date.now()}`

    await page.goto(`/${session.store_id}/orders/${order.id}`)
    await documentsCard(page)
      .getByRole('button', { name: /upload document/i })
      .click()
    const sheet = page.getByRole('dialog')
    await sheet.locator('#document-label').fill(label)
    await attach(sheet, OTHER_DOCUMENT)
    await sheet.getByRole('button', { name: /^upload$/i }).click()

    const row = documentsCard(page).getByRole('listitem').filter({ hasText: label })
    await expect(row.getByText(/^internal$/i)).toBeVisible({ timeout: 15_000 })

    await row.getByRole('button', { name: /actions/i }).click()
    await page.getByRole('menuitem', { name: /show to customer/i }).click()
    await expect(row.getByText(/visible to customer/i)).toBeVisible({ timeout: 15_000 })
  })

  test('lists a paid order missing an invoice until one is uploaded', async ({ page }) => {
    const session = await login(page)
    const lastName = `Invoiceless${Date.now()}`
    const order = await createPlacedOrder(page, session.accessToken, { ship: false, lastName })

    await page.goto(`/${session.store_id}/orders`)
    await addListFilter(page, /^missing invoice$/i, /missing an invoice/i)
    await page
      .getByPlaceholder(/search/i)
      .first()
      .fill(order.number)
    await expect(page.getByRole('link', { name: order.number })).toBeVisible({ timeout: 15_000 })

    await page.goto(`/${session.store_id}/orders/${order.id}`)
    await uploadInvoice(page, { number: `FV/${Date.now()}`, total: order.total })
    await expect(documentsCard(page).getByRole('listitem')).toHaveCount(1, { timeout: 15_000 })

    await page.goBack()
    await page.goto(`/${session.store_id}/orders`)
    await addListFilter(page, /^missing invoice$/i, /missing an invoice/i)
    await page
      .getByPlaceholder(/search/i)
      .first()
      .fill(order.number)
    await expect(page.getByRole('link', { name: order.number })).toBeHidden({ timeout: 15_000 })
  })
})

test.describe('seller panel — invoices', () => {
  test('shows the Documents card on an order and the Invoices list', async ({ page }) => {
    await sellerLogin(page)

    await page
      .getByRole('link', { name: /^orders$/i })
      .first()
      .click()
    const order = page.getByRole('button', { name: /^R\d+/ }).first()
    await expect(order).toBeVisible({ timeout: 15_000 })
    await order.click()
    await expect(documentsCard(page)).toBeVisible({ timeout: 15_000 })
    await expect(documentsCard(page).getByRole('button', { name: /upload invoice/i })).toBeVisible()

    await page.goto(SELLER_PANEL)
    await page
      .getByRole('link', { name: /^invoices$/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /^invoices$/i, level: 1 })).toBeVisible({
      timeout: 15_000,
    })
  })
})
