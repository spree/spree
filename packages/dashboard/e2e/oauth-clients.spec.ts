import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'

const AGENTS_PATH = (storeId: string) => `/${storeId}/settings/connected-apps`
const CLIENTS_PATH = (storeId: string) => `/${storeId}/settings/oauth-clients`
const CONNECT_CTA = /connect an agent/i
const REGISTER_CTA = /register a client/i

/**
 * Registers a client through the connect sheet, the way a merchant does:
 * pick the assistant, continue, and the sheet hands back its address and id.
 */
async function connectKnownClient(page: Page) {
  await page.getByRole('button', { name: CONNECT_CTA }).click()
  const sheet = page.getByRole('dialog')
  await expect(sheet.getByText(/choose the assistant/i)).toBeVisible()

  // The callback is filled in for a client we know, so a merchant never sees
  // a URL field — picking a name is the whole choice.
  await expect(sheet.getByText(/callback url/i)).toHaveCount(0)

  await sheet.getByText(/claude\.ai, claude desktop/i).click()
  await sheet.getByRole('button', { name: /^continue$/i }).click()

  return sheet
}

test.describe('connecting an agent', () => {
  test('registers the client and shows what to paste into it', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, AGENTS_PATH(creds.store_id), CONNECT_CTA)

    const sheet = await connectKnownClient(page)

    await expect(sheet.getByText(/ready to connect/i)).toBeVisible({ timeout: 15_000 })
    await expect(sheet.getByText(/mcp address/i)).toBeVisible()
    await expect(sheet.getByText(/client id/i)).toBeVisible()

    // Claude Code connects by command rather than by pasting an address, so
    // the two surfaces are tabbed rather than listed together.
    await sheet.getByRole('tab', { name: /claude code/i }).click()
    await expect(sheet.getByText(/claude mcp add/i)).toBeVisible()

    await sheet.getByRole('button', { name: /^done$/i }).click()
  })

  // Revoking keeps the registration so the same client can be connected
  // again — which is exactly why the row has to say what changed.
  test('says whether a registration is connected', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, AGENTS_PATH(creds.store_id), CONNECT_CTA)

    const sheet = await connectKnownClient(page)
    await expect(sheet.getByText(/ready to connect/i)).toBeVisible({ timeout: 15_000 })
    await sheet.getByRole('button', { name: /^done$/i }).click()

    // Registered but nobody has signed in through it yet.
    await expect(page.getByText(/not connected/i).first()).toBeVisible({ timeout: 15_000 })
  })
})

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
