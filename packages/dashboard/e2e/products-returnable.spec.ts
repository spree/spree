import { expect, type Page, test } from '@playwright/test'
import { login, waitForToastsToClear } from './helpers'
import {
  addOptionToVariants,
  card,
  createProduct,
  seedOptionType,
  variantsCard as variantsCardLocator,
} from './products-helpers'

const returnsCard = (page: Page) => card(page, /^Returns$/)

async function saveProduct(page: Page) {
  await page.getByRole('button', { name: /save product/i }).click()
  await expect(page.getByText(/product saved/i)).toBeVisible({ timeout: 30_000 })
  await waitForToastsToClear(page)
}

// Final sale, or goods the EU right of withdrawal exempts: customers cannot
// send them back themselves, and a variant may say otherwise.
test.describe('product returnable', () => {
  test('marks a product final sale and lets one variant stay returnable', async ({ page }) => {
    const creds = await login(page)
    const suffix = Date.now()
    const colorLabel = await seedOptionType(page, creds.store_id, 'color', ['red', 'blue'])
    await createProduct(page, creds.store_id, `E2E Final Sale ${suffix}`)
    await addOptionToVariants(page, colorLabel, ['Red', 'Blue'])

    const toggle = returnsCard(page).getByRole('switch', { name: /customers can return this/i })
    await toggle.scrollIntoViewIfNeeded()
    await expect(toggle).toBeChecked()
    await toggle.click()

    await variantsCardLocator(page)
      .getByRole('button', { name: /^edit .*\bred$/i })
      .click()
    const sheet = page.getByRole('dialog')
    await sheet.getByLabel(/^customers can return this$/i).click()
    await page.getByRole('option', { name: /^returnable$/i }).click()
    await sheet.getByRole('button', { name: /^done$/i }).click()

    await saveProduct(page)
    await page.reload()

    await expect(
      returnsCard(page).getByRole('switch', { name: /customers can return this/i }),
    ).not.toBeChecked({ timeout: 15_000 })
    await variantsCardLocator(page)
      .getByRole('button', { name: /^edit .*\bred$/i })
      .click()
    await expect(page.getByRole('dialog').getByLabel(/^customers can return this$/i)).toHaveText(
      /^returnable$/i,
    )
  })
})
