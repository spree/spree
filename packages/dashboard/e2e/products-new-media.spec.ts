import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import { expect, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import { clickMediaThumbnailAction, mediaCard, PRODUCTS_PATH } from './products-helpers'

const FIXTURE_IMAGE = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'fixtures/test-image.png',
)

test.describe('new product — media', () => {
  test('uploads media pre-save and persists it through product creation', async ({ page }) => {
    const creds = await login(page)
    const productName = `E2E New Media ${Date.now()}`

    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), /add product/i)
    await page.getByRole('button', { name: /add product/i }).click()
    await expect(page.getByRole('heading', { name: /^new product$/i })).toBeVisible()
    await page.getByLabel(/^name$/i).fill(productName)

    // Drive the file input directly — drag/drop in Playwright requires
    // synthetic events that some browsers fight. The hidden <input
    // type=file> is the same code path the click-to-browse uses.
    const media = mediaCard(page)
    await media.locator('input[type="file"]').setInputFiles(FIXTURE_IMAGE)

    // Once upload completes, the thumbnail switches from the in-flight
    // pending render (opacity 60 + spinner) to a static one. Look for an
    // <img> inside the card with the local object URL.
    await expect(media.locator('img[src]').first()).toBeVisible({ timeout: 15_000 })
    // Wait for the upload spinner (Loader2Icon.animate-spin in MediaCard's
    // pending render) to clear. Once it's gone, the pending entry has been
    // replaced by a real `media` row with a signed_id — form state is settled
    // and clicking Create is safe.
    await expect(media.locator('.animate-spin')).toHaveCount(0, { timeout: 15_000 })

    // Save → product created with media attached → navigates to edit page.
    await page.getByRole('button', { name: /^create product$/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 30_000,
    })

    // Reload from the edit page so the media query refetches from a fresh
    // cache; useProductMedia then renders the API-served URL. Without the
    // explicit reload the cache can lag behind cross-route invalidation.
    await page.reload()
    await expect(media.locator('img[src]').first()).toBeVisible({ timeout: 30_000 })
  })

  test('removes a pending media item before save', async ({ page }) => {
    const creds = await login(page)
    const productName = `E2E Remove Media ${Date.now()}`

    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), /add product/i)
    await page.getByRole('button', { name: /add product/i }).click()
    await page.getByLabel(/^name$/i).fill(productName)

    const media = mediaCard(page)
    await media.locator('input[type="file"]').setInputFiles(FIXTURE_IMAGE)
    await expect(media.locator('img[src]').first()).toBeVisible({ timeout: 15_000 })
    // Wait for upload to finish — the pending thumbnail img is replaced once
    // the direct upload settles; clicking delete before that races DOM detachment.
    await expect(media.locator('.animate-spin')).toHaveCount(0, { timeout: 15_000 })

    // Hover the thumb to reveal the delete button and click it.
    await clickMediaThumbnailAction(media, 'delete')
    // Confirm the deletion in the dialog (handleDelete uses useConfirm now).
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    // Thumbnail gone.
    await expect(media.locator('img[src]')).toHaveCount(0)

    // Save still works — product created without media.
    await page.getByRole('button', { name: /^create product$/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 30_000,
    })
  })
})
