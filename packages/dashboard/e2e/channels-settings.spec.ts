import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const CHANNELS_PATH = (storeId: string) => `/${storeId}/settings/channels`
const ADD_CTA = /new sales channel/i

async function createChannel(page: Page, attrs: { name: string; code?: string }) {
  await page.getByRole('button', { name: ADD_CTA }).click()
  await expect(page.getByRole('heading', { name: /add sales channel/i })).toBeVisible()

  await page.getByLabel(/^name$/i).fill(attrs.name)
  if (attrs.code !== undefined) {
    await page.getByLabel(/^code$/i).fill(attrs.code)
  }

  await page.getByRole('button', { name: /create sales channel/i }).click()
}

test.describe('settings / channels', () => {
  test('lists channels', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CHANNELS_PATH(creds.store_id), ADD_CTA)
  })

  test('auto-derives the code from the name and lists the new channel without a reload', async ({
    page,
  }) => {
    const creds = await login(page)
    await gotoIndex(page, CHANNELS_PATH(creds.store_id), ADD_CTA)

    const suffix = Date.now()
    const name = `E2E Channel ${suffix}`
    // ActiveSupport's +String#parameterize+: lowercase, hyphen-separated. The
    // SPA's +slugifyChannelCode+ must produce the same string the user can
    // submit with the auto-fill alone.
    const expectedCode = `e2e-channel-${suffix}`

    await page.getByRole('button', { name: ADD_CTA }).click()
    await expect(page.getByRole('heading', { name: /add sales channel/i })).toBeVisible()

    await page.getByLabel(/^name$/i).fill(name)
    // Auto-derive should populate +code+ without us touching the field.
    await expect(page.getByLabel(/^code$/i)).toHaveValue(expectedCode)

    await page.getByRole('button', { name: /create sales channel/i }).click()

    // List refresh after create — the new row appears without reloading.
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('cell', { name: expectedCode, exact: true })).toBeVisible()
  })

  test('stops auto-deriving once the user edits the code field', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CHANNELS_PATH(creds.store_id), ADD_CTA)

    const suffix = Date.now()
    const customCode = `e2e-custom-${suffix}`

    await page.getByRole('button', { name: ADD_CTA }).click()
    await page.getByLabel(/^name$/i).fill('Initial Name')
    await page.getByLabel(/^code$/i).fill(customCode)
    // Keep typing on the name — code must NOT follow once it's been touched.
    await page.getByLabel(/^name$/i).fill('Renamed Channel')
    await expect(page.getByLabel(/^code$/i)).toHaveValue(customCode)
  })

  test('edits an existing channel', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CHANNELS_PATH(creds.store_id), ADD_CTA)

    const suffix = Date.now()
    const original = `E2E Channel Edit ${suffix}`
    const updated = `${original} (updated)`

    await createChannel(page, { name: original })
    await expect(rowButton(page, original)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, original).click()
    await expect(page.getByRole('heading', { name: original })).toBeVisible({ timeout: 15_000 })

    await page.getByLabel(/^name$/i).fill(updated)

    // Pick the routing strategy by its human label — the dropdown must surface
    // readable option labels, never the raw strategy class name.
    await page.locator('#preferred_order_routing_strategy').click()
    await page.getByRole('option', { name: /^rules \(ordered\)$/i }).click()

    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(rowButton(page, updated)).toBeVisible({ timeout: 15_000 })
  })

  test('manages order routing rules on a channel', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CHANNELS_PATH(creds.store_id), ADD_CTA)

    const suffix = Date.now()
    const name = `E2E Channel Routing ${suffix}`

    await createChannel(page, { name })
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })

    // A new channel seeds its three default rules in priority order.
    const ruleRow = (label: string | RegExp) => page.locator('li', { hasText: label })
    await expect(ruleRow(/preferred location/i)).toBeVisible({ timeout: 15_000 })
    await expect(ruleRow(/minimize splits/i)).toBeVisible()
    await expect(ruleRow(/default location/i)).toBeVisible()

    // Every built-in kind is already on the channel — nothing left to add.
    await expect(page.getByRole('button', { name: /add rule/i })).toHaveCount(0)

    // The editor only applies to the Rules strategy — switching to Legacy hides it.
    // Wait for the select popup to fully close after each pick so a lingering
    // overlay can't intercept the next click. (No Escape here — the popup
    // closes on selection, and a stray Escape would close the sheet instead.)
    await page.locator('#preferred_order_routing_strategy').click()
    await page.getByRole('option', { name: /^legacy$/i }).click()
    await expect(page.getByRole('listbox')).toBeHidden()
    await expect(page.getByText(/order routing rules/i)).toHaveCount(0)
    await page.locator('#preferred_order_routing_strategy').click()
    await page.getByRole('option', { name: /^rules \(ordered\)$/i }).click()
    await expect(page.getByRole('listbox')).toBeHidden()
    await expect(ruleRow(/preferred location/i)).toBeVisible()

    // Toggle a rule off — the switch state must survive the refetch.
    const preferredSwitch = ruleRow(/preferred location/i).getByRole('switch')
    await expect(preferredSwitch).toBeChecked()
    await preferredSwitch.click()
    await expect(preferredSwitch).not.toBeChecked({ timeout: 15_000 })

    // Delete a rule (confirm dialog on top of the sheet).
    await ruleRow(/default location/i)
      .getByRole('button', { name: /^delete$/i })
      .click()
    await expect(page.getByRole('heading', { name: /delete routing rule\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .filter({ hasText: /delete routing rule\?/i })
      .getByRole('button', { name: /^delete$/i })
      .click()
    await expect(ruleRow(/default location/i)).toHaveCount(0, { timeout: 15_000 })

    // Deleting freed up a kind, so the add button reappears — and the picker
    // offers only the missing kind.
    await page.getByRole('button', { name: /add rule/i }).click()
    await expect(page.getByRole('button', { name: /minimize splits/i })).toHaveCount(0)
    await page.getByRole('button', { name: /prefer the stock location marked as default/i }).click()
    await expect(ruleRow(/default location/i)).toBeVisible({ timeout: 15_000 })

    // All kinds used again — the add affordance goes away.
    await expect(page.getByRole('button', { name: /add rule/i })).toHaveCount(0)
  })

  test('deletes a non-default channel', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CHANNELS_PATH(creds.store_id), ADD_CTA)

    const suffix = Date.now()
    const name = `E2E Channel Delete ${suffix}`

    await createChannel(page, { name })
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()

    await expect(page.getByRole('dialog')).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
