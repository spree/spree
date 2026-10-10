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

/**
 * Removes every registration, so the screens show the state a store is in
 * before anyone has connected anything. The suite runs serially and earlier
 * specs register clients, so this cannot be left to ordering.
 */
async function clearRegistrations(page: Page, storeId: string, accessToken: string) {
  const headers = { 'X-Spree-Store-Id': storeId, Authorization: `Bearer ${accessToken}` }
  const res = await page.request.get('/api/v3/admin/oauth/applications?limit=100', { headers })
  if (!res.ok()) throw new Error(`Listing clients failed: ${res.status()} ${await res.text()}`)

  for (const client of (await res.json()).data ?? []) {
    const deleted = await page.request.delete(`/api/v3/admin/oauth/applications/${client.id}`, {
      headers,
    })
    if (!deleted.ok()) {
      throw new Error(`Deleting ${client.id} failed: ${deleted.status()} ${await deleted.text()}`)
    }
  }
}

// Nothing is seeded, so a store that has never connected an agent carries no
// registrations at all — the first thing a merchant sees.
test.describe('before any agent has been connected', () => {
  test('both screens say so rather than showing an empty table', async ({ page }) => {
    const creds = await login(page)
    await clearRegistrations(page, creds.store_id, creds.accessToken)

    await gotoIndex(page, AGENTS_PATH(creds.store_id), CONNECT_CTA)
    await expect(page.getByText(/no agents have been connected/i)).toBeVisible({ timeout: 15_000 })

    await gotoIndex(page, CLIENTS_PATH(creds.store_id), REGISTER_CTA)
    await expect(page.getByText(/no clients registered/i)).toBeVisible({ timeout: 15_000 })
  })

  // The whole point of dropping the seeds: connecting works from nothing.
  test('connecting registers the first client', async ({ page }) => {
    const creds = await login(page)
    await clearRegistrations(page, creds.store_id, creds.accessToken)
    await gotoIndex(page, AGENTS_PATH(creds.store_id), CONNECT_CTA)

    const sheet = await connectKnownClient(page)
    await expect(sheet.getByText(/ready to connect/i)).toBeVisible({ timeout: 15_000 })
    await sheet.getByRole('button', { name: /^done$/i }).click()

    await expect(page.getByRole('row', { name: /Claude/ })).toBeVisible({ timeout: 15_000 })
  })
})

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

test.describe('connecting a client we do not know', () => {
  // A merchant picking Claude never types a callback. Choosing "Something
  // else" is the developer's path, and it is the only one where the field
  // that must be right is filled in by hand.
  test('asks for a callback only once Something else is chosen', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, AGENTS_PATH(creds.store_id), CONNECT_CTA)

    await page.getByRole('button', { name: CONNECT_CTA }).click()
    const sheet = page.getByRole('dialog')

    await expect(sheet.getByText(/callback url/i)).toHaveCount(0)

    await sheet.getByText(/any other client that speaks mcp/i).click()
    await expect(sheet.getByText(/callback url/i)).toBeVisible()

    const name = `CI custom ${Date.now()}`
    await sheet.locator('#mcp-other-name').fill(name)
    await sheet.locator('#mcp-other-uri').fill('https://custom.example.com/oauth/callback')
    await sheet.getByRole('button', { name: /^continue$/i }).click()

    // Its own client id, and no CLI tab — we publish no command for a client
    // we know nothing about.
    await expect(sheet.getByText(/ready to connect/i)).toBeVisible({ timeout: 15_000 })
    await expect(sheet.getByText(/client id/i)).toBeVisible()
    await expect(sheet.getByRole('tab')).toHaveCount(0)

    await sheet.getByRole('button', { name: /^done$/i }).click()
    await expect(page.getByRole('row', { name: new RegExp(name) })).toBeVisible({
      timeout: 15_000,
    })
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
