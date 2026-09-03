import { expect, test } from '@playwright/test'
import { login } from './helpers'

const REPORTS_PATH = (storeId: string) => `/${storeId}/reports`

test.describe('reports', () => {
  test('lists the built-in reports and opens one', async ({ page }) => {
    const creds = await login(page)
    await page.goto(REPORTS_PATH(creds.store_id))

    await expect(page.getByRole('link', { name: /sales over time/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(/^built-in$/i).first()).toBeVisible()

    await page.getByRole('link', { name: /sales over time/i }).click()

    await expect(page.getByRole('heading', { name: /sales over time/i })).toBeVisible({
      timeout: 15_000,
    })
    // A time-series report renders the metric tiles and the comparison legend.
    await expect(page.getByRole('button', { name: /total sales/i })).toBeVisible()
    await expect(page.getByText(/^previous period$/i)).toBeVisible()
    // Built-in reports offer a copy, never an in-place save.
    await expect(page.getByRole('button', { name: /save a copy/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /^save$/i })).toHaveCount(0)
  })

  test('builds, saves, renames and deletes a custom report', async ({ page }) => {
    const creds = await login(page)
    const name = `Orders by payment ${Date.now()}`
    await page.goto(`${REPORTS_PATH(creds.store_id)}/new`)

    await expect(page.getByRole('heading', { name: /^new report$/i })).toBeVisible({
      timeout: 15_000,
    })

    // Group the default metrics by payment status → a ranked table.
    await page.getByRole('combobox', { name: /group by/i }).click()
    await page.getByRole('option', { name: /payment status/i }).click()
    // The seeded database may hold no completed orders in range — a ranked
    // table with the breakdown column, or the empty state, both prove the
    // query ran with the new shape.
    await expect(
      page
        .getByRole('columnheader', { name: /payment status/i })
        .or(page.getByText(/no data for this period/i)),
    ).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /^save$/i }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByLabel(/^name$/i).fill(name)
    await dialog.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('button', { name: /export csv/i })).toBeVisible()

    // Rename through the more-actions menu.
    await page.getByRole('button', { name: /more actions/i }).click()
    await page.getByRole('menuitem', { name: /rename/i }).click()
    await page
      .getByRole('dialog')
      .getByLabel(/^name$/i)
      .fill(`${name} renamed`)
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()
    await expect(page.getByRole('heading', { name: `${name} renamed` })).toBeVisible({
      timeout: 15_000,
    })

    // Delete from the same menu and land back on the list.
    await page.getByRole('button', { name: /more actions/i }).click()
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()
    await expect(page.getByRole('link', { name: /sales over time/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByRole('link', { name: `${name} renamed` })).toHaveCount(0)
  })
})
