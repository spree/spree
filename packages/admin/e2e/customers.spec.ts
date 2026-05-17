import { expect, type Page, test } from '@playwright/test'
import { fillAddressForm, gotoIndex, login } from './helpers'

const CUSTOMERS_PATH = (storeId: string) => `/${storeId}/customers`
const CTA = /new customer/i

async function createCustomer(page: Page, email: string) {
  await page.getByRole('button', { name: /new customer/i }).click()
  await expect(page.getByRole('heading', { name: /^new customer$/i })).toBeVisible()
  await page.locator('#email').fill(email)
  await page.getByRole('button', { name: /^create customer$/i }).click()
  await expect(page.getByRole('heading', { name: email })).toBeVisible({ timeout: 15_000 })
}

test.describe('customers', () => {
  test('lists customers', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)
  })

  test('creates a new customer', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-create-${Date.now()}@example.com`
    await createCustomer(page, email)

    // Back to the index, the row appears.
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)
    await expect(page.getByRole('link', { name: email })).toBeVisible({ timeout: 15_000 })
  })

  test('edits a customer profile', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-edit-${Date.now()}@example.com`
    await createCustomer(page, email)

    // `<CardTitle>` renders as a `<div>` (not an `<h*>`), so we scope by text
    // and pick the first Edit button under it.
    const profileCard = page.locator('div').filter({
      has: page.getByText('Profile', { exact: true }),
    })
    await profileCard
      .getByRole('button', { name: /^edit$/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /^edit customer$/i })).toBeVisible()

    await page.locator('#first_name').fill('Pat')
    await page.locator('#last_name').fill('Smith')
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByRole('heading', { name: 'Pat Smith' })).toBeVisible({ timeout: 15_000 })
  })

  test('adds an address', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-addr-${Date.now()}@example.com`
    await createCustomer(page, email)

    await page.getByRole('button', { name: /add address/i }).click()
    await expect(page.getByRole('heading', { name: /^add address$/i })).toBeVisible()

    await fillAddressForm(page, {
      firstName: 'Pat',
      lastName: 'Smith',
      address1: '1 Main St',
      city: 'Anytown',
      postalCode: '12345',
      phone: '555-0100',
      country: 'United States',
      state: 'California',
    })
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByText('1 Main St')).toBeVisible({ timeout: 15_000 })
  })

  test('issues store credit', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-credit-${Date.now()}@example.com`
    await createCustomer(page, email)

    await page.getByRole('button', { name: /issue credit/i }).click()
    await expect(page.getByRole('heading', { name: /issue store credit/i })).toBeVisible()

    await page.locator('#sc-amount').fill('25.00')
    await page.locator('#sc-memo').fill('E2E test credit')
    await page.locator('#sc-category').click()
    await page.getByRole('option').first().click()

    await page.getByRole('button', { name: /^issue credit$/i }).click()

    await expect(page.getByText(/25\.00/).first()).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a customer', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CUSTOMERS_PATH(creds.store_id), CTA)

    const email = `e2e-delete-${Date.now()}@example.com`
    await createCustomer(page, email)

    // PageHeader's more-actions dropdown holds the destructive Delete entry.
    await page.getByRole('button', { name: /more actions/i }).click()
    await page.getByRole('menuitem', { name: /delete customer/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /delete customer/i })
      .click()

    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/customers(?:\\?|$)`), {
      timeout: 15_000,
    })
    await expect(page.getByRole('link', { name: email })).toHaveCount(0, { timeout: 15_000 })
  })
})
