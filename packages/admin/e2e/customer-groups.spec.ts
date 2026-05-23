import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, rowButton } from './helpers'

const CUSTOMER_GROUPS_PATH = (storeId: string) => `/${storeId}/customers/groups`
const CTA = /add customer group/i

async function createCustomerGroup(page: Page, attrs: { name: string; description?: string }) {
  await page.getByRole('button', { name: /add customer group/i }).click()
  await expect(page.getByRole('heading', { name: /add customer group/i })).toBeVisible()

  await page.locator('#name').fill(attrs.name)
  if (attrs.description) await page.locator('#description').fill(attrs.description)

  await page.getByRole('button', { name: /create customer group/i }).click()
}

test.describe('customer groups', () => {
  test('lists customer groups', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMER_GROUPS_PATH(creds.store_id), CTA)
  })

  test('creates a new customer group', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMER_GROUPS_PATH(creds.store_id), CTA)

    const name = `E2E Group ${Date.now()}`
    await createCustomerGroup(page, { name, description: 'For E2E test.' })

    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
  })

  test('edits a group name and description', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMER_GROUPS_PATH(creds.store_id), CTA)

    const original = `E2E Edit Group ${Date.now()}`
    const updated = `${original} (updated)`

    await createCustomerGroup(page, { name: original })
    await expect(rowButton(page, original)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, original).click()
    await expect(page.getByRole('heading', { name: original })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#name')).toHaveValue(original)

    await page.locator('#name').fill(updated)
    await page.locator('#description').fill('Updated description')
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(rowButton(page, updated)).toBeVisible({ timeout: 15_000 })
  })

  test('edit sheet links to the filtered customers view', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMER_GROUPS_PATH(creds.store_id), CTA)

    const name = `E2E Members Link ${Date.now()}`
    await createCustomerGroup(page, { name })
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })

    // Members summary shows "0 customers" (empty by default) + a View members
    // link that deep-links to the customers index with a Ransack filter on
    // `customer_groups_id_in`.
    await expect(page.getByText(/^0 customers$/i)).toBeVisible()
    const link = page.getByRole('link', { name: /view members/i })
    await expect(link).toHaveAttribute('href', /customer_groups_id/)
  })

  test('deletes a customer group', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMER_GROUPS_PATH(creds.store_id), CTA)

    const name = `E2E Delete Group ${Date.now()}`
    await createCustomerGroup(page, { name })
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, name).click()
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete customer group\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
