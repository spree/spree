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

    // 3 × 3 = 9 generated rows. Each row shows composeOptionsText
    // ("Color: Red, Size: S"); asserting on SKU input count is
    // order-independent — 3 × 3 = 9 variants means 9 SKU inputs.
    const variantsCard = variantsCardLocator(page)
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

    // Remove the Blue row via its row-level remove button. Aria-label is
    // `Remove ${variant.label}` and label = composeOptionsText → "<Type>: Blue".
    await variantsCard.getByRole('button', { name: /^remove .*\bblue$/i }).click()
    await expect(variantsCard.getByText('Blue')).toHaveCount(0)

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()
    await expect(variantsCard.getByText('Red').first()).toBeVisible({ timeout: 15_000 })
    await expect(variantsCard.getByText('Blue')).toHaveCount(0)
  })

  test('opens the per-variant edit sheet and edits SKU, weight and dimension unit', async ({
    page,
  }) => {
    const creds = await login(page)

    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red'])

    const productName = `E2E Variant Sheet ${Date.now()}`
    await createProduct(page, creds.store_id, productName)
    await addOptionToVariants(page, colorLabel, ['Red'])

    const variantsCard = variantsCardLocator(page)

    await variantsCard.getByRole('button', { name: /^edit .*\bred$/i }).click()
    const sheet = page.getByRole('dialog')
    await expect(sheet.getByRole('heading', { name: /edit variant — .*\bred$/i })).toBeVisible()

    // Scope to the sheet so we don't fight with the matrix row's SKU input,
    // which is registered on the same form path (matrix uses register; the
    // sheet uses Controller — both stay in sync, but the test wants to
    // verify the sheet's UI specifically).
    await sheet.getByLabel(/^sku$/i).fill('SKU-SHEET-1')
    await sheet.getByLabel(/^weight$/i).fill('1.5')
    // Feet: the last unit the server accepts, once missing from this picker.
    await sheet.locator('[id$="-dim-unit"]').click()
    await page.getByRole('option', { name: 'ft', exact: true }).click()
    await expect(sheet.locator('[id$="-dim-unit"]')).toHaveText('ft')

    await sheet.getByRole('button', { name: /^done$/i }).click()
    await expect(sheet).toBeHidden()

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()
    await variantsCard.getByRole('button', { name: /^edit .*\bred$/i }).click()
    const reopened = page.getByRole('dialog')
    await expect(reopened.getByLabel(/^sku$/i)).toHaveValue('SKU-SHEET-1')
    await expect(reopened.getByLabel(/^weight$/i)).toHaveValue('1.5')
    await expect(reopened.locator('[id$="-dim-unit"]')).toHaveText('ft')
  })

  test('reads weights typed into the bulk editor with grouping and a decimal comma', async ({
    page,
  }) => {
    const creds = await login(page)

    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red', 'blue'])

    const productName = `E2E Bulk Weights ${Date.now()}`
    await createProduct(page, creds.store_id, productName)
    await addOptionToVariants(page, colorLabel, ['Red', 'Blue'])

    const variantsCard = variantsCardLocator(page)
    await variantsCard.getByRole('button', { name: /^bulk edit$/i }).click()
    const grid = page.getByRole('dialog')

    // A spreadsheet cell is read-only until double-clicked.
    for (const [variant, typed] of [
      ['Red', '1,500'],
      ['Blue', '2,5'],
    ]) {
      const cell = grid.getByLabel(new RegExp(`^weight — .*\\b${variant}$`, 'i'))
      await cell.dblclick()
      await cell.fill(typed)
      await cell.press('Enter')
    }
    await expect(grid.getByLabel(/^weight — .*\bred$/i)).toHaveValue('1500')
    await expect(grid.getByLabel(/^weight — .*\bblue$/i)).toHaveValue('2.5')

    await grid.getByRole('button', { name: /^done$/i }).click()
    await expect(grid).toBeHidden()

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()
    for (const [variant, weight] of [
      ['red', '1500'],
      ['blue', '2.5'],
    ]) {
      await variantsCard
        .getByRole('button', { name: new RegExp(`^edit .*\\b${variant}$`, 'i') })
        .click()
      const sheet = page.getByRole('dialog')
      await expect(sheet.getByLabel(/^weight$/i)).toHaveValue(weight)
      await sheet.getByRole('button', { name: /^done$/i }).click()
      await expect(sheet).toBeHidden()
    }
  })
})
