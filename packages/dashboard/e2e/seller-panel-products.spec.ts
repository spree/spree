import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import { expect, type Page, test } from '@playwright/test'
import { clickBulkAction, FIXTURE_SELLER_WRITER_EMAIL, openRowMenu, sellerLogin } from './helpers'

// The card serves whatever is attached, so the shared image fixture will do.
const DIGITAL_FILE = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'fixtures/test-image.png',
)

/** Lists a product from the panel's form and returns to the seller's product list. */
async function listProduct(page: Page, home: string, name: string) {
  await page.goto(`${home}/products/new`)
  await page.locator('#product-name').fill(name)
  await page.getByRole('button', { name: /^save$/i }).click()
  await expect(page).toHaveURL(/\/products\/prod_/, { timeout: 20_000 })
  await expect(page.getByRole('heading', { name })).toBeVisible()
}

function productRow(page: Page, name: string) {
  return page.getByRole('row').filter({ hasText: name })
}

async function selectProduct(page: Page, name: string) {
  await productRow(page, name)
    .getByRole('checkbox', { name: /select row/i })
    .check()
}

test.describe('seller panel — products', () => {
  test('renames a listing from its own page', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    const name = `E2E Vase ${Date.now()}`
    await listProduct(page, home, name)

    await page.locator('#product-name').fill(`${name} (large)`)
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/product saved/i)).toBeVisible({ timeout: 15_000 })

    await page.goto(`${home}/products`)
    await expect(productRow(page, `${name} (large)`)).toBeVisible({ timeout: 15_000 })
  })

  // Putting a product on sale is the marketplace's decision; the seller asks.
  test('submits a draft for review', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    const name = `E2E Bowl ${Date.now()}`
    await listProduct(page, home, name)

    await page.goto(`${home}/products`)
    await expect(productRow(page, name).getByText(/^draft$/i)).toBeVisible({ timeout: 15_000 })
    await selectProduct(page, name)
    await clickBulkAction(page, /submit for review/i)
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /submit for review/i })
      .click()

    await expect(productRow(page, name).getByText(/^in review$/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  test('deletes a listing after confirming', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    const name = `E2E Chipped Mug ${Date.now()}`
    await listProduct(page, home, name)

    await page.goto(`${home}/products`)
    await expect(productRow(page, name)).toBeVisible({ timeout: 15_000 })
    await selectProduct(page, name)
    await clickBulkAction(page, /^delete$/i)
    await expect(
      page.getByRole('heading', { name: /delete the selected products\?/i }),
    ).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(productRow(page, name)).toHaveCount(0, { timeout: 15_000 })
  })

  // A seller selling downloads manages the files on their own listing.
  test('uploads a digital file, sets its download limits, then removes it', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await listProduct(page, home, `E2E Amp Model ${Date.now()}`)

    const digitalCard = page
      .locator('[data-slot="card"]')
      .filter({ has: page.locator('[data-slot="card-title"]', { hasText: /^Digital files$/ }) })
    await expect(digitalCard).toHaveCount(1)

    const fileName = path.basename(DIGITAL_FILE)
    await digitalCard.locator('input[type="file"]').setInputFiles(DIGITAL_FILE)

    const fileRow = digitalCard.locator('tr').filter({ hasText: fileName })
    await expect(fileRow).toBeVisible({ timeout: 30_000 })

    await openRowMenu(page, fileName)
    await page.getByRole('menuitem', { name: /^edit$/i }).click()
    const sheet = page.getByRole('dialog')
    await sheet.getByLabel(/downloads allowed/i).fill('3')
    await sheet.getByLabel(/days available/i).fill('30')
    await sheet.getByRole('button', { name: /^save$/i }).click()
    await expect(sheet).toBeHidden()

    await expect(fileRow.getByRole('cell', { name: '3', exact: true })).toBeVisible({
      timeout: 15_000,
    })
    await expect(fileRow.getByRole('cell', { name: '30', exact: true })).toBeVisible()

    await openRowMenu(page, fileName)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^confirm$/i })
      .click()

    await expect(fileRow).toBeHidden({ timeout: 15_000 })
    await expect(digitalCard.getByText(/drag & drop files here/i)).toBeVisible()
  })
})
