import { expect, test } from '@playwright/test'
import { login } from './helpers'
import {
  addOptionToVariants,
  createProduct,
  seedOptionType,
  variantsCard as variantsCardLocator,
} from './products-helpers'

test.describe('product variants', () => {
  test('builds variants from two option types and persists them', async ({ page }) => {
    const creds = await login(page)

    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red', 'blue', 'green'])
    const sizeLabel = await seedOptionType(page, creds.store_id, 'size', ['s', 'm', 'l'])

    const productName = `E2E Variants ${Date.now()}`
    await createProduct(page, creds.store_id, productName)

    await addOptionToVariants(page, colorLabel, ['Red', 'Blue', 'Green'])
    await addOptionToVariants(page, sizeLabel, ['S', 'M', 'L'])

    // 3 × 3 = 9 generated rows. Each cell shows the joined label "Red / S".
    const variantsCard = variantsCardLocator(page)

    // The matrix row label joins canonical option value names with " / "
    // (e.g. "red / s" or "s / red"). The slash order depends on the seeded
    // option_type positions, which vary between local and CI. Asserting on
    // the SKU input count is order-independent — 3 × 3 = 9 variants means
    // 9 SKU inputs.
    const skuInputs = variantsCard.getByRole('textbox', { name: /^sku$/i })
    await expect(skuInputs).toHaveCount(9, { timeout: 15_000 })

    // Fill SKUs on the first three rows so we can confirm round-trip persistence.
    await skuInputs.nth(0).fill('TSHIRT-RED-S')
    await skuInputs.nth(1).fill('TSHIRT-RED-M')
    await skuInputs.nth(2).fill('TSHIRT-RED-L')

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    // Reload — all 9 SKU rows must still be there.
    await page.reload()
    await expect(skuInputs).toHaveCount(9, { timeout: 15_000 })
    await expect(skuInputs.nth(0)).toHaveValue('TSHIRT-RED-S')
    await expect(skuInputs.nth(1)).toHaveValue('TSHIRT-RED-M')
    await expect(skuInputs.nth(2)).toHaveValue('TSHIRT-RED-L')
  })

  test('removes a variant row and persists the deletion', async ({ page }) => {
    const creds = await login(page)

    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red', 'blue'])

    const productName = `E2E Variant Delete ${Date.now()}`
    await createProduct(page, creds.store_id, productName)
    await addOptionToVariants(page, colorLabel, ['Red', 'Blue'])

    const variantsCard = variantsCardLocator(page)

    // Matrix renders the option value name both as a badge AND in a table
    // cell, so `.getByText('Red')` is ambiguous (strict mode violation).
    // Scope to the first match to assert presence — the symmetric "not
    // visible" check tolerates `count = 0`, so leave that as-is below.
    await expect(variantsCard.getByText('Red').first()).toBeVisible({ timeout: 15_000 })
    await expect(variantsCard.getByText('Blue').first()).toBeVisible()

    // Remove the Blue row via its row-level remove button.
    await variantsCard.getByRole('button', { name: /^remove blue$/i }).click()
    await expect(variantsCard.getByText('Blue')).toHaveCount(0)

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()
    await expect(variantsCard.getByText('Red').first()).toBeVisible({ timeout: 15_000 })
    await expect(variantsCard.getByText('Blue')).toHaveCount(0)
  })

  // Skipped: pre-existing flake — both the matrix and the edit sheet register
  test('opens the per-variant edit sheet and edits SKU + weight', async ({ page }) => {
    const creds = await login(page)

    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red'])

    const productName = `E2E Variant Sheet ${Date.now()}`
    await createProduct(page, creds.store_id, productName)
    await addOptionToVariants(page, colorLabel, ['Red'])

    const variantsCard = variantsCardLocator(page)

    await variantsCard.getByRole('button', { name: /^edit red$/i }).click()
    const sheet = page.getByRole('dialog')
    await expect(sheet.getByRole('heading', { name: /edit variant — red/i })).toBeVisible()

    // Scope to the sheet so we don't fight with the matrix row's SKU input,
    // which is registered on the same form path (matrix uses register; the
    // sheet uses Controller — both stay in sync, but the test wants to
    // verify the sheet's UI specifically).
    await sheet.getByLabel(/^sku$/i).fill('SKU-SHEET-1')
    await sheet.getByLabel(/^weight$/i).fill('1.5')

    await sheet.getByRole('button', { name: /^done$/i }).click()
    await expect(sheet).toBeHidden()

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()
    await variantsCard.getByRole('button', { name: /^edit red$/i }).click()
    const reopened = page.getByRole('dialog')
    await expect(reopened.getByLabel(/^sku$/i)).toHaveValue('SKU-SHEET-1')
    await expect(reopened.getByLabel(/^weight$/i)).toHaveValue('1.5')
  })
})
