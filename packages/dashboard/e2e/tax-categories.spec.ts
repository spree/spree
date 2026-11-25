import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const TAX_CATEGORIES_PATH = (storeId: string) => `/${storeId}/settings/taxes/categories`
const CTA = /add tax category/i

async function createTaxCategory(
  page: Page,
  attrs: { name: string; taxCode?: string; description?: string },
) {
  await page.getByRole('button', { name: /add tax category/i }).click()
  await expect(page.getByRole('heading', { name: /add tax category/i })).toBeVisible()

  await page.locator('#name').fill(attrs.name)
  if (attrs.taxCode) await page.locator('#tax_code').fill(attrs.taxCode)
  if (attrs.description) await page.locator('#description').fill(attrs.description)

  // The sheet's plugin slot, filled by src/testing/slot-probes.tsx.
  await expect(page.getByText('Slot probe: tax_category.form_fields (new)')).toBeVisible()
  await page.getByRole('button', { name: /create tax category/i }).click()
}

// The e2e app loads no engine with a code search (Avalara needs credentials),
// so one is added to the engine list and its catalogue answered here.
const LOOKUP_ENGINE = 'e2e_lookup'
const CATALOGUE = [
  { code: 'PC040100', description: 'Clothing and related products (business-to-consumer)' },
  { code: 'PC040200', description: 'Clothing and related products (business-to-business)' },
]

async function stubTaxCodeLookup(page: Page) {
  await page.route('**/api/v3/admin/tax_providers', async (route) => {
    const response = await route.fetch()
    const body = await response.json()
    const engines = body.data.map((engine: Record<string, unknown>) => ({
      ...engine,
      default: false,
    }))
    engines.push({
      ...engines[0],
      id: LOOKUP_ENGINE,
      name: 'E2E Lookup',
      default: true,
      available: true,
      tax_code_lookup: true,
    })
    await route.fulfill({ response, json: { ...body, data: engines } })
  })

  await page.route(`**/api/v3/admin/tax_providers/${LOOKUP_ENGINE}/tax_codes?*`, async (route) => {
    const query = (new URL(route.request().url()).searchParams.get('q') ?? '').toLowerCase()
    const data = CATALOGUE.filter(
      (entry) =>
        entry.code.toLowerCase().startsWith(query) ||
        entry.description.toLowerCase().includes(query),
    )
    await route.fulfill({ json: { data } })
  })
}

test.describe('tax category code lookup', () => {
  test('picks a code from the engine search and keeps it', async ({ page }) => {
    await stubTaxCodeLookup(page)
    const creds = await login(page)
    await gotoIndex(page, TAX_CATEGORIES_PATH(creds.store_id), CTA)

    const name = `E2E Lookup Tax ${Date.now()}`
    await page.getByRole('button', { name: CTA }).click()
    await page.locator('#name').fill(name)

    await page.locator('#tax_code').fill('clothing')
    await expect(page.getByRole('option', { name: /PC040200/ })).toBeVisible()
    await page.getByRole('option', { name: /PC040100/ }).click()
    await page.getByRole('button', { name: /create tax category/i }).click()
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#tax_code')).toHaveValue('PC040100')
  })

  test('saves a code the engine does not list', async ({ page }) => {
    await stubTaxCodeLookup(page)
    const creds = await login(page)
    await gotoIndex(page, TAX_CATEGORIES_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const name = `E2E Typed Tax ${suffix}`
    const code = `ZZ${suffix}`
    await page.getByRole('button', { name: CTA }).click()
    await page.locator('#name').fill(name)

    await page.locator('#tax_code').fill(code)
    await page.getByRole('option', { name: /use this code/i }).click()
    await page.getByRole('button', { name: /create tax category/i }).click()
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#tax_code')).toHaveValue(code)
  })
})

test.describe('tax categories', () => {
  test('lists tax categories', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TAX_CATEGORIES_PATH(creds.store_id), CTA)
  })

  test('creates a new tax category', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TAX_CATEGORIES_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const name = `E2E Tax ${suffix}`

    await createTaxCategory(page, { name, taxCode: `TX${suffix}`, description: 'For E2E test.' })

    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
  })

  test('edits a tax category', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TAX_CATEGORIES_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const original = `E2E Edit Tax ${suffix}`
    const updated = `${original} (updated)`

    await createTaxCategory(page, { name: original })
    await expect(rowButton(page, original)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, original).click()
    await expect(page.getByRole('heading', { name: original })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#name')).toHaveValue(original)

    await page.locator('#name').fill(updated)
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(rowButton(page, updated)).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a tax category', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, TAX_CATEGORIES_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const name = `E2E Delete Tax ${suffix}`

    await createTaxCategory(page, { name })
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    // Delete now lives on the row-action kebab.
    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete tax category\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
