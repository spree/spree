import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { expect, type Page, test } from '@playwright/test'
import { login } from './helpers'
import { E2E_DIR } from './paths'

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
})
