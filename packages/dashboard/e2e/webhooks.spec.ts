import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const WEBHOOKS_PATH = (storeId: string) => `/${storeId}/settings/webhooks`
const CTA = /new endpoint/i

async function createEndpoint(
  page: Page,
  opts: { name: string; url: string; pickEvents?: string[] },
) {
  await page.getByRole('button', { name: CTA }).click()
  await expect(page.getByRole('heading', { name: /add webhook endpoint/i })).toBeVisible()

  await page.locator('#webhook-name').fill(opts.name)
  await page.locator('#webhook-url').fill(opts.url)

  // Base UI's <Checkbox> renders two elements with the same accessible label
  // (a visible role=checkbox span + a hidden native <input>), so `getByLabel`
  // is ambiguous. Target the role=checkbox span by accessible name instead.
  // The label is the literal event name (e.g. `order.completed`).
  for (const ev of opts.pickEvents ?? []) {
    await page.getByRole('checkbox', { name: ev }).click()
  }

  // The Sheet footer renders just "Cancel" + "Create". Match the latter.
  await page
    .locator('[role="dialog"]')
    .getByRole('button', { name: /^create$/i })
    .click()
}

test.describe.configure({ mode: 'serial' })

test.describe('webhooks', () => {
  test('lists webhook endpoints', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, WEBHOOKS_PATH(creds.store_id), CTA)
  })

  test('creates an endpoint, reveals the secret, and navigates to its detail page', async ({
    page,
  }) => {
    const creds = await login(page)
    await gotoIndex(page, WEBHOOKS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const name = `E2E Webhook ${suffix}`
    const url = `https://e2e-${suffix}.example.com/webhooks`

    await createEndpoint(page, {
      name,
      url,
      pickEvents: ['order.completed', 'order.canceled'],
    })

    // One-shot "Save your signing secret" dialog. The reveal is the proof
    // that create returned `secret_key` — that's the response contract.
    await expect(page.getByRole('heading', { name: /save your signing secret/i })).toBeVisible({
      timeout: 15_000,
    })
    await page.getByRole('button', { name: /^done$/i }).click()

    // After dismissing the secret reveal the user lands on the new endpoint's
    // detail page (see `SecretRevealDialog.onOpenChange` in webhooks.tsx).
    await expect(page).toHaveURL(/\/settings\/webhooks\/whe_/, { timeout: 15_000 })
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })

    // Going back to the index, the endpoint shows up in the list — proves
    // cache invalidation across the route change.
    await page.goto(WEBHOOKS_PATH(creds.store_id))
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
  })

  test('clicking the name navigates to the detail page', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, WEBHOOKS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const name = `E2E Edit ${suffix}`
    const url = `https://edit-${suffix}.example.com/hook`

    await createEndpoint(page, { name, url, pickEvents: ['order.completed'] })
    // Skip the secret-reveal redirect: dismiss the dialog *and* go back to
    // the index so we can click the row.
    await page.getByRole('button', { name: /^done$/i }).click()
    await page.goto(WEBHOOKS_PATH(creds.store_id))
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    await expect(page).toHaveURL(/\/settings\/webhooks\/whe_/, { timeout: 15_000 })
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
    // The detail page surfaces the URL as a copyable subtitle next to the
    // title and shows the Send test / Edit action buttons in the header.
    await expect(page.getByText(url, { exact: true })).toBeVisible()
    await expect(page.getByRole('button', { name: /send test/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /^edit$/i })).toBeVisible()
  })

  test('renames an endpoint on its detail page', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, WEBHOOKS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const original = `E2E Rename ${suffix}`
    const updated = `${original} (renamed)`
    const url = `https://rename-${suffix}.example.com/hook`

    await createEndpoint(page, { name: original, url, pickEvents: ['order.completed'] })
    // After the secret-reveal Done we're on the detail page; open the Edit
    // sheet via the header button to access the form fields.
    await page.getByRole('button', { name: /^done$/i }).click()
    await expect(page.getByRole('heading', { name: original })).toBeVisible({ timeout: 15_000 })
    await page.getByRole('button', { name: /^edit$/i }).click()
    await expect(page.locator('#webhook-name')).toHaveValue(original, { timeout: 15_000 })

    await page.locator('#webhook-name').fill(updated)
    await page.getByRole('button', { name: /^save$/i }).click()

    // The page <h1> reflects the new name once the mutation completes
    // (the form revalidates from the cached endpoint and the detail body
    // refetches on invalidation). The Edit sheet's title also reflects the
    // name — scope to the heading-level-1 specifically to disambiguate.
    await expect(page.getByRole('heading', { level: 1, name: updated })).toBeVisible({
      timeout: 15_000,
    })
  })

  test('sends a test delivery and surfaces it in the embedded deliveries list', async ({
    page,
  }) => {
    const creds = await login(page)
    await gotoIndex(page, WEBHOOKS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const name = `E2E Test Send ${suffix}`
    const url = `https://test-${suffix}.example.com/hook`

    await createEndpoint(page, { name, url, pickEvents: ['order.completed'] })
    await page.getByRole('button', { name: /^done$/i }).click()

    // We're on the detail page after the secret-reveal redirect. The "Send
    // test" header button replaces the row kebab menu entry from before.
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
    await page.getByRole('button', { name: /send test/i }).click()

    // Toast confirmation.
    await expect(page.getByText(/test webhook queued/i)).toBeVisible({ timeout: 10_000 })

    // The embedded deliveries `<ResourceTable>` refetches via the
    // useSendTestWebhook invalidation, so a `webhook.test` row appears
    // without a manual refresh.
    await expect(page.getByText('webhook.test', { exact: true }).first()).toBeVisible({
      timeout: 15_000,
    })
  })

  test('deletes an endpoint via the row confirm dialog', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, WEBHOOKS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const name = `E2E Delete ${suffix}`
    const url = `https://del-${suffix}.example.com/hook`

    await createEndpoint(page, { name, url, pickEvents: ['order.completed'] })
    await page.getByRole('button', { name: /^done$/i }).click()
    await page.goto(WEBHOOKS_PATH(creds.store_id))
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete webhook endpoint\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
