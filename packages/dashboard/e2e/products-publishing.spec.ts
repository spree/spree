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

    // Land on /new with the form pristine — the Publishing card auto-seeds
    // the store's default channel ("Online Store") so merchants don't have
    // to open Manage before save. The seed runs via setValue with
    // shouldDirty:false, so the form stays pristine: Create button stays
    // disabled until the merchant types something, no Discard button, no
    // beforeunload warning.
    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), /add product/i)
    await page.getByRole('button', { name: /add product/i }).click()
    await expect(page.getByRole('heading', { name: /^new product$/i })).toBeVisible()

    const card = publishingCard(page)
    await expect(card.getByText(/online store/i)).toBeVisible({ timeout: 15_000 })
    await expect(card.getByText(/not listed on any sales channel/i)).not.toBeVisible()

    // Form stays pristine after the seed: Create is disabled, no Discard.
    await expect(page.getByRole('button', { name: /^create product$/i })).toBeDisabled()
    await expect(page.getByRole('button', { name: /^discard$/i })).not.toBeVisible()

    // Now type a name → form is dirty → Create enables and we can submit.
    await page.getByLabel(/^name$/i).fill(productName)
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

    // Scope to the "Publish from" field row (a <Field> renders as a
    // role=group with the FieldLabel text inside) so the picker is
    // unambiguous even if the placeholder copy ("Live immediately") is
    // reworded in en.json — the FieldLabel is the stable anchor.
    const publishedAtField = edit.getByRole('group').filter({ hasText: /^publish from/i })
    await publishedAtField.getByRole('button').first().click()

    const calendarDialog = page.getByRole('dialog')
    await expect(calendarDialog).toBeVisible({ timeout: 5_000 })

    // Advance one month so the day we pick is unambiguously in the future,
    // regardless of when in the current month the spec runs. Without this
    // step, picking `.last()` on a month-end Saturday selects today (the
    // calendar's last cell IS today), and the DatePicker emits midnight
    // today — scheduleStatus uses strict `>` against Date.now() so status
    // falls through to 'live' and the test flakes once or twice a year.
    await calendarDialog.getByRole('button', { name: /next month/i }).click()
    // Pick the 15th of the next month — middle of the row, guaranteed not
    // an outside day, guaranteed in the future, no edge-case math.
    // react-day-picker emits the day as a button inside the gridcell with
    // an aria-label like "Monday, January 15th, 2026"; filter by text 15.
    await calendarDialog.getByRole('gridcell', { name: '15' }).click()

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
