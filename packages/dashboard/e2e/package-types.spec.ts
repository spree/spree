import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const PACKAGE_TYPES_PATH = (storeId: string) => `/${storeId}/settings/package-types`
const CTA = /add package type/i

async function createPackageType(page: Page, name: string) {
  await page.getByRole('button', { name: CTA }).click()
  await page.locator('#package-type-name').fill(name)
  await page.locator('#package-type-length').fill('40')
  await page.locator('#package-type-width').fill('30')
  await page.locator('#package-type-height').fill('20')
  await page.locator('#package-type-weight').fill('0.5')
  await page
    .getByRole('dialog')
    .getByRole('button', { name: /^save$/i })
    .click()
  await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
}

test.describe('package types', () => {
  test('adds a carton and lists its measurements', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PACKAGE_TYPES_PATH(creds.store_id), CTA)

    const name = `E2E Carton ${Date.now()}`
    await createPackageType(page, name)

    const row = page.getByRole('row').filter({ has: rowButton(page, name) })
    await expect(row.getByText(/40(\.0+)? × 30(\.0+)? × 20(\.0+)?/)).toBeVisible()
  })

  test('edits a package type', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PACKAGE_TYPES_PATH(creds.store_id), CTA)

    const name = `E2E Resized ${Date.now()}`
    await createPackageType(page, name)

    await rowButton(page, name).click()
    await expect(page.locator('#package-type-length')).toHaveValue(/^40(\.0+)?$/, {
      timeout: 15_000,
    })
    await page.locator('#package-type-length').fill('45')
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()

    const row = page.getByRole('row').filter({ has: rowButton(page, name) })
    await expect(row.getByText(/45(\.0+)? × 30(\.0+)? × 20(\.0+)?/)).toBeVisible({
      timeout: 15_000,
    })
  })

  test('deletes a package type after confirming', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, PACKAGE_TYPES_PATH(creds.store_id), CTA)

    const name = `E2E Retired Box ${Date.now()}`
    await createPackageType(page, name)

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete package type\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
