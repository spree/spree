import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import { expect, type Page, test } from '@playwright/test'
import {
  adminApiSession,
  adminRequest,
  clickBulkAction,
  FIXTURE_SELLER_WRITER_EMAIL,
  login,
  openRowMenu,
  sellerLogin,
} from './helpers'
import { inventoryCard, mediaCard } from './products-helpers'

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
  test('shows how many units of a listing are in stock', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    // A shelf of this test's own, so the product has somewhere to hold stock.
    const shelf = `E2E Shelf ${Date.now()}`
    try {
      await page.goto(`${home}/settings/stock-locations`)
      await page.getByRole('button', { name: /add stock location/i }).click({ timeout: 15_000 })
      await page.locator('#name').fill(shelf)
      await page.getByRole('button', { name: /create stock location/i }).click()
      await expect(page.getByRole('row').filter({ hasText: shelf })).toBeVisible({
        timeout: 15_000,
      })

      const name = `E2E Stocked Lamp ${Date.now()}`
      await listProduct(page, home, name)

      const onHand = inventoryCard(page).getByRole('textbox', {
        name: new RegExp(`^on hand at ${shelf}$`, 'i'),
      })
      await onHand.dblclick()
      await onHand.fill('7')
      await onHand.press('Tab')
      await page.getByRole('button', { name: /^save$/i }).click()
      await expect(page.getByText(/product saved/i)).toBeVisible({ timeout: 15_000 })

      await page.goto(`${home}/products`)
      await expect(productRow(page, name).getByText(/^7 in stock$/i)).toBeVisible({
        timeout: 15_000,
      })

      // This seller is not approved to sell yet, so none of its variants count
      // as purchasable; the operator's search still reads the units on hand.
      const operator = await login(page)
      await page.goto(`/${operator.store_id}`)
      await page.getByRole('button', { name: /^search\b/i }).click()
      await page.getByRole('dialog').getByRole('combobox').fill(name)
      await expect(
        page
          .getByRole('option')
          .filter({ hasText: name })
          .getByText(/^in stock$/i),
      ).toBeVisible({ timeout: 15_000 })
    } finally {
      // The fixture seller is shared, so its locations must not pile up.
      const admin = await adminApiSession(page)
      const found = await adminRequest<{ data: { id: string }[] }>(
        page,
        admin,
        'get',
        `/stock_locations?q[name_eq]=${encodeURIComponent(shelf)}`,
      )
      for (const location of found.data) {
        await adminRequest(page, admin, 'delete', `/stock_locations/${location.id}`)
      }
    }
  })

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

  // Saving the product never removes a file it was not sent, so removal goes
  // through its own delete — and a later save must not try it again.
  test('removes a gallery image on save, and saves again cleanly', async ({ page }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    const name = `E2E Lamp ${Date.now()}`
    await listProduct(page, home, name)

    const media = mediaCard(page)
    const tiles = media.locator('[data-slot="media-thumbnail"]')
    await media.locator('input[type="file"]').setInputFiles(DIGITAL_FILE)
    await expect(tiles).toHaveCount(1, { timeout: 15_000 })
    await expect(media.locator('.animate-spin')).toHaveCount(0, { timeout: 15_000 })
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/product saved/i)).toBeVisible({ timeout: 15_000 })
    await page.reload()
    await expect(tiles).toHaveCount(1, { timeout: 30_000 })

    await tiles.first().hover()
    await tiles.first().getByRole('checkbox').check()
    await media.getByRole('button', { name: /^remove$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^remove$/i })
      .click()
    await expect(tiles).toHaveCount(0)
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/product saved/i).last()).toBeVisible({ timeout: 15_000 })

    await page.reload()
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 30_000 })
    await expect(tiles).toHaveCount(0)

    await page.locator('#product-name').fill(`${name} (desk)`)
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByRole('heading', { name: `${name} (desk)` })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(/something went wrong/i)).toHaveCount(0)
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
  test('uploads a digital file, sets its download limits, replaces it, then removes it', async ({
    page,
  }) => {
    // Off by default: the marketplace opens file uploads to its sellers. The
    // replacement below is a format nothing recognises, which the default
    // type list refuses, so the marketplace admits unknown binaries too.
    const admin = await adminApiSession(page)
    const store = await adminRequest<{
      seller_digital_assets_enabled: boolean
      seller_digital_asset_content_types: string[]
    }>(page, admin, 'get', '/store')
    await adminRequest(page, admin, 'patch', '/store', {
      seller_digital_assets_enabled: true,
      seller_digital_asset_content_types: Array.from(
        new Set([...store.seller_digital_asset_content_types, 'application/octet-stream']),
      ),
    })

    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await listProduct(page, home, `E2E Amp Model ${Date.now()}`)

    const digitalCard = page
      .locator('[data-slot="card"]')
      .filter({ has: page.locator('[data-slot="card-title"]', { hasText: /^Digital files$/ }) })
    await expect(digitalCard).toHaveCount(1)

    const fileName = path.basename(DIGITAL_FILE)
    const chooser = page.waitForEvent('filechooser')
    await digitalCard.getByRole('button', { name: /drag & drop files here/i }).click()
    await (await chooser).setFiles(DIGITAL_FILE)

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

    // Replacing keeps the row and its limits; only the file changes.
    const replacementName = 'clean-tube-amp.nam'
    await openRowMenu(page, fileName)
    await page.getByRole('menuitem', { name: /replace file/i }).click()
    const replaceChooser = page.waitForEvent('filechooser')
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^confirm$/i })
      .click()
    await (await replaceChooser).setFiles({
      name: replacementName,
      mimeType: 'application/octet-stream',
      buffer: Buffer.from('replacement capture'),
    })
    const replacedRow = digitalCard.locator('tr').filter({ hasText: replacementName })
    await expect(replacedRow).toBeVisible({ timeout: 30_000 })
    await expect(replacedRow.getByRole('cell', { name: '3', exact: true })).toBeVisible()

    await openRowMenu(page, replacementName)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^confirm$/i })
      .click()

    await expect(replacedRow).toBeHidden({ timeout: 15_000 })
    await expect(digitalCard.getByText(/drag & drop files here/i)).toBeVisible()

    // Put the store back so later specs read what the seed left.
    await adminRequest(page, admin, 'patch', '/store', {
      seller_digital_assets_enabled: store.seller_digital_assets_enabled,
      seller_digital_asset_content_types: store.seller_digital_asset_content_types,
    })
  })
})
