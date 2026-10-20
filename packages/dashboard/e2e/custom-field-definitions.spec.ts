import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const PATH = (storeId: string) => `/${storeId}/settings/custom-field-definitions`
const CTA = /add custom field/i

async function createDefinition(
  page: Page,
  attrs: { label: string; key: string; namespace?: string; appliesTo?: RegExp },
) {
  await page.getByRole('button', { name: CTA }).click()
  await expect(page.getByRole('heading', { name: /add custom field/i })).toBeVisible()

  if (attrs.appliesTo) {
    await page.locator('#cfd-resource-type').click()
    await page.getByRole('option', { name: attrs.appliesTo }).click()
  }
  await page.getByLabel(/^label$/i).fill(attrs.label)
  if (attrs.namespace) {
    await page.getByLabel(/^namespace$/i).fill(attrs.namespace)
  }
  await page.getByLabel(/^key$/i).fill(attrs.key)
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
    await expect(page.getByLabel(/^label$/i)).toHaveValue(original)

    // Resource type + field type pickers must be disabled in edit mode —
    // changing either would orphan or misinterpret stored values.
    await expect(page.getByLabel(/^applies to$/i)).toBeDisabled()
    await expect(page.getByLabel(/^type$/i)).toBeDisabled()

    await page.getByLabel(/^label$/i).fill(updated)
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

  // Resource types travel as short names (`category`), both in the picker and
  // in the filter each record's custom fields card loads its definitions by.
  test('a definition for categories is offered on a category and keeps its value', async ({
    page,
  }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const label = `E2E Aisle ${suffix}`
    await createDefinition(page, { label, key: `aisle_${suffix}`, appliesTo: /^categories$/i })
    await expect(
      page
        .getByRole('row')
        .filter({ has: rowButton(page, label) })
        .getByText(/^categories$/i),
    ).toBeVisible({ timeout: 15_000 })

    await page.goto(`/${creds.store_id}/products/categories/new`)
    await page.locator('#category-name').fill(`E2E CF Category ${suffix}`)
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page).toHaveURL(/\/products\/categories\/(?!new(?:\?|$))/, { timeout: 15_000 })

    const customFields = page
      .locator('[data-slot="card"]')
      .filter({ has: page.locator('[data-slot="card-title"]', { hasText: /^custom fields$/i }) })
    const input = customFields.getByLabel(new RegExp(`^${label}$`, 'i'))
    await expect(input).toBeVisible({ timeout: 15_000 })
    await input.fill('Aisle 7')
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByRole('button', { name: /^save$/i })).toBeDisabled({ timeout: 15_000 })

    await page.reload()
    await expect(customFields.getByLabel(new RegExp(`^${label}$`, 'i'))).toHaveValue('Aisle 7', {
      timeout: 15_000,
    })
  })
  test('a definition for customers is offered on a customer and keeps its value', async ({
    page,
  }) => {
    const creds = await login(page)
    await gotoIndex(page, PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const label = `E2E Tier ${suffix}`
    await createDefinition(page, { label, key: `tier_${suffix}`, appliesTo: /^customers$/i })

    const email = `e2e-cf-customer-${suffix}@example.com`
    await page.goto(`/${creds.store_id}/customers`)
    await page.getByRole('button', { name: /new customer/i }).click()
    await page.locator('#email').fill(email)
    await page.getByRole('button', { name: /^create customer$/i }).click()
    await expect(page.getByRole('heading', { name: email })).toBeVisible({ timeout: 15_000 })

    const customFields = page
      .locator('[data-slot="card"]')
      .filter({ has: page.locator('[data-slot="card-title"]', { hasText: /^custom fields$/i }) })
    await customFields.getByRole('button', { name: /^edit$/i }).click()
    await customFields.getByLabel(new RegExp(`^${label}$`, 'i')).fill('Gold')
    await customFields.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/custom fields saved/i)).toBeVisible({ timeout: 15_000 })

    await page.reload()
    await expect(customFields.getByText('Gold')).toBeVisible({ timeout: 15_000 })
  })
})
