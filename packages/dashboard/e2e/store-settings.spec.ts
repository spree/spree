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

  test('setting the store admin language switches the dashboard UI', async ({ page }) => {
    const creds = await login(page)

    // Normalize the store's admin language to English while the UI is still
    // English, so the Polish selection below is always a real change regardless
    // of any value left by a prior run (the suite shares one seeded DB). A
    // concrete language (not the blank "use default") is used because clearing
    // the override sends `undefined`, which the backend treats as "unchanged".
    // Save only when this actually dirties the form.
    await page.goto(STORE_PATH(creds.store_id))
    await expect(page.locator('#store-admin-locale')).toBeVisible({ timeout: 15_000 })
    await page.locator('#store-admin-locale').click()
    await page.getByRole('option', { name: /^english$/i }).click()
    const saveEn = page.getByRole('button', { name: /^save$/i })
    if (await saveEn.isEnabled()) {
      await saveEn.click()
      await expect(saveEn).toBeDisabled({ timeout: 15_000 })
    }

    // Precondition: give the admin an explicit personal language that DIFFERS
    // from the one we'll set via store settings. This persists `selected_locale`
    // on the account, which the auth provider treats as the cross-device source
    // of truth. Without a saved personal language the store-locale switch passes
    // trivially on a fresh account (selected_locale = null → nothing to revert
    // it) while still being broken for a real user who has one — the auth
    // provider reverts a localStorage-only switch back to the saved language on
    // the next session bootstrap. German here; the store switch to Polish below
    // must win over it and survive a reload.
    await page.goto(`/${creds.store_id}/settings/profile`)
    await expect(page.locator('#profile-language')).toBeVisible({ timeout: 15_000 })
    await page.locator('#profile-language').click()
    await page.getByRole('option', { name: /^deutsch$/i }).click()
    // Save only if the selection dirtied the form — a prior run may have already
    // left the account on German, in which case the button stays disabled.
    const saveProfile = page.getByRole('button', { name: /^(save|speichern)$/i })
    if (await saveProfile.isEnabled()) await saveProfile.click()
    // Saving a new language reloads into it; the profile heading is now German.
    await expect(page.getByText('Persönliche Daten', { exact: true })).toBeVisible({
      timeout: 15_000,
    })

    await page.goto(STORE_PATH(creds.store_id))
    await expect(page.locator('#store-admin-locale')).toBeVisible({ timeout: 15_000 })

    // Pick Polish (endonym shown in the picker) and save. The page is currently
    // in German (the precondition above), so the Save button reads "Speichern".
    // Saving persists preferred_admin_locale AND switches the dashboard into
    // Polish, reloading so every module-load `i18n.t(...)` label re-resolves.
    await page.locator('#store-admin-locale').click()
    await page.getByRole('option', { name: /polski/i }).click()
    await page.getByRole('button', { name: /^speichern$/i }).click()

    // Whole UI re-renders in Polish: the "Standards and formats" card title →
    // "Standardy i formaty", and the nav "Products" → "Produkty" (proves the
    // switch drives boot-time labels across nav/tables, not just this form).
    await expect(page.getByText('Standardy i formaty', { exact: true })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByRole('link', { name: /produkty/i })).toBeVisible()

    // The crux: survives a reload. The switch must have been adopted as the
    // admin's own `selected_locale` (PATCH /me), not just written to
    // localStorage — otherwise the auth provider reverts to the previously
    // saved German on the next session bootstrap and the UI bounces back.
    await page.reload()
    await expect(page.getByText('Standardy i formaty', { exact: true })).toBeVisible({
      timeout: 15_000,
    })

    // Saving an UNRELATED field (the store name) must NOT touch the admin's UI
    // language: only an actual change to the admin-locale field switches it.
    // The UI stays Polish — no surprise reload back to a different language.
    await page.locator('#store-name').fill(`${creds.store_name} ${Date.now()}`)
    await page.getByRole('button', { name: /^zapisz$/i }).click()
    await expect(page.getByText('Standardy i formaty', { exact: true })).toBeVisible({
      timeout: 15_000,
    })

    // Reset to English + restore the store name so later tests/specs run
    // against clean English chrome. The page is now in Polish: the admin-locale
    // field and the save button read "Zapisz".
    await page.locator('#store-name').fill(creds.store_name)
    await page.locator('#store-admin-locale').click()
    await page.getByRole('option', { name: /^english$/i }).click()
    await page.getByRole('button', { name: /^zapisz$/i }).click()
    await expect(page.getByText('Standards and formats', { exact: true })).toBeVisible({
      timeout: 15_000,
    })
  })
})

test.describe('store settings — emails', () => {
  test('hides addresses + logo cards when consumer emails are turned off', async ({ page }) => {
    const creds = await login(page)
    await page.goto(EMAILS_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^email settings$/i })).toBeVisible({
      timeout: 15_000,
    })

    // The logo card always shows an upload CTA — use that as a proxy for the
    // card's presence. The CardTitle is rendered as a `<div>` so `role=heading`
    // doesn't apply, and matching plain text would collide with other strings.
    const uploadCta = page.getByRole('button', { name: /upload logo/i })

    // Base UI's <Switch> renders a hidden <input> + a visible <button
    // role="switch">. The id is on the hidden input, so we drive interaction
    // via the visible role-switch (matched by its accessible label).
    const consumerEmailsToggle = page.getByRole('switch', {
      name: /send transactional emails to customers/i,
    })

    // Cards visible by default (consumer emails are enabled on a fresh store).
    await expect(page.locator('#store-mail-from-address')).toBeVisible()
    await expect(uploadCta).toBeVisible()

    // Toggle off → address + logo cards disappear.
    await consumerEmailsToggle.click()
    await expect(page.locator('#store-mail-from-address')).toHaveCount(0)
    await expect(uploadCta).toHaveCount(0)

    // Toggle back on → cards return without losing the seed value.
    await consumerEmailsToggle.click()
    await expect(page.locator('#store-mail-from-address')).toBeVisible()
    await expect(uploadCta).toBeVisible()
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
    const senderField = page.locator('#store-mail-from-address')
    await expect(senderField).toBeVisible({ timeout: 15_000 })

    await senderField.fill('not-an-email')

    // The input is `type="email"`, so the browser's native HTML5 validity
    // check rejects the value before the form ever submits — that's what the
    // user actually sees (the native popup blocks the submit). Asserting on
    // `validity.valid` keeps the test honest about what stops the user from
    // sending bad data, rather than relying on Zod's downstream `aria-invalid`
    // (which never fires because the submit is blocked at the form level).
    await expect(async () => {
      const valid = await senderField.evaluate((el) => (el as HTMLInputElement).validity.valid)
      expect(valid).toBe(false)
    }).toPass({ timeout: 5_000 })
  })
})
