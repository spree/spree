import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, rowButton } from './helpers'

const OPTIONS_PATH = (storeId: string) => `/${storeId}/products/options`
const CTA = /add option type/i

async function createOptionType(
  page: Page,
  attrs: { internalName: string; label: string; values?: Array<{ name: string; label: string }> },
) {
  await page.getByRole('button', { name: /add option type/i }).click()
  await expect(page.getByRole('heading', { name: /create option type/i })).toBeVisible()

  // Use `#label` / `#name` directly — row-level option-value inputs also
  // expose accessible names of "Label" / "Internal name", and `getByLabel`'s
  // strict mode rejects ambiguous matches once a value row exists.
  await page.locator('#label').fill(attrs.label)
  await page.locator('#name').fill(attrs.internalName)

  for (const [i, value] of (attrs.values ?? []).entries()) {
    await page.getByRole('button', { name: /add option value/i }).click()
    const row = page
      .locator('tbody tr')
      .filter({ has: page.getByLabel('Internal name') })
      .nth(i)
    await row.getByLabel('Internal name').fill(value.name)
    await row.getByLabel('Label').fill(value.label)
  }

  await page.getByRole('button', { name: /create option type/i }).click()
}

test.describe('option types', () => {
  test('lists option types', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, OPTIONS_PATH(creds.store_id), CTA)
  })

  test('creates a new option type with option values', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, OPTIONS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const internalName = `e2e-size-${suffix}`
    const label = `E2E Size ${suffix}`

    await createOptionType(page, {
      internalName,
      label,
      values: [
        { name: 'small', label: 'Small' },
        { name: 'medium', label: 'Medium' },
      ],
    })

    await expect(rowButton(page, internalName)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(label)).toBeVisible()
  })

  test('edits an option type with option values', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, OPTIONS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const internalName = `e2e-edit-${suffix}`
    const originalLabel = `E2E Edit ${suffix}`
    const updatedLabel = `${originalLabel} (updated)`

    await createOptionType(page, {
      internalName,
      label: originalLabel,
      values: [{ name: 'one', label: 'One' }],
    })
    await expect(rowButton(page, internalName)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, internalName).click()
    await expect(page.getByRole('heading', { name: internalName })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#label')).toHaveValue(originalLabel)

    await page.locator('#label').fill(updatedLabel)

    await page.getByRole('button', { name: /add option value/i }).click()
    const secondRow = page
      .locator('tbody tr')
      .filter({ has: page.getByLabel('Internal name') })
      .nth(1)
    await secondRow.getByLabel('Internal name').fill('two')
    await secondRow.getByLabel('Label').fill('Two')

    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByText(updatedLabel)).toBeVisible({ timeout: 15_000 })
  })

  test('deletes an option type', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, OPTIONS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const internalName = `e2e-delete-${suffix}`
    const label = `E2E Delete ${suffix}`

    await createOptionType(page, { internalName, label })
    await expect(rowButton(page, internalName)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, internalName).click()
    await expect(page.getByRole('heading', { name: internalName })).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete option type\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, internalName)).toHaveCount(0, { timeout: 15_000 })
  })
})
