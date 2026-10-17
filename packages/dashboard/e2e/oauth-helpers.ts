import { expect, type Page } from '@playwright/test'

export const AGENTS_PATH = (storeId: string) => `/${storeId}/settings/ai-agents`
export const CLIENTS_PATH = (storeId: string) => `/${storeId}/settings/oauth-clients`
export const CONNECT_CTA = /connect an agent/i
export const REGISTER_CTA = /register a client/i

/**
 * Registers a client through the connect sheet, the way a merchant does:
 * pick the assistant, continue, and the sheet hands back its address and id.
 */
export async function connectKnownClient(page: Page) {
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
export async function clearRegistrations(page: Page, storeId: string, accessToken: string) {
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

/**
 * Connects an agent for real: registers a client, then walks consent and the
 * token exchange exactly as a client does.
 *
 * There is no endpoint that mints a token — by design, since a connection is
 * something a person approves. So a spec that needs one has to earn it the
 * way the product does.
 */
export async function seedConnection(
  page: Page,
  storeId: string,
  accessToken: string,
  { name, scope = 'read_products' }: { name: string; scope?: string },
) {
  const headers = { 'X-Spree-Store-Id': storeId, Authorization: `Bearer ${accessToken}` }

  const registered = await page.request.post('/api/v3/admin/oauth/applications', {
    headers,
    data: { name, redirect_uri: 'https://example.test/callback' },
  })
  if (!registered.ok()) {
    throw new Error(`Registering ${name} failed: ${registered.status()} ${await registered.text()}`)
  }
  const application = await registered.json()

  // A fixed verifier and its S256 challenge. The pair only has to be
  // self-consistent — the server checks one against the other.
  const verifier = 'v'.repeat(64)
  const challenge = 'w1TpKUdYE9hUAcNSeeSRFioHDxfUxuHho_JHAfZ_vDM'
  const query = new URLSearchParams({
    client_id: application.client_id,
    redirect_uri: 'https://example.test/callback',
    response_type: 'code',
    scope,
    code_challenge: challenge,
    code_challenge_method: 'S256',
  })

  const approved = await page.request.post(`/api/v3/admin/oauth/authorize?${query}`, { headers })
  if (!approved.ok()) {
    throw new Error(`Consent failed: ${approved.status()} ${await approved.text()}`)
  }
  const code = new URL((await approved.json()).redirect_uri).searchParams.get('code')

  // Straight to Rails: the token endpoint sits outside `/api`, which is the
  // only prefix the dashboard's dev proxy forwards.
  const railsPort = process.env.E2E_RAILS_PORT || '3010'
  const exchanged = await page.request.post(`http://localhost:${railsPort}/oauth/token`, {
    form: {
      grant_type: 'authorization_code',
      code: code ?? '',
      client_id: application.client_id,
      redirect_uri: 'https://example.test/callback',
      code_verifier: verifier,
    },
  })
  if (!exchanged.ok()) {
    throw new Error(`Token exchange failed: ${exchanged.status()} ${await exchanged.text()}`)
  }

  return application
}
