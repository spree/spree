import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import {
  addOptionToVariants,
  clickMediaThumbnailAction,
  createProduct,
  mediaCard,
  PRODUCTS_PATH,
  seedOptionType,
  variantsCard,
} from './products-helpers'

// The slots plugins extend the product page with, filled by the probes in
// src/testing/slot-probes.tsx. A host-form field proves the slot renders
// inside the product form and saves with its Save button.

const FIXTURE_IMAGE = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'fixtures/test-image.png',
)

async function saveProduct(page: Page) {
  await page.getByRole('button', { name: /save product/i }).click()
  await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
    timeout: 30_000,
  })
}

test.describe('product page slots', () => {
  test('renders the column slots on the create and edit pages', async ({ page }) => {
    const creds = await login(page)

    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), /add product/i)
    await page.getByRole('button', { name: /add product/i }).click()
    await expect(page.getByText('Slot probe: product.form_main (new)')).toBeVisible()
    await expect(page.getByText('Slot probe: product.form_sidebar (new)')).toBeVisible()

    await createProduct(page, creds.store_id, `E2E Slots ${Date.now()}`)
    await expect(page.getByText('Slot probe: product.form_main (edit)')).toBeVisible()
    await expect(page.getByText('Slot probe: product.form_sidebar (edit)')).toBeVisible()
  })

  test('a media sheet field saves with the product and Cancel discards it', async ({ page }) => {
    const creds = await login(page)
    await createProduct(page, creds.store_id, `E2E Media Slot ${Date.now()}`)

    const media = mediaCard(page)
    await media.locator('input[type="file"]').setInputFiles(FIXTURE_IMAGE)
    await expect(media.locator('.animate-spin')).toHaveCount(0, { timeout: 15_000 })
    await saveProduct(page)
    await page.reload()

    await clickMediaThumbnailAction(media, 'edit')
    const sheet = page.getByRole('dialog')
    await sheet.getByLabel('Probe media credit').fill('Photo by Jane')
    await sheet.getByRole('button', { name: /^done$/i }).click()
    await saveProduct(page)

    await page.reload()
    await clickMediaThumbnailAction(media, 'edit')
    await expect(sheet.getByLabel('Probe media credit')).toHaveValue('Photo by Jane')

    await sheet.getByLabel('Probe media credit').fill('Typed then cancelled')
    await sheet.getByRole('button', { name: /^cancel$/i }).click()
    await clickMediaThumbnailAction(media, 'edit')
    await expect(sheet.getByLabel('Probe media credit')).toHaveValue('Photo by Jane')
  })

  test('media added by a media actions widget saves with the product', async ({ page }) => {
    const creds = await login(page)
    await createProduct(page, creds.store_id, `E2E Media Action ${Date.now()}`)

    const media = mediaCard(page)
    await media.getByRole('button', { name: 'Probe attach video' }).click()
    await expect(media.locator('[data-slot="media-thumbnail"]')).toHaveCount(1)
    await saveProduct(page)

    await page.reload()
    await expect(media.locator('[data-slot="media-thumbnail"]')).toHaveCount(1, {
      timeout: 30_000,
    })
  })

  test('a variant sheet field saves with the product', async ({ page }) => {
    const creds = await login(page)
    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red'])
    await createProduct(page, creds.store_id, `E2E Variant Slot ${Date.now()}`)
    await addOptionToVariants(page, colorLabel, ['Red'])

    const variants = variantsCard(page)
    await variants.getByRole('button', { name: /^edit .*\bred$/i }).click()
    const sheet = page.getByRole('dialog')
    await sheet.getByLabel('Probe variant code').fill('ACME-RED')
    await sheet.getByRole('button', { name: /^done$/i }).click()
    await saveProduct(page)

    await page.reload()
    await variants.getByRole('button', { name: /^edit .*\bred$/i }).click()
    await expect(page.getByRole('dialog').getByLabel('Probe variant code')).toHaveValue('ACME-RED')
  })
})
