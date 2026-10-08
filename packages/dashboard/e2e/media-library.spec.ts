import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import { E2E_DIR } from './paths'
import { mediaCard, PRODUCTS_PATH } from './products-helpers'

const MEDIA_PATH = (storeId: string) => `/${storeId}/products/media`
const FIXTURE_IMAGE = readFileSync(resolve(E2E_DIR, 'fixtures/test-image.png'))

/** Uploads the fixture image under a name of its own, so a search finds just this one. */
async function uploadImage(page: Page, name: string) {
  await page.locator('input[type="file"]').setInputFiles({
    name,
    mimeType: 'image/png',
    buffer: FIXTURE_IMAGE,
  })
  await expect(page.getByText(/1 file uploaded/i)).toBeVisible({ timeout: 20_000 })
}

async function findTile(page: Page, text: string) {
  await page.getByRole('searchbox').fill(text)
  const tile = page.getByRole('listitem').filter({ hasText: text }).getByRole('button')
  await expect(tile).toBeVisible({ timeout: 15_000 })
  return tile
}

test.describe('media library', () => {
  test('uploads an image and describes it for screen readers', async ({ page }) => {
    const creds = await login(page)
    await page.goto(MEDIA_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^media$/i })).toBeVisible({ timeout: 15_000 })

    const name = `e2e-library-${Date.now()}.png`
    await uploadImage(page, name)

    await (await findTile(page, name)).click()
    const sheet = page.getByRole('dialog')
    await expect(sheet.getByRole('heading', { name })).toBeVisible()
    // Freshly uploaded, so nothing uses it yet.
    await expect(sheet.getByText(/not used anywhere/i)).toBeVisible()

    await sheet.locator('#media-alt').fill('A red test swatch')
    await sheet.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/^saved$/i).first()).toBeVisible({ timeout: 15_000 })
    // The grid captions a file by its description once it has one.
    await sheet.getByRole('button', { name: /^cancel$/i }).click()
    await expect(page.getByRole('listitem').filter({ hasText: 'A red test swatch' })).toBeVisible()
  })

  test('deletes a file from the grid after confirming', async ({ page }) => {
    const creds = await login(page)
    await page.goto(MEDIA_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^media$/i })).toBeVisible({ timeout: 15_000 })

    const name = `e2e-doomed-${Date.now()}.png`
    await uploadImage(page, name)

    await (await findTile(page, name)).click({ button: 'right' })
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete this file\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(page.getByText(/no files match your filters/i)).toBeVisible({ timeout: 15_000 })
  })

  // Usage references name their owner by short type (`product`), which is
  // what turns a placement into a link back to the record using the file.
  test('links a file to the product it is used on', async ({ page }) => {
    const creds = await login(page)
    const suffix = Date.now()
    const productName = `E2E Media Owner ${suffix}`
    const fileName = `e2e-used-${suffix}.png`

    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), /add product/i)
    await page.getByRole('button', { name: /add product/i }).click()
    await expect(page.getByRole('heading', { name: /^new product$/i })).toBeVisible()
    await page.getByLabel(/^name$/i).fill(productName)
    await mediaCard(page)
      .locator('input[type="file"]')
      .setInputFiles({ name: fileName, mimeType: 'image/png', buffer: FIXTURE_IMAGE })
    await expect(mediaCard(page).locator('img[src]').first()).toBeVisible({ timeout: 15_000 })
    await expect(mediaCard(page).locator('.animate-spin')).toHaveCount(0, { timeout: 15_000 })
    await page.getByRole('button', { name: /^create product$/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 30_000,
    })

    await page.goto(MEDIA_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^media$/i })).toBeVisible({ timeout: 15_000 })
    await (await findTile(page, fileName)).click()
    const sheet = page.getByRole('dialog')
    const usage = sheet.getByRole('link', { name: productName })
    await expect(usage).toBeVisible({ timeout: 15_000 })

    await usage.click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 15_000,
    })
  })
})
