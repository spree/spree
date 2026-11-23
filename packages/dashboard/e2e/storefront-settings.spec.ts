import { expect, test } from '@playwright/test'
import { adminRequest, login } from './helpers'

const STOREFRONT_PATH = (storeId: string) => `/${storeId}/settings/storefront`

type StorefrontSettings = {
  storefront_url: string | null
  storefront_access: string
  guest_checkout: boolean
  always_include_confirm_step: boolean
  company_field_enabled: boolean
  address_requires_phone: boolean
}

// Every test changes the one shared store, so they run in order and put each
// setting back afterwards.
test.describe.configure({ mode: 'serial' })

test.describe('storefront & checkout settings', () => {
  test('saves storefront access, checkout and address settings', async ({ page }) => {
    const creds = await login(page)
    const original = await adminRequest<StorefrontSettings>(page, creds, 'get', '/store')

    try {
      await page.goto(STOREFRONT_PATH(creds.store_id))
      const access = page.locator('#store-storefront-access')
      const guestCheckout = page.getByRole('switch', { name: /^guest checkout/i })
      const companyField = page.getByRole('switch', { name: /^company field/i })
      const save = page.getByRole('button', { name: /^save$/i })
      await expect(access).toBeVisible({ timeout: 15_000 })

      await access.click()
      await page.getByRole('option', { name: /^prices hidden/i }).click()
      await guestCheckout.click()
      await companyField.click()
      await save.click()
      await expect(page.getByText(/store settings updated/i)).toBeVisible({ timeout: 15_000 })
      await expect(save).toBeDisabled()

      await page.reload()
      await expect(access).toContainText(/prices hidden/i, { timeout: 15_000 })
      await expect(guestCheckout).toHaveAttribute('aria-checked', String(!original.guest_checkout))
      await expect(companyField).toHaveAttribute(
        'aria-checked',
        String(!original.company_field_enabled),
      )
    } finally {
      await adminRequest(page, creds, 'patch', '/store', {
        storefront_access: original.storefront_access,
        guest_checkout: original.guest_checkout,
        company_field_enabled: original.company_field_enabled,
      })
    }
  })

  // The URL is set through the connect sheet, which also allows its origin, so
  // the page only shows it and opens that sheet.
  test('shows the storefront URL and opens the connect sheet', async ({ page }) => {
    const creds = await login(page)
    const store = await adminRequest<StorefrontSettings>(page, creds, 'get', '/store')
    await page.goto(STOREFRONT_PATH(creds.store_id))

    const button = page.getByRole('button', {
      name: store.storefront_url ? /^change$/i : /^connect$/i,
    })
    await expect(button).toBeVisible({ timeout: 15_000 })
    if (store.storefront_url) {
      await expect(page.getByRole('link', { name: store.storefront_url })).toBeVisible()
    } else {
      await expect(page.getByText(/not connected yet/i)).toBeVisible()
    }

    await button.click()
    await expect(page.getByRole('heading', { name: /connect your storefront/i })).toBeVisible()
  })

  test('is listed in the settings navigation, and off the store page', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings/store`)
    await page.getByRole('link', { name: /^storefront & checkout$/i }).click()
    await expect(page.getByRole('heading', { name: /^storefront & checkout$/i })).toBeVisible({
      timeout: 15_000,
    })

    // These settings live here only: the store page no longer carries them.
    await page.goto(`/${creds.store_id}/settings/store`)
    await expect(page.locator('#store-name')).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('switch', { name: /^guest checkout/i })).toHaveCount(0)
    await expect(page.getByText(/^storefront access$/i)).toHaveCount(0)
  })
})
