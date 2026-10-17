import { expect, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import { CLIENTS_PATH, REGISTER_CTA } from './oauth-helpers'

// The developer-facing screen: which OAuth clients this store has registered,
// before any merchant connects one. Connecting is the other screen's job —
// see ai-agents.spec.ts.
test.describe('oauth clients', () => {
  test('registers a client from a name and a callback', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CLIENTS_PATH(creds.store_id), REGISTER_CTA)

    const name = `CI client ${Date.now()}`
    await page.getByRole('button', { name: REGISTER_CTA }).click()

    const sheet = page.getByRole('dialog')
    await sheet.locator('#oauth-application-name').fill(name)
    await sheet.locator('#oauth-application-redirect-uri').fill('https://ci.example.com/callback')
    await sheet.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByRole('row', { name: new RegExp(name) })).toBeVisible({
      timeout: 15_000,
    })
  })

  // The one field a merchant must not get wrong: authorization codes are
  // delivered to it, so a plain-http host would hand them away.
  test('refuses a callback that is not https', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CLIENTS_PATH(creds.store_id), REGISTER_CTA)

    await page.getByRole('button', { name: REGISTER_CTA }).click()
    const sheet = page.getByRole('dialog')
    await sheet.locator('#oauth-application-name').fill(`CI insecure ${Date.now()}`)
    await sheet.locator('#oauth-application-redirect-uri').fill('http://insecure.example.com/cb')
    await sheet.getByRole('button', { name: /^save$/i }).click()

    // Shown twice: once as a banner at the top of the form, once under the
    // field that caused it.
    await expect(
      sheet.getByRole('alert').filter({ hasText: /must start with https/i }),
    ).toBeVisible({ timeout: 15_000 })
  })
})

test.describe('managing a registered client', () => {
  test('renames one, and removes it', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CLIENTS_PATH(creds.store_id), REGISTER_CTA)

    const name = `CI editable ${Date.now()}`
    await page.getByRole('button', { name: REGISTER_CTA }).click()
    const sheet = page.getByRole('dialog')
    await sheet.locator('#oauth-application-name').fill(name)
    await sheet.locator('#oauth-application-redirect-uri').fill('https://ci.example.com/callback')
    await sheet.getByRole('button', { name: /^save$/i }).click()

    const row = page.getByRole('row', { name: new RegExp(name) })
    await expect(row).toBeVisible({ timeout: 15_000 })

    const renamed = `${name} renamed`
    await row.getByRole('button', { name: /open menu|actions/i }).click()
    await page.getByRole('menuitem', { name: /^edit$/i }).click()
    const editSheet = page.getByRole('dialog')
    await editSheet.locator('#oauth-application-name').fill(renamed)
    await editSheet.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByRole('row', { name: new RegExp(renamed) })).toBeVisible({
      timeout: 15_000,
    })

    await page
      .getByRole('row', { name: new RegExp(renamed) })
      .getByRole('button', { name: /open menu|actions/i })
      .click()
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(page.getByRole('row', { name: new RegExp(renamed) })).toHaveCount(0, {
      timeout: 15_000,
    })
  })
})
