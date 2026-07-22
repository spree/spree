import { expect, test } from '@playwright/test'
import { login } from './helpers'

const HOME_PATH = (storeId: string) => `/${storeId}`

test.describe('home dashboard', () => {
  test('renders KPI tiles with the comparison chart', async ({ page }) => {
    const creds = await login(page)
    await page.goto(HOME_PATH(creds.store_id))

    await expect(page.getByRole('heading', { name: /^dashboard$/i })).toBeVisible({
      timeout: 15_000,
    })

    // KPI metric tiles (buttons that switch the chart metric)
    await expect(page.getByRole('button', { name: /total sales/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /total orders/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /avg order value/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /units sold/i })).toBeVisible()

    // Comparison legend under the chart
    await expect(page.getByText(/^this period$/i)).toBeVisible()
    await expect(page.getByText(/^previous period$/i)).toBeVisible()

    // Switching the active metric keeps the chart rendered
    await page.getByRole('button', { name: /total orders/i }).click()
    await expect(page.getByText(/^this period$/i)).toBeVisible()
  })

  test('renders the operations and rankings widgets', async ({ page }) => {
    const creds = await login(page)
    await page.goto(HOME_PATH(creds.store_id))

    await expect(page.getByRole('heading', { name: /^dashboard$/i })).toBeVisible({
      timeout: 15_000,
    })

    // Operations rows
    await expect(page.getByText(/orders to fulfill/i)).toBeVisible()
    await expect(page.getByText(/payments to collect/i)).toBeVisible()
    await expect(page.getByText(/open returns/i)).toBeVisible()
    await expect(page.getByText(/low stock variants/i)).toBeVisible()
    await expect(page.getByText(/out of stock variants/i)).toBeVisible()

    // Rankings card with customer/category tabs
    await expect(page.getByText('Rankings', { exact: true })).toBeVisible()
    await page.getByRole('button', { name: /^categories$/i }).click()
    await page.getByRole('button', { name: /^customers$/i }).click()
  })

  test('orders to fulfill links to the filtered orders list', async ({ page }) => {
    const creds = await login(page)
    await page.goto(HOME_PATH(creds.store_id))

    await page.getByText(/orders to fulfill/i).click()

    await expect(page).toHaveURL(/\/orders\?/, { timeout: 15_000 })
    await expect(page.getByText(/fulfillment/i).first()).toBeVisible()
  })
})
