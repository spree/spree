import { expect, type Page, test } from '@playwright/test'
import {
  FIXTURE_LEDGER_SELLER,
  FIXTURE_PROMO_TAXON,
  gotoIndex,
  login,
  openRowMenu,
  rowButton,
  waitForToastsToClear,
} from './helpers'

const COMMISSION_RATES_PATH = (storeId: string) => `/${storeId}/sellers/commission-rates`
const CTA = /add commission rate/i

async function createCommissionRate(page: Page, name: string, value: string) {
  await page.getByRole('button', { name: CTA }).click()
  await page.locator('#name').fill(name)
  await page.locator('#value').fill(value)
  await page.getByRole('button', { name: /create commission rate/i }).click()
  await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
}

test.describe('commission rates', () => {
  test('creates a percentage rate and edits it', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COMMISSION_RATES_PATH(creds.store_id), CTA)

    const name = `E2E Commission ${Date.now()}`
    await createCommissionRate(page, name, '12')

    const row = page.getByRole('row').filter({ has: rowButton(page, name) })
    await expect(row.getByText(/^12(\.0+)?%$/)).toBeVisible()
    // A rate with no conditions matches every sale, and the row says so.
    await expect(row.getByText(/^every sale$/i)).toBeVisible()

    await rowButton(page, name).click()
    await expect(page.locator('#value')).toHaveValue(/^12(\.0+)?$/, { timeout: 15_000 })
    await page.locator('#value').fill('15')
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(row.getByText(/^15(\.0+)?%$/)).toBeVisible({ timeout: 15_000 })
  })

  // Amounts and rates go to the API as exact decimal strings, so each one
  // must read back as typed when the rate is reopened.
  test('keeps a flat fee per currency exactly', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COMMISSION_RATES_PATH(creds.store_id), CTA)

    const name = `E2E Flat Commission ${Date.now()}`
    await page.getByRole('button', { name: CTA }).click()
    await page.locator('#name').fill(name)
    await page.locator('#kind').click()
    await page.getByRole('option', { name: /^flat fee$/i }).click()
    await page.getByRole('dialog').getByLabel('USD', { exact: true }).fill('1.25')
    await page.getByRole('button', { name: /create commission rate/i }).click()
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    await expect(page.getByRole('dialog').getByLabel('USD', { exact: true })).toHaveValue('1.25', {
      timeout: 15_000,
    })
  })

  test('keeps a percentage with its floor, cap and tax exactly', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COMMISSION_RATES_PATH(creds.store_id), CTA)

    const name = `E2E Bounded Commission ${Date.now()}`
    await page.getByRole('button', { name: CTA }).click()
    const sheet = page.getByRole('dialog')
    await page.locator('#name').fill(name)
    await page.locator('#value').fill('12.5')
    await sheet.getByLabel('USD Minimum', { exact: true }).fill('0.50')
    await sheet.getByLabel('USD Maximum', { exact: true }).fill('25.00')
    await page.locator('#commission_tax_rate').fill('7.125')
    await page.getByRole('button', { name: /create commission rate/i }).click()
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    const reopened = page.getByRole('dialog')
    await expect(page.locator('#value')).toHaveValue('12.5', { timeout: 15_000 })
    await expect(reopened.getByLabel('USD Minimum', { exact: true })).toHaveValue('0.50')
    await expect(reopened.getByLabel('USD Maximum', { exact: true })).toHaveValue('25.00')
    await expect(page.locator('#commission_tax_rate')).toHaveValue('7.125')
  })

  // Seller and category conditions keep prefixed ids in their preferences,
  // so reopening must name the same records that were picked.
  test('saves seller and category conditions and reopens with them', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COMMISSION_RATES_PATH(creds.store_id), CTA)

    const name = `E2E Commission Conditions ${Date.now()}`
    await page.getByRole('button', { name: CTA }).click()
    const sheet = page.getByRole('dialog')
    await page.locator('#name').fill(name)
    await page.locator('#value').fill('8')

    await sheet.getByRole('button', { name: /^add condition$/i }).click()
    await page.getByRole('menuitem', { name: /^seller$/i }).click()
    await sheet.getByPlaceholder(/search sellers/i).fill(FIXTURE_LEDGER_SELLER)
    await page.getByRole('option', { name: FIXTURE_LEDGER_SELLER }).click()

    await sheet.getByRole('button', { name: /^add condition$/i }).click()
    await page.getByRole('menuitem', { name: /^category$/i }).click()
    await sheet.getByPlaceholder(/search categories/i).fill(FIXTURE_PROMO_TAXON)
    await page
      .getByRole('option', { name: new RegExp(FIXTURE_PROMO_TAXON) })
      .first()
      .click()

    await page.getByRole('button', { name: /create commission rate/i }).click()
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await page.reload()
    await rowButton(page, name).click()
    await expect(page.locator('#value')).toHaveValue(/^8(\.0+)?$/, { timeout: 15_000 })
    await expect(sheet.getByText(FIXTURE_LEDGER_SELLER)).toBeVisible()
    await expect(sheet.getByText(FIXTURE_PROMO_TAXON).first()).toBeVisible()
  })

  test('deletes a rate after confirming', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COMMISSION_RATES_PATH(creds.store_id), CTA)

    const name = `E2E Old Commission ${Date.now()}`
    await createCommissionRate(page, name, '5')

    await waitForToastsToClear(page)
    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete commission rate\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })

  test('the old settings address opens the commission rates', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings/commission-rates`)

    await expect(page).toHaveURL(new RegExp(`${COMMISSION_RATES_PATH(creds.store_id)}(\\?|$)`), {
      timeout: 15_000,
    })
    await expect(page.getByRole('button', { name: CTA })).toBeVisible()
  })
})
