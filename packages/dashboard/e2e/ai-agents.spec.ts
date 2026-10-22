import { expect, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import {
  AGENTS_PATH,
  CLIENTS_PATH,
  CONNECT_CTA,
  clearRegistrations,
  connectKnownClient,
  consentPath,
  REGISTER_CTA,
  registerClient,
  seedConnection,
} from './oauth-helpers'

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

    await expect(page.getByText('Claude').first()).toBeVisible({ timeout: 15_000 })
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
  })

  // Revoking keeps the registration so the same client can be connected
  // again — which is exactly why the card has to say who holds access now.
  test('says who is connected through a registration', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, AGENTS_PATH(creds.store_id), CONNECT_CTA)

    const sheet = await connectKnownClient(page)
    await expect(sheet.getByText(/ready to connect/i)).toBeVisible({ timeout: 15_000 })
    await sheet.getByRole('button', { name: /^done$/i }).click()

    // Registered, but nobody has signed in through it yet.
    await expect(page.getByText(/nobody is connected through this agent/i).first()).toBeVisible({
      timeout: 15_000,
    })
  })
})

// The consent screen is where a person decides, so it has to say where the
// authorization goes. Anyone who may register clients can call theirs
// "Claude" and point it at a host of their own; without the destination on
// the screen, a more privileged colleague approving it would never know.
test.describe('deciding on the consent screen', () => {
  test('says where the authorization will be sent', async ({ page }) => {
    const creds = await login(page)
    await clearRegistrations(page, creds.store_id, creds.accessToken)
    const application = await registerClient(page, creds.store_id, creds.accessToken, {
      name: 'CI Consent',
      redirectUri: 'https://example.test/callback',
    })

    await page.goto(
      consentPath(creds.store_id, {
        clientId: application.client_id,
        redirectUri: 'https://example.test/callback',
      }),
    )

    await expect(page.getByRole('button', { name: /allow access/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(/sent back to example\.test/i)).toBeVisible()
    await expect(page.getByRole('alert').filter({ hasText: /calls itself/i })).toHaveCount(0)
  })

  test('warns when a registration borrows a known name but points elsewhere', async ({ page }) => {
    const creds = await login(page)
    await clearRegistrations(page, creds.store_id, creds.accessToken)
    const application = await registerClient(page, creds.store_id, creds.accessToken, {
      name: 'Claude',
      redirectUri: 'https://attacker.example/callback',
    })

    await page.goto(
      consentPath(creds.store_id, {
        clientId: application.client_id,
        redirectUri: 'https://attacker.example/callback',
      }),
    )

    await expect(
      page.getByRole('alert').filter({ hasText: /calls itself Claude.*attacker\.example/i }),
    ).toBeVisible({ timeout: 15_000 })
  })

  // The connect sheet reuses a registration with the same name rather than
  // creating a second one. It must not hand over one that only borrowed the
  // name, or the merchant would paste a look-alike's client id into Claude.
  test('refuses to reconnect through a registration that only borrowed the name', async ({
    page,
  }) => {
    const creds = await login(page)
    await clearRegistrations(page, creds.store_id, creds.accessToken)
    await registerClient(page, creds.store_id, creds.accessToken, {
      name: 'Claude',
      redirectUri: 'https://attacker.example/callback',
    })
    await gotoIndex(page, AGENTS_PATH(creds.store_id), CONNECT_CTA)

    const sheet = await connectKnownClient(page)

    await expect(
      sheet.getByRole('alert').filter({ hasText: /already registered with a different callback/i }),
    ).toBeVisible({ timeout: 15_000 })
    await expect(sheet.getByText(/ready to connect/i)).toHaveCount(0)
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
    await expect(page.getByText(name).first()).toBeVisible({ timeout: 15_000 })
  })
})

// A store registers an agent once and every staff member connects to that
// same registration, so the card lists the people rather than the agent —
// and revoking has to cut off one of them without touching the rest.
test.describe('a connection someone holds', () => {
  test('names the person, what they approved, and when', async ({ page }) => {
    const creds = await login(page)
    await clearRegistrations(page, creds.store_id, creds.accessToken)
    await seedConnection(page, creds.store_id, creds.accessToken, { name: 'CI Connected' })

    await gotoIndex(page, AGENTS_PATH(creds.store_id), CONNECT_CTA)

    const card = page.locator('[data-slot="card"]').filter({ hasText: 'CI Connected' })
    await expect(card.getByText(creds.admin_email)).toBeVisible({ timeout: 15_000 })
    await expect(card.getByText(/view products/i).first()).toBeVisible()
  })

  // The bug this screen was rebuilt for: one row stood for the whole team,
  // so the only revoke available cut everybody off.
  test('revokes that one person and keeps the registration', async ({ page }) => {
    const creds = await login(page)
    await clearRegistrations(page, creds.store_id, creds.accessToken)
    await seedConnection(page, creds.store_id, creds.accessToken, { name: 'CI Revocable' })

    await gotoIndex(page, AGENTS_PATH(creds.store_id), CONNECT_CTA)

    const card = page.locator('[data-slot="card"]').filter({ hasText: 'CI Revocable' })
    await expect(card.getByText(creds.admin_email)).toBeVisible({ timeout: 15_000 })

    await card
      .getByRole('button', { name: /open menu|actions/i })
      .first()
      .click()
    await page.getByRole('menuitem', { name: /revoke/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /revoke/i })
      .click()

    // The person goes; the agent stays, ready to be connected again.
    await expect(card.getByText(/nobody is connected through this agent/i)).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText('CI Revocable').first()).toBeVisible()
  })
})
