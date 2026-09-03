import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, rowButton } from './helpers'

const COMMISSION_RATES_PATH = (storeId: string) => `/${storeId}/settings/commission-rates`
const ADD_CTA = /add commission rate/i

async function createCommissionRate(
  page: Page,
  attrs: { name: string; code?: string; value?: string },
) {
  await page.getByRole('button', { name: ADD_CTA }).click()
  await expect(page.getByRole('heading', { name: /add commission rate/i })).toBeVisible()

  await page.getByLabel(/^name$/i).fill(attrs.name)
  if (attrs.code !== undefined) {
    await page.getByLabel(/^code$/i).fill(attrs.code)
  }
  if (attrs.value !== undefined) {
    await page.getByLabel(/^value$/i).fill(attrs.value)
  }

  await page.getByRole('button', { name: /create commission rate/i }).click()
}

test.describe('settings / commission rates', () => {
  test('lists commission rates', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COMMISSION_RATES_PATH(creds.store_id), ADD_CTA)
  })

  test('auto-derives the code from the name while creating', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COMMISSION_RATES_PATH(creds.store_id), ADD_CTA)

    const suffix = Date.now()
    const name = `E2E Commission ${suffix}`
    const expectedCode = `e2e-commission-${suffix}`

    await page.getByRole('button', { name: ADD_CTA }).click()
    await page.getByLabel(/^name$/i).fill(name)
    await expect(page.getByLabel(/^code$/i)).toHaveValue(expectedCode)

    await page.getByRole('button', { name: /create commission rate/i }).click()
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('cell', { name: expectedCode, exact: true })).toBeVisible()
  })

  test('keeps a custom code when editing an unrelated field', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, COMMISSION_RATES_PATH(creds.store_id), ADD_CTA)

    const suffix = Date.now()
    const name = `Kestrel negotiated ${suffix}`
    const customCode = `kestrel-${suffix}`

    await createCommissionRate(page, { name, code: customCode, value: '10' })
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('cell', { name: customCode, exact: true })).toBeVisible()

    await rowButton(page, name).click()
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
    await expect(page.getByLabel(/^code$/i)).toHaveValue(customCode)

    await page.getByLabel(/^value$/i).fill('12')
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('cell', { name: customCode, exact: true })).toBeVisible()
  })
})
