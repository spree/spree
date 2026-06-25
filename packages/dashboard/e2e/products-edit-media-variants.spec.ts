import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import { expect, test } from '@playwright/test'
import { login } from './helpers'
import {
  addOptionToVariants,
  clickMediaThumbnailAction,
  createProduct,
  mediaCard,
  seedOptionType,
  variantsCard,
} from './products-helpers'

const FIXTURE_IMAGE = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'fixtures/test-image.png',
)

test.describe('edit product — media variant linking', () => {
  test('toggles a variant assignment on a persisted image and round-trips it', async ({ page }) => {
    const creds = await login(page)

    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red', 'blue'])
    const productName = `E2E Media×Variant ${Date.now()}`
    await createProduct(page, creds.store_id, productName)

    // Add the color option + Red / Blue variants.
    await addOptionToVariants(page, colorLabel, ['Red', 'Blue'])
    const variants = variantsCard(page)
    await expect(variants.getByText('Red').first()).toBeVisible({ timeout: 15_000 })
    await expect(variants.getByText('Blue').first()).toBeVisible({ timeout: 15_000 })

    // Upload an image (still pre-Save on the variants).
    const media = mediaCard(page)
    await media.locator('input[type="file"]').setInputFiles(FIXTURE_IMAGE)
    await expect(media.locator('img[src]').first()).toBeVisible({ timeout: 15_000 })
    // Upload spinner is the user-visible "settled" signal — once gone, the
    // pending entry has been swapped into form state with a signed_id.
    await expect(media.locator('.animate-spin')).toHaveCount(0, { timeout: 15_000 })

    // Save the whole product — variants + media go in one PATCH.
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    // Reload so we know variant_ids reflect the persisted server state, not
    // the form's local optimistic copy.
    await page.reload()
    await expect(media.locator('img[src]').first()).toBeVisible({ timeout: 30_000 })

    // Open the per-image edit sheet via the hover-revealed Edit button.
    await clickMediaThumbnailAction(media, 'edit')
    await expect(page.getByRole('heading', { name: /^edit media$/i })).toBeVisible()

    // The "Assigned variants" pill row shows one button per variant. The
    // accessible name is the variant's `options_text` ("Color: Red", joined
    // by the localized option type label). Match by partial label.
    const sheet = page.getByRole('dialog')
    const redPill = sheet.getByRole('button', { name: /Red$/ })
    const bluePill = sheet.getByRole('button', { name: /Blue$/ })
    await expect(redPill).toHaveAttribute('aria-pressed', 'false')
    await redPill.click()
    await expect(redPill).toHaveAttribute('aria-pressed', 'true')

    // Done closes the sheet (form-backed — no API call yet).
    await sheet.getByRole('button', { name: /^done$/i }).click()
    await expect(page.getByRole('heading', { name: /^edit media$/i })).toBeHidden()

    // Save → PATCH ships media[].variant_ids inline.
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    // Reload, reopen the sheet, assert Red is still pressed and Blue is not.
    await page.reload()
    await expect(media.locator('img[src]').first()).toBeVisible({ timeout: 30_000 })
    await clickMediaThumbnailAction(media, 'edit')
    await expect(page.getByRole('heading', { name: /^edit media$/i })).toBeVisible()

    await expect(redPill).toHaveAttribute('aria-pressed', 'true')
    await expect(bluePill).toHaveAttribute('aria-pressed', 'false')
  })

  test('edits alt text on a persisted image and round-trips it', async ({ page }) => {
    const creds = await login(page)
    const productName = `E2E Alt ${Date.now()}`
    await createProduct(page, creds.store_id, productName)

    // Upload one image, save the product so the asset is persisted.
    const media = mediaCard(page)
    await media.locator('input[type="file"]').setInputFiles(FIXTURE_IMAGE)
    await expect(media.locator('img[src]').first()).toBeVisible({ timeout: 15_000 })
    await expect(media.locator('.animate-spin')).toHaveCount(0, { timeout: 15_000 })
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    // Reload so the alt-text edit hits the persisted asset.
    await page.reload()
    await expect(media.locator('img[src]').first()).toBeVisible({ timeout: 30_000 })

    // Open the sheet, type new alt text, click Done.
    await clickMediaThumbnailAction(media, 'edit')
    const sheet = page.getByRole('dialog')
    const altInput = sheet.getByRole('textbox')
    const newAlt = `Alt text ${Date.now()}`
    await altInput.fill(newAlt)
    await sheet.getByRole('button', { name: /^done$/i }).click()
    await expect(page.getByRole('heading', { name: /^edit media$/i })).toBeHidden()

    // Save product — alt rides the same PATCH.
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    // Reload and reopen the sheet — alt persisted.
    await page.reload()
    await expect(media.locator('img[src]').first()).toBeVisible({ timeout: 30_000 })
    await clickMediaThumbnailAction(media, 'edit')
    await expect(sheet.getByRole('textbox')).toHaveValue(newAlt)

    // ---- Regression: Cancel after editing must actually discard. ----
    // The earlier implementation used form.reset(..., { keepDirtyValues:true })
    // which PRESERVES dirty values rather than restoring the snapshot — so
    // Cancel was a silent no-op for any edit the user actually made.
    await sheet.getByRole('textbox').fill('TYPED THEN CANCELLED')
    await sheet.getByRole('button', { name: /^cancel$/i }).click()
    await expect(page.getByRole('heading', { name: /^edit media$/i })).toBeHidden()

    // Re-open: the alt input shows the restored snapshot value, not the
    // typed-then-cancelled text. (The parent form's isDirty bit may stay
    // true — the merchant can click Save to commit a no-op, that's an
    // acceptable trade-off for a per-field-scoped restore that doesn't
    // accidentally wipe sibling edits.)
    await clickMediaThumbnailAction(media, 'edit')
    await expect(sheet.getByRole('textbox')).toHaveValue(newAlt)
  })
})
