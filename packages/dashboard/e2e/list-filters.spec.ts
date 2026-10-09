import { expect, type Page, test } from '@playwright/test'
import {
  addListFilter,
  deleteSeededRecords,
  login,
  narrowQuickFilter,
  searchList,
  seedRecord,
} from './helpers'

// Searches and filters the API used to ignore, so each list came back whole
// while the control said it was narrowed. Each test narrows a list of its own
// records and checks that one leaves it.

const stamp = () => `${Date.now()}`
const row = (page: Page, text: string) => page.getByRole('row').filter({ hasText: text })

test.afterEach(({ page }) => deleteSeededRecords(page))

async function openList(page: Page, path: string, search: RegExp) {
  await page.goto(path)
  await expect(page.getByPlaceholder(search)).toBeVisible({ timeout: 15_000 })
}

test.describe('list filters', () => {
  test('searches allowed origins', async ({ page }) => {
    const session = await login(page)
    const id = stamp()
    const kept = `https://shop-${id}.example.com`
    const other = `https://admin-${id}.example.com`
    for (const origin of [kept, other]) {
      await seedRecord(page, session, '/allowed_origins', { origin })
    }

    await openList(page, `/${session.store_id}/settings/allowed-origins`, /search by origin/i)
    await searchList(page, /search by origin/i, `shop-${id}`)

    await expect(row(page, kept)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, other)).toBeHidden()
  })

  test('filters payment methods by status', async ({ page }) => {
    const session = await login(page)
    const id = stamp()
    const active = `E2E Active ${id}`
    const inactive = `E2E Inactive ${id}`
    await seedRecord(page, session, '/payment_methods', {
      type: 'check',
      name: active,
      active: true,
    })
    await seedRecord(page, session, '/payment_methods', {
      type: 'check',
      name: inactive,
      active: false,
    })

    await openList(page, `/${session.store_id}/settings/payment-methods`, /search by name/i)
    await searchList(page, /search by name/i, id)
    await expect(row(page, active)).toBeVisible({ timeout: 15_000 })

    await addListFilter(page, /^status$/i, /^no$/i)

    await expect(row(page, inactive)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, active)).toBeHidden()
  })

  test('filters sellers by status', async ({ page }) => {
    const session = await login(page)
    const name = `E2E Filter Seller ${stamp()}`
    await seedRecord(page, session, '/sellers', {
      name,
      contact_email: `filter-seller-${Date.now()}@example.com`,
    })

    await openList(page, `/${session.store_id}/sellers`, /search sellers/i)
    await searchList(page, /search sellers/i, name)
    await expect(row(page, name)).toBeVisible({ timeout: 15_000 })

    // A new seller has not been approved, so narrowing to approved sellers drops it.
    await narrowQuickFilter(page, /^status/i, /^approved$/i)

    await expect(row(page, name)).toBeHidden({ timeout: 15_000 })
  })

  test('filters option types by kind', async ({ page }) => {
    const session = await login(page)
    const id = stamp()
    const swatch = `e2e-swatch-${id}`
    const buttons = `e2e-buttons-${id}`
    await seedRecord(page, session, '/option_types', {
      name: swatch,
      label: swatch,
      kind: 'color_swatch',
    })
    await seedRecord(page, session, '/option_types', {
      name: buttons,
      label: buttons,
      kind: 'buttons',
    })

    await openList(page, `/${session.store_id}/products/options`, /search by name/i)
    await searchList(page, /search by name/i, id)
    await expect(row(page, buttons)).toBeVisible({ timeout: 15_000 })

    await narrowQuickFilter(page, /^kind/i, /^color swatch$/i)

    await expect(row(page, swatch)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, buttons)).toBeHidden()
  })

  test('filters custom field definitions by type', async ({ page }) => {
    const session = await login(page)
    const id = stamp()
    const number = `weight_${id}`
    const text = `fabric_${id}`
    for (const [key, fieldType] of [
      [number, 'number'],
      [text, 'short_text'],
    ]) {
      await seedRecord(page, session, '/custom_field_definitions', {
        namespace: 'e2e',
        key,
        field_type: fieldType,
        resource_type: 'product',
      })
    }

    const search = /search by label, namespace, or key/i
    await openList(page, `/${session.store_id}/settings/custom-field-definitions`, search)
    await searchList(page, search, id)
    await expect(row(page, text)).toBeVisible({ timeout: 15_000 })

    await addListFilter(page, /^type$/i, /^number$/i)

    await expect(row(page, number)).toBeVisible({ timeout: 15_000 })
    await expect(row(page, text)).toBeHidden()
  })
})
