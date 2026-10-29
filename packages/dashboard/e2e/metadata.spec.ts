import { expect, test } from '@playwright/test'
import {
  adminRequest,
  createPlacedOrder,
  deleteSeededRecords,
  type E2ELoginSession,
  gotoIndex,
  login,
  rowButton,
  seedRecord,
} from './helpers'

// Metadata and external references are written by apps and integrations,
// never in the dashboard, so every record here is seeded through the Admin API.
const METADATA = { erp_id: 'ERP-4711' }
const EXTERNAL_REFERENCES = { netsuite: 'NS-0042' }

async function seedCompany(page: Parameters<typeof login>[0], session: E2ELoginSession) {
  return seedRecord(page, session, '/companies', {
    name: `E2E Metadata Co ${Date.now()}`,
    metadata: METADATA,
    external_references: EXTERNAL_REFERENCES,
  })
}

test.describe('metadata', () => {
  test.afterEach(({ page }) => deleteSeededRecords(page))

  test('a detail page folds metadata to a counted header', async ({ page }) => {
    const session = await login(page)
    const company = await seedCompany(page, session)

    await page.goto(`/${session.store_id}/companies/${company.id}`)

    const toggle = page.getByRole('button', { name: /^metadata\s*2$/i })
    await expect(toggle).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText('ERP-4711')).toBeHidden()

    await toggle.click()
    await expect(page.getByText('erp_id')).toBeVisible()
    await expect(page.getByText('ERP-4711')).toBeVisible()
    await expect(page.getByText('External references')).toBeVisible()
    await expect(page.getByText('NS-0042')).toBeVisible()
    await expect(page.getByRole('button', { name: /copy netsuite key/i })).toBeVisible()
  })

  test('a row menu opens the metadata of a nested record', async ({ page }) => {
    const session = await login(page)
    const order = await createPlacedOrder(page, session.accessToken)
    const fulfillments = await adminRequest<{
      data: { id: string; fulfillment_items: { id: string }[] }[]
    }>(page, session, 'get', `/orders/${order.id}/fulfillments?expand=fulfillment_items`)
    const orderReturn = await adminRequest<{ id: string; number: string }>(
      page,
      session,
      'post',
      `/orders/${order.id}/returns`,
      {
        items: [{ fulfillment_item_id: fulfillments.data[0].fulfillment_items[0].id, quantity: 1 }],
      },
    )
    await adminRequest(page, session, 'patch', `/orders/${order.id}/returns/${orderReturn.id}`, {
      metadata: METADATA,
      external_references: EXTERNAL_REFERENCES,
    })
    // References alone are enough to offer the sheet.
    await adminRequest(
      page,
      session,
      'patch',
      `/orders/${order.id}/fulfillments/${fulfillments.data[0].id}`,
      { external_references: { wms: 'SHIP-0042' } },
    )

    await page.goto(`/${session.store_id}/orders/${order.id}`)
    const returns = page.locator('[data-slot="card"]').filter({ hasText: /^returns/i })
    await expect(returns.getByText(orderReturn.number)).toBeVisible({ timeout: 15_000 })
    await returns.getByRole('button', { name: /actions/i }).click()
    await page.getByRole('menuitem', { name: /view metadata/i }).click()

    const sheet = page.getByRole('dialog')
    await expect(sheet.getByText('erp_id')).toBeVisible()
    await expect(sheet.getByText('ERP-4711')).toBeVisible()
    await expect(sheet.getByText('NS-0042')).toBeVisible()
    await page.keyboard.press('Escape')
    await expect(sheet).toBeHidden()

    const fulfillmentsCard = page.locator('[data-slot="card"]').filter({
      has: page.locator('[data-slot="card-title"]', { hasText: /fulfillments/i }),
    })
    await fulfillmentsCard
      .getByRole('button', { name: /actions/i })
      .first()
      .click()
    await page.getByRole('menuitem', { name: /view metadata/i }).click()
    await expect(page.getByRole('dialog').getByText('SHIP-0042')).toBeVisible()
  })

  test('a seller page lists the keys external systems know it by', async ({ page }) => {
    const session = await login(page)
    const seller = await seedRecord(page, session, '/sellers', {
      name: `E2E Referenced Seller ${Date.now()}`,
      external_references: EXTERNAL_REFERENCES,
    })

    await page.goto(`/${session.store_id}/sellers/${seller.id}`)

    const toggle = page.getByRole('button', { name: /^metadata\s*1$/i })
    await expect(toggle).toBeVisible({ timeout: 15_000 })
    await toggle.click()
    await expect(page.getByText('netsuite')).toBeVisible()
    await expect(page.getByText('NS-0042')).toBeVisible()
  })

  test('an edit sheet keeps metadata collapsed until opened', async ({ page }) => {
    const session = await login(page)
    const name = `E2E Metadata Supplier ${Date.now()}`
    await seedRecord(page, session, '/suppliers', { name, metadata: METADATA })

    await gotoIndex(page, `/${session.store_id}/suppliers`, /new supplier/i)
    await rowButton(page, name).click()

    const sheet = page.getByRole('dialog')
    const section = sheet.getByRole('button', { name: /^metadata\s*1$/i })
    await expect(section).toBeVisible({ timeout: 15_000 })
    await expect(sheet.getByText('ERP-4711')).toBeHidden()

    await section.click()
    await expect(sheet.getByText('erp_id')).toBeVisible()
    await expect(sheet.getByText('ERP-4711')).toBeVisible()
  })

  test('an edit sheet shows external references on a record without metadata', async ({ page }) => {
    const session = await login(page)
    const name = `E2E Referenced Warehouse ${Date.now()}`
    await seedRecord(page, session, '/stock_locations', {
      name,
      external_references: EXTERNAL_REFERENCES,
    })

    await gotoIndex(page, `/${session.store_id}/settings/stock-locations`, /add stock location/i)
    await rowButton(page, name).click()

    const sheet = page.getByRole('dialog')
    const section = sheet.getByRole('button', { name: /^metadata\s*1$/i })
    await expect(section).toBeVisible({ timeout: 15_000 })

    await section.click()
    await expect(sheet.getByText('netsuite')).toBeVisible()
    await expect(sheet.getByText('NS-0042')).toBeVisible()
  })
})
