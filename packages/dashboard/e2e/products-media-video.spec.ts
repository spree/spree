import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import { expect, test } from '@playwright/test'
import { login } from './helpers'
import { clickMediaThumbnailAction, createProduct, mediaCard } from './products-helpers'

const FIXTURE_IMAGE = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'fixtures/test-image.png',
)

test.describe('product media — video', () => {
  test('adds a YouTube video and persists it through save', async ({ page }) => {
    const creds = await login(page)
    await createProduct(page, creds.store_id, `E2E Video ${Date.now()}`)

    const media = mediaCard(page)
    await media.getByRole('button', { name: /add video/i }).click()

    const dialog = page.getByRole('dialog')
    await dialog.getByLabel(/video link/i).fill('https://www.youtube.com/watch?v=dQw4w9WgXcQ')
    await dialog.getByRole('button', { name: /add video/i }).click()

    // The tile previews from YouTube's own still, so an image appears without
    // anything being uploaded.
    await expect(media.locator('img[src]').first()).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /^save$/i }).click()
    await page.reload()

    // Survives the round trip: the gallery still shows one tile after reload.
    await expect(media.locator('img[src]').first()).toBeVisible({ timeout: 30_000 })
  })

  test('gives a video a poster image', async ({ page }) => {
    const creds = await login(page)
    await createProduct(page, creds.store_id, `E2E Poster ${Date.now()}`)

    const media = mediaCard(page)
    await media.getByRole('button', { name: /add video/i }).click()

    const dialog = page.getByRole('dialog')
    // Vimeo supplies no thumbnail, so this is the case that needs a poster.
    await dialog.getByLabel(/video link/i).fill('https://vimeo.com/123456789')
    await dialog.getByRole('button', { name: /add video/i }).click()

    // Open the tile's editor and upload the still.
    await clickMediaThumbnailAction(media, 'edit')
    const sheet = page.getByRole('dialog')
    await sheet.locator('input[type="file"]').setInputFiles(FIXTURE_IMAGE)
    await expect(sheet.locator('img[src]').first()).toBeVisible({ timeout: 15_000 })
    await sheet.getByRole('button', { name: /^done$/i }).click()

    await page.getByRole('button', { name: /^save$/i }).click()
    await page.reload()

    // The poster survives the round trip — the tile renders it after reload.
    await expect(media.locator('img[src]').first()).toBeVisible({ timeout: 30_000 })
  })

  test('refuses a link that is not a video', async ({ page }) => {
    const creds = await login(page)
    await createProduct(page, creds.store_id, `E2E Bad Video ${Date.now()}`)

    await mediaCard(page)
      .getByRole('button', { name: /add video/i })
      .click()

    const dialog = page.getByRole('dialog')
    await dialog.getByLabel(/video link/i).fill('https://example.com/clip.mp4')
    await dialog.getByRole('button', { name: /add video/i }).click()

    await expect(dialog.getByText(/youtube or vimeo/i)).toBeVisible()
    // The dialog stays open — nothing was added.
    await expect(dialog).toBeVisible()
  })
})
