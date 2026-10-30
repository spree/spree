import { expect, type Page, test } from '@playwright/test'
import { login } from './helpers'

// The palette is reachable from every page, so each spec opens it from the
// store home rather than navigating somewhere specific first.
async function openPalette(page: Page, storeId: string) {
  await page.goto(`/${storeId}`)
  await page.getByRole('button', { name: /search anything/i }).click()
  // Scoped to the dialog: the sidebar trigger and the palette's own input both
  // carry search text, so an unscoped lookup would match two elements.
  const input = page.getByRole('dialog').getByRole('combobox')
  await expect(input).toBeVisible({ timeout: 15_000 })
  return input
}

test.describe('command palette', () => {
  test('opens with the keyboard shortcut', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}`)
    // The shortcut is bound after the shell mounts, so wait for the trigger to
    // appear — pressing earlier lands before the listener exists.
    await expect(page.getByRole('button', { name: /search anything/i })).toBeVisible({
      timeout: 15_000,
    })

    // The binding is `Mod+K`, which the hotkey library resolves against the
    // browser's platform rather than the host's. Try both modifiers so the
    // spec passes on a Linux CI runner and a macOS workstation alike.
    const palette = page.getByRole('dialog').getByRole('combobox')
    await page.keyboard.press('Control+k')
    if (!(await palette.isVisible().catch(() => false))) {
      await page.keyboard.press('Meta+k')
    }

    await expect(palette).toBeVisible({ timeout: 15_000 })
  })

  test('"add product" opens the product create page', async ({ page }) => {
    const creds = await login(page)
    const input = await openPalette(page, creds.store_id)

    await input.fill('add product')
    await page.getByRole('option', { name: /new product/i }).click()

    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/new`))
    await expect(page.getByRole('heading', { name: /new product/i })).toBeVisible({
      timeout: 15_000,
    })
  })

  // Resources without a dedicated `/new` route open a create sheet on their
  // index page instead, which the action reaches via a `?new=true` search param.
  test('"new customer" opens the create sheet on the customers page', async ({ page }) => {
    const creds = await login(page)
    const input = await openPalette(page, creds.store_id)

    await input.fill('new customer')
    await page.getByRole('option', { name: /^new customer$/i }).click()

    await expect(page).toHaveURL(/[?&]new=true/)
    await expect(page.getByRole('heading', { name: /new customer/i })).toBeVisible({
      timeout: 15_000,
    })
  })

  // A bare verb lists every resource the signed-in user may create, which is
  // also how the palette advertises what this dashboard can create at all.
  test('a bare verb lists the create actions', async ({ page }) => {
    const creds = await login(page)
    const input = await openPalette(page, creds.store_id)

    await input.fill('new')

    await expect(page.getByRole('option', { name: /new product/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByRole('option', { name: /^new order$/i })).toBeVisible()
  })

  // With no query the destinations are listed, so there is no empty-list hint.
  test('opens on the list of destinations', async ({ page }) => {
    const creds = await login(page)
    await openPalette(page, creds.store_id)

    const dialog = page.getByRole('dialog')
    await expect(dialog.getByRole('option', { name: /^orders$/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(dialog.getByText(/type to search/i)).toBeHidden()
  })

  // A query naming a destination outright puts that page first, highlighted,
  // so Enter alone reaches it.
  test('Enter opens the highlighted destination', async ({ page }) => {
    const creds = await login(page)
    const input = await openPalette(page, creds.store_id)

    await input.fill('orders')
    const orders = page.getByRole('option', { name: /^orders$/i })
    await expect(orders).toHaveAttribute('data-highlighted', '', { timeout: 15_000 })

    await input.press('Enter')

    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/orders(?:[?#]|$)`))
    await expect(page.getByRole('dialog')).toBeHidden()
  })

  test('arrow keys move the highlight without changing the query', async ({ page }) => {
    const creds = await login(page)
    const input = await openPalette(page, creds.store_id)

    await input.fill('new')
    const options = page.getByRole('dialog').getByRole('option')
    await expect(options.first()).toHaveAttribute('data-highlighted', '', { timeout: 15_000 })

    await input.press('ArrowDown')

    await expect(options.nth(1)).toHaveAttribute('data-highlighted', '')
    await expect(options.first()).not.toHaveAttribute('data-highlighted', '')
    await expect(input).toHaveValue('new')
  })

  test('Escape closes the palette', async ({ page }) => {
    const creds = await login(page)
    const input = await openPalette(page, creds.store_id)

    await input.fill('orders')
    await input.press('Escape')

    await expect(page.getByRole('dialog')).toBeHidden()
  })

  test('reports when a query matches nothing', async ({ page }) => {
    const creds = await login(page)
    const input = await openPalette(page, creds.store_id)

    await input.fill('zzzznotathing')

    await expect(page.getByText(/no results for/i)).toBeVisible({ timeout: 15_000 })
  })
})
