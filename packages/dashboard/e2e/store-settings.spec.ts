import { expect, test } from '@playwright/test'
import { login } from './helpers'

const STORE_PATH = (storeId: string) => `/${storeId}/settings/store`
const EMAILS_PATH = (storeId: string) => `/${storeId}/settings/emails`

// Both pages mutate a single shared resource (the default store). Run them
// serially so the email-suite doesn't observe a store name from
// store-settings mid-update.
test.describe.configure({ mode: 'serial' })

test.describe('store settings — general', () => {
  test('loads the store settings page', async ({ page }) => {
    const creds = await login(page)
    await page.goto(STORE_PATH(creds.store_id))

    await expect(page.getByRole('heading', { name: /^store settings$/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.locator('#store-name')).toBeVisible()
  })

  test('renames the store and persists across reload', async ({ page }) => {
    const creds = await login(page)
    await page.goto(STORE_PATH(creds.store_id))
    await expect(page.locator('#store-name')).toBeVisible({ timeout: 15_000 })

    const newName = `E2E Store ${Date.now()}`

    await page.locator('#store-name').fill(newName)
    await page.getByRole('button', { name: /^save$/i }).click()

    // Toast shows the success message. We don't depend on it being visible by
    // the time we navigate — the next assertion (reload + value match) is
    // what confirms persistence.
    await expect(page.locator('#store-name')).toHaveValue(newName)

    await page.reload()
    await expect(page.locator('#store-name')).toHaveValue(newName, { timeout: 15_000 })

    // Reset for the rest of the suite — keeps the shared DB clean.
    await page.locator('#store-name').fill(creds.store_name)
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.locator('#store-name')).toHaveValue(creds.store_name)
  })
})

test.describe('store settings — emails', () => {
  test('hides addresses + logo cards when consumer emails are turned off', async ({ page }) => {
    const creds = await login(page)
    await page.goto(EMAILS_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^email settings$/i })).toBeVisible({
      timeout: 15_000,
    })

    // Cards visible by default (consumer emails are enabled on a fresh store).
    await expect(page.locator('#store-mail-from-address')).toBeVisible()
    await expect(page.getByRole('heading', { name: /^logo$/i })).toBeVisible()

    // Toggle off → address + logo cards disappear.
    await page.locator('#store-send-consumer-emails').click()
    await expect(page.locator('#store-mail-from-address')).toHaveCount(0)
    await expect(page.getByRole('heading', { name: /^logo$/i })).toHaveCount(0)

    // Toggle back on → cards return without losing the seed value.
    await page.locator('#store-send-consumer-emails').click()
    await expect(page.locator('#store-mail-from-address')).toBeVisible()
    await expect(page.getByRole('heading', { name: /^logo$/i })).toBeVisible()
  })

  test('saves sender + support + notifications addresses and reloads them', async ({ page }) => {
    const creds = await login(page)
    await page.goto(EMAILS_PATH(creds.store_id))
    await expect(page.locator('#store-mail-from-address')).toBeVisible({ timeout: 15_000 })

    const suffix = Date.now()
    const sender = `sender-${suffix}@example.com`
    const support = `support-${suffix}@example.com`
    const ops = `ops-${suffix}@example.com`

    await page.locator('#store-mail-from-address').fill(sender)
    await page.locator('#store-customer-support-email').fill(support)
    await page.locator('#store-new-order-notifications-email').fill(ops)

    await page.getByRole('button', { name: /^save$/i }).click()

    // Re-fetch values after the mutation roundtrip. RHF re-seeds defaults on
    // success, so we don't need an explicit toast wait.
    await expect(page.locator('#store-mail-from-address')).toHaveValue(sender)

    await page.reload()
    await expect(page.locator('#store-mail-from-address')).toHaveValue(sender, { timeout: 15_000 })
    await expect(page.locator('#store-customer-support-email')).toHaveValue(support)
    await expect(page.locator('#store-new-order-notifications-email')).toHaveValue(ops)
  })

  test('flags an invalid mail_from_address inline', async ({ page }) => {
    const creds = await login(page)
    await page.goto(EMAILS_PATH(creds.store_id))
    await expect(page.locator('#store-mail-from-address')).toBeVisible({ timeout: 15_000 })

    await page.locator('#store-mail-from-address').fill('not-an-email')
    await page.getByRole('button', { name: /^save$/i }).click()

    // Zod resolver renders an inline error via the field's aria-invalid + the
    // accompanying FieldError component — assert the field reflects invalid
    // state. Specific copy varies by zod version, so we anchor on the
    // attribute rather than the message string.
    await expect(page.locator('#store-mail-from-address')).toHaveAttribute('aria-invalid', 'true')
  })
})
