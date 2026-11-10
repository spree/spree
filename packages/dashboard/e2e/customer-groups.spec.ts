import { expect, type Page, test } from '@playwright/test'
import {
  FIXTURE_PROMO_CUSTOMER_EMAIL,
  FIXTURE_PROMO_CUSTOMER_FULL_NAME,
  gotoIndex,
  login,
  openRowMenu,
  rowButton,
  section,
} from './helpers'

const CUSTOMER_GROUPS_PATH = (storeId: string) => `/${storeId}/customers/groups`
const CTA = /add customer group/i

async function createCustomerGroup(page: Page, attrs: { name: string; description?: string }) {
  await page.getByRole('button', { name: /add customer group/i }).click()
  await expect(page.getByRole('heading', { name: /add customer group/i })).toBeVisible()

  await page.locator('#name').fill(attrs.name)
  if (attrs.description) await page.locator('#description').fill(attrs.description)

  // The sheet's plugin slot, filled by src/testing/slot-probes.tsx.
  await expect(page.getByText('Slot probe: customer_group.form_fields (new)')).toBeVisible()
  await page.getByRole('button', { name: /create customer group/i }).click()
  // Creating opens the new group's page.
  await expect(page.getByRole('heading', { name: attrs.name, level: 1 })).toBeVisible({
    timeout: 15_000,
  })
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

    await expect(
      section(page, /^members/i).getByText(/no customers in this group yet/i),
    ).toBeVisible()
    await page.goto(CUSTOMER_GROUPS_PATH(creds.store_id))
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
  })

  test('edits a group name and description on its page', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMER_GROUPS_PATH(creds.store_id), CTA)

    const original = `E2E Edit Group ${Date.now()}`
    const updated = `${original} (updated)`
    await createCustomerGroup(page, { name: original })

    await expect(page.locator('#name')).toHaveValue(original)
    await expect(page.getByText('Slot probe: customer_group.form_fields (edit)')).toBeVisible()
    await page.locator('#name').fill(updated)
    await page.locator('#description').fill('Updated description')
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByRole('heading', { name: updated, level: 1 })).toBeVisible({
      timeout: 15_000,
    })
    await page.goto(CUSTOMER_GROUPS_PATH(creds.store_id))
    await expect(rowButton(page, updated)).toBeVisible({ timeout: 15_000 })
  })

  test('adds a customer to the group and removes them', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMER_GROUPS_PATH(creds.store_id), CTA)

    const name = `E2E Members Group ${Date.now()}`
    await createCustomerGroup(page, { name })

    const members = section(page, /^members/i)
    await members.getByRole('button', { name: /add customer/i }).click()
    await page.locator('#group-member-customer').click()
    await page
      .getByPlaceholder(/search/i)
      .last()
      .fill(FIXTURE_PROMO_CUSTOMER_EMAIL)
    await page.getByRole('option', { name: new RegExp(FIXTURE_PROMO_CUSTOMER_FULL_NAME) }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^add customer$/i })
      .click()

    // The whole identity is one link to the customer.
    const member = members.getByRole('link', { name: new RegExp(FIXTURE_PROMO_CUSTOMER_FULL_NAME) })
    await expect(member).toBeVisible({ timeout: 15_000 })
    await expect(member).toContainText(FIXTURE_PROMO_CUSTOMER_EMAIL)

    await members.getByRole('button', { name: /open actions/i }).click()
    await page.getByRole('menuitem', { name: /remove from group/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /remove from group/i })
      .click()
    await expect(members.getByText(/no customers in this group yet/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  test('opens the group page from the list', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMER_GROUPS_PATH(creds.store_id), CTA)

    const name = `E2E Open Group ${Date.now()}`
    await createCustomerGroup(page, { name })
    await page.goto(CUSTOMER_GROUPS_PATH(creds.store_id))

    await rowButton(page, name).click()
    await expect(page.getByRole('heading', { name, level: 1 })).toBeVisible({ timeout: 15_000 })
    await expect(page).toHaveURL(/\/customers\/groups\/cg_/)
  })

  test('deletes a customer group', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMER_GROUPS_PATH(creds.store_id), CTA)

    const name = `E2E Delete Group ${Date.now()}`
    await createCustomerGroup(page, { name })
    await page.goto(CUSTOMER_GROUPS_PATH(creds.store_id))
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete customer group\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
