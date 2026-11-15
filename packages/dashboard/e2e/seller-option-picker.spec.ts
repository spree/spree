import { expect, type Page, test } from '@playwright/test'
import { FIXTURE_SELLER_WRITER_EMAIL, login, sellerLogin } from './helpers'
import { seedOptionType, variantsCard } from './products-helpers'

/** Lists a product from the panel's form and stays on its page. */
async function listProduct(page: Page, home: string, name: string) {
  await page.goto(`${home}/products/new`)
  await page.locator('#product-name').fill(name)
  await page.getByRole('button', { name: /^save$/i }).click()
  await expect(page).toHaveURL(/\/products\/prod_/, { timeout: 20_000 })
  await expect(page.getByRole('heading', { name })).toBeVisible()
}

// The option vocabulary is the marketplace's. A seller builds variants from
// what is there and has no way to add to it.
test.describe('seller panel — option picker', () => {
  test('builds a variant from an existing option type, without creating one', async ({ page }) => {
    // The operator defines the vocabulary the seller will pick from.
    const operator = await login(page)
    const optionLabel = await seedOptionType(page, operator.store_id, 'finish', ['matte', 'gloss'])

    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    const name = `E2E Picker Lamp ${Date.now()}`
    await listProduct(page, home, name)

    const card = variantsCard(page)
    await card.getByRole('button', { name: /add option/i }).click()

    // Picking from what exists is offered; creating is not.
    await expect(card.getByRole('button', { name: /create new option type/i })).toHaveCount(0)
    await card.getByRole('combobox').first().click()
    await page.getByRole('option', { name: optionLabel, exact: true }).click()
    await expect(card.getByRole('button', { name: /new value/i })).toHaveCount(0)

    await card.getByRole('button', { name: 'Matte', exact: true }).click()
    await card.getByRole('button', { name: /^done$/i }).click()

    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/product saved/i)).toBeVisible({ timeout: 15_000 })

    // The variant survives a reload, so it was saved against the existing value.
    await page.reload()
    await expect(variantsCard(page).getByRole('button', { name: /^edit .*\bmatte$/i })).toBeVisible(
      {
        timeout: 15_000,
      },
    )
  })
})
