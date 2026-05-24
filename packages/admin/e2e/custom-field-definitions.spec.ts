import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const PATH = (storeId: string) => `/${storeId}/settings/custom-field-definitions`
const CTA = /add custom field/i

async function createDefinition(
  page: Page,
  attrs: { label: string; key: string; namespace?: string; resourceLabel?: RegExp },
) {
  await page.getByRole('button', { name: CTA }).click()
  await expect(page.getByRole('heading', { name: /add custom field/i })).toBeVisible()

  await page.locator('#cfd-label').fill(attrs.label)
  if (attrs.namespace) {
    await page.locator('#cfd-namespace').fill(attrs.namespace)
  }
  await page.locator('#cfd-key').fill(attrs.key)
  await page.getByRole('button', { name: /create custom field/i }).click()
}

test.describe('custom field definitions', () => {
  test('lists custom field definitions', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)
  })

  test('creates a new definition', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const label = `E2E Field ${suffix}`
    const key = `e2e_${suffix}`

    await createDefinition(page, { label, key })
    await expect(rowButton(page, label)).toBeVisible({ timeout: 15_000 })
  })

  test('edits a definition', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const original = `E2E Edit Field ${suffix}`
    const updated = `${original} (updated)`
    const key = `edit_${suffix}`

    await createDefinition(page, { label: original, key })
    await expect(rowButton(page, original)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, original).click()
    await expect(page.getByRole('heading', { name: original })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#cfd-label')).toHaveValue(original)

    // Resource type picker must be disabled in edit mode — orphaning stored
    // values by repointing the owner would silently break consumers.
    await expect(page.locator('#cfd-resource-type')).toBeDisabled()

    await page.locator('#cfd-label').fill(updated)
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(rowButton(page, updated)).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a definition', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const label = `E2E Delete Field ${suffix}`
    const key = `delete_${suffix}`

    await createDefinition(page, { label, key })
    await expect(rowButton(page, label)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, label)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete custom field\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, label)).toHaveCount(0, { timeout: 15_000 })
  })
})
