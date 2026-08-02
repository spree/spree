import { expect, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'

const ZONES_PATH = (storeId: string) => `/${storeId}/settings/delivery-zones`
const METHODS_PATH = (storeId: string) => `/${storeId}/settings/delivery-methods`
const ZONES_CTA = /add delivery zone/i
const METHODS_CTA = /add delivery method/i

test.describe('delivery zones', () => {
  test('lists delivery zones', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, ZONES_PATH(creds.store_id), ZONES_CTA)
  })

  test('creates a delivery zone with a country member', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, ZONES_PATH(creds.store_id), ZONES_CTA)

    const name = `E2E Zone ${Date.now()}`

    await page.getByRole('button', { name: ZONES_CTA }).click()
    await expect(page.getByRole('heading', { name: /new delivery zone/i })).toBeVisible()

    await page.locator('#name').fill(name)
    await page.getByRole('button', { name: /add member/i }).click()
    // Second combobox in the member row is the country picker.
    await page.getByRole('combobox').nth(1).click()
    await page.getByRole('option', { name: /united states/i }).click()

    await page.getByRole('button', { name: /create delivery zone/i }).click()

    await expect(page.getByText(name)).toBeVisible({ timeout: 15_000 })
  })
})

test.describe('delivery methods', () => {
  test('lists delivery methods', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, METHODS_PATH(creds.store_id), METHODS_CTA)
  })

  test('creates a pickup delivery method', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, METHODS_PATH(creds.store_id), METHODS_CTA)

    const name = `E2E Pickup ${Date.now()}`

    await page.getByRole('button', { name: METHODS_CTA }).click()
    await expect(page.getByRole('heading', { name: /new delivery method/i })).toBeVisible()

    await page.locator('#name').fill(name)
    // Fulfillment type select — first combobox in the sheet form.
    await page.getByRole('combobox').first().click()
    await page.getByRole('option', { name: /^pickup$/i }).click()

    // Choosing pickup reveals the provider field (several providers handle the
    // type) and suggests the one that actually does pickup, not generic Manual.
    await expect(page.getByText(/fulfillment provider/i)).toBeVisible()
    await expect(page.getByRole('combobox').nth(1)).toHaveText(/pickup/i)

    await page.getByRole('button', { name: /create delivery method/i }).click()

    await expect(page.getByText(name)).toBeVisible({ timeout: 15_000 })
  })
})
