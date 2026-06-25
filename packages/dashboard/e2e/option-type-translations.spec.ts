import { expect, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'
import { OPTIONS_PATH, seedOptionType } from './products-helpers'

// The e2e store has a US (en) + Europe (de) market, so `de` is a non-default
// translation locale and the translations editor renders.
test.describe('option type + value translations', () => {
  test('translates an option type and one of its values in one save', async ({ page }) => {
    const creds = await login(page)
    const label = await seedOptionType(page, creds.store_id, 'size', ['small', 'large'])

    // Open the option type's edit sheet, then its translations editor.
    await gotoIndex(page, OPTIONS_PATH(creds.store_id), /add option type/i)
    await page.getByRole('button', { name: label }).click()
    await page.getByRole('button', { name: /manage translations/i }).click()

    const dialog = page.getByRole('dialog')
    await expect(dialog.getByText('Original', { exact: true })).toBeVisible({ timeout: 15_000 })

    // Row 0 is the option type (field `label`); the value rows are labelled by
    // their source ("Small", "Large").
    const suffix = Date.now()
    const typeDe = `Größe ${suffix}`
    const valueDe = `Klein ${suffix}`
    await dialog.getByLabel('label de').fill(typeDe)
    await dialog.getByLabel('Small de').fill(valueDe)

    // One Save batches both the type and the value.
    await dialog.getByRole('button', { name: /^save translations$/i }).click()
    await expect(page.getByText(/translations saved/i)).toBeVisible({ timeout: 15_000 })

    // Reopen and confirm both persisted.
    await page.getByRole('button', { name: /^close$/i }).click()
    await page.getByRole('button', { name: /manage translations/i }).click()
    const reopened = page.getByRole('dialog')
    await expect(reopened.getByLabel('label de')).toHaveValue(typeDe, { timeout: 15_000 })
    await expect(reopened.getByLabel('Small de')).toHaveValue(valueDe)
  })
})
