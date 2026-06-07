import { expect, type Page, test } from '@playwright/test'
import { FIXTURE_BULK_CHANNEL_NAME, gotoIndex, login } from './helpers'
import { PRODUCTS_PATH, publishingCard } from './products-helpers'

// Drive the New Product form just far enough to land on the edit page.
// The point of this spec is the Publishing card, not the rest of the form.
async function createMinimalProduct(page: Page, storeId: string, name: string): Promise<void> {
  await gotoIndex(page, PRODUCTS_PATH(storeId), /add product/i)
  await page.getByRole('button', { name: /add product/i }).click()
  await expect(page.getByRole('heading', { name: /^new product$/i })).toBeVisible()
  await page.getByLabel(/^name$/i).fill(name)
}

test.describe('product publishing', () => {
  test('new product seeds the default channel before save', async ({ page }) => {
    const creds = await login(page)
    const productName = `E2E Publish Default ${Date.now()}`

    await createMinimalProduct(page, creds.store_id, productName)

    // The Publishing card on the New Product page auto-seeds the store's
    // default channel ("Online Store") so merchants don't have to open
    // Manage before save. Asserting on the channel row before clicking
    // Create proves the seed lands client-side (the merchant sees what
    // will be persisted).
    const card = publishingCard(page)
    await expect(card.getByText(/online store/i)).toBeVisible({ timeout: 15_000 })
    await expect(card.getByText(/not listed on any sales channel/i)).not.toBeVisible()

    // Create the product — the seeded publication rides the POST.
    await page.getByRole('button', { name: /^create product$/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 30_000,
    })

    // The publication persisted — the edit page's Publishing card shows it.
    await expect(publishingCard(page).getByText(/online store/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  test('merchant can add a second channel before save', async ({ page }) => {
    const creds = await login(page)
    const productName = `E2E Publish Add Channel ${Date.now()}`

    await createMinimalProduct(page, creds.store_id, productName)
    const card = publishingCard(page)
    await expect(card.getByText(/online store/i)).toBeVisible({ timeout: 15_000 })

    // Add the bulk channel via Manage.
    await card.getByRole('button', { name: /^manage$/i }).click()
    const sheet = page.getByRole('dialog')
    await expect(sheet.getByRole('heading', { name: /^manage sales channels$/i })).toBeVisible()
    await sheet.getByRole('button', { name: new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i') }).click()
    await sheet.getByRole('button', { name: /^done$/i }).click()

    // Both rows visible on the New Product page.
    await expect(card.getByText(/online store/i)).toBeVisible()
    await expect(card.getByText(new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i'))).toBeVisible()

    await page.getByRole('button', { name: /^create product$/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 30_000,
    })

    // Both publications survived the round-trip.
    const persistedCard = publishingCard(page)
    await expect(persistedCard.getByText(/online store/i)).toBeVisible({ timeout: 15_000 })
    await expect(persistedCard.getByText(new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i'))).toBeVisible()
  })

  test('merchant can untick the default channel and ship a no-channel product', async ({
    page,
  }) => {
    const creds = await login(page)
    const productName = `E2E Publish Untick Default ${Date.now()}`

    await createMinimalProduct(page, creds.store_id, productName)
    const card = publishingCard(page)
    await expect(card.getByText(/online store/i)).toBeVisible({ timeout: 15_000 })

    // Untick the default channel — the merchant deliberately wants the
    // product invisible on the storefront on first save.
    await card.getByRole('button', { name: /^manage$/i }).click()
    const sheet = page.getByRole('dialog')
    await sheet.getByRole('button', { name: /online store/i }).click()
    await sheet.getByRole('button', { name: /^done$/i }).click()

    await expect(card.getByText(/online store/i)).not.toBeVisible()
    await expect(card.getByText(/not listed on any sales channel/i)).toBeVisible()

    await page.getByRole('button', { name: /^create product$/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 30_000,
    })

    // No publication persisted — the untick decision held.
    await expect(publishingCard(page).getByText(/not listed on any sales channel/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  test('merchant can schedule a publication window via the inline editor', async ({ page }) => {
    const creds = await login(page)
    const productName = `E2E Publish Schedule ${Date.now()}`

    // Save the product first — the schedule editor opens the same way pre-
    // and post-save, but the edit page is where merchants typically set a
    // publication window. Flip status to Active so scheduleStatus actually
    // computes from published_at (it short-circuits to "not_available"
    // while the product is Draft).
    await createMinimalProduct(page, creds.store_id, productName)
    await page.getByRole('button', { name: /^create product$/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 30_000,
    })

    // Switch status to Active.
    const statusCard = page
      .locator('[data-slot="card"]')
      .filter({ has: page.locator('[data-slot="card-title"]', { hasText: /^Status$/ }) })
    await statusCard.getByRole('combobox').click()
    await page.getByRole('option', { name: /^active$/i }).click()

    const edit = publishingCard(page)
    await expect(edit.getByText(/online store/i)).toBeVisible({ timeout: 15_000 })
    // With Active status + no published_at, the default channel row is "live".
    await expect(edit.getByText(/^live$/i)).toBeVisible({ timeout: 5_000 })

    // Open the inline editor by clicking the channel row.
    await edit.getByRole('button', { name: /online store/i }).click()

    // The editor renders two StoreDatePicker triggers — the unset state's
    // trigger label is the placeholder copy. "Live immediately" is the
    // empty-label for `published_at`. Clicking it opens the calendar
    // dialog; picking any future day flips schedule status live → scheduled.
    await edit.getByRole('button', { name: /live immediately/i }).click()
    const calendarDialog = page.getByRole('dialog')
    await expect(calendarDialog).toBeVisible({ timeout: 5_000 })

    // Pick a future day — `getByRole('gridcell')` matches calendar day
    // cells; filter out disabled (past) ones. Picking the last enabled
    // cell in the visible month maximizes the chance of landing in the
    // future even when the current month has few remaining days.
    const enabledDays = calendarDialog
      .getByRole('gridcell')
      .filter({ hasNot: page.locator('[aria-disabled="true"]') })
    await enabledDays.last().click()

    // Close the inline editor.
    await edit.getByRole('button', { name: /^done$/i }).click()

    // The chosen date is in the future → status flips to "scheduled".
    await expect(edit.getByText(/^scheduled$/i)).toBeVisible({ timeout: 5_000 })

    // Persist and reload — the schedule survives.
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 30_000,
    })

    await page.reload()
    await expect(publishingCard(page).getByText(/^scheduled$/i)).toBeVisible({
      timeout: 15_000,
    })
  })
})
