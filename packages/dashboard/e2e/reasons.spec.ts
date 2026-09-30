import { expect, type Page, test } from '@playwright/test'
import { login, openRowMenu } from './helpers'

const REASONS_PATH = (storeId: string) => `/${storeId}/settings/reasons`

/** One of the four reason lists on the page, found by its card title. */
function reasonCard(page: Page, title: RegExp) {
  return page
    .locator('[data-slot="card"]')
    .filter({ has: page.locator('[data-slot="card-title"]', { hasText: title }) })
}

async function addReason(page: Page, cardTitle: RegExp, name: string) {
  await reasonCard(page, cardTitle)
    .getByRole('button', { name: /add reason/i })
    .click()
  await expect(page.getByRole('heading', { name: /^add reason$/i })).toBeVisible()
  await page.locator('#reason-name').fill(name)
  await page
    .getByRole('dialog')
    .getByRole('button', { name: /^create$/i })
    .click()
  await expect(reasonCard(page, cardTitle).getByText(name)).toBeVisible({ timeout: 15_000 })
}

test.describe('reasons', () => {
  test('lists the seeded vocabularies, one card per kind', async ({ page }) => {
    const creds = await login(page)
    await page.goto(REASONS_PATH(creds.store_id))

    await expect(page.getByRole('heading', { name: /returns & reasons/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(reasonCard(page, /^claim reasons$/i).getByText('Wrong item sent')).toBeVisible()
    await expect(
      reasonCard(page, /^return reasons$/i).getByText('Better price available'),
    ).toBeVisible()
    await expect(reasonCard(page, /^refund reasons$/i)).toBeVisible()
    await expect(reasonCard(page, /^order cancellation reasons$/i)).toBeVisible()
  })

  test('adds a reason to the list it was added from only', async ({ page }) => {
    const creds = await login(page)
    await page.goto(REASONS_PATH(creds.store_id))

    const name = `E2E Too small ${Date.now()}`
    await addReason(page, /^return reasons$/i, name)

    await expect(reasonCard(page, /^claim reasons$/i).getByText(name)).toHaveCount(0)
  })

  test('retires a reason so new records stop offering it', async ({ page }) => {
    const creds = await login(page)
    await page.goto(REASONS_PATH(creds.store_id))

    const name = `E2E Retired ${Date.now()}`
    await addReason(page, /^claim reasons$/i, name)

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^edit$/i }).click()
    await expect(page.getByRole('heading', { name: /edit reason/i })).toBeVisible()
    await page.getByRole('switch', { name: /available on new records/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()

    const row = page.getByRole('row').filter({ hasText: name })
    await expect(row.getByText(/^inactive$/i)).toBeVisible({ timeout: 15_000 })
  })

  test('deletes an unused reason after confirming', async ({ page }) => {
    const creds = await login(page)
    await page.goto(REASONS_PATH(creds.store_id))

    const name = `E2E Doomed ${Date.now()}`
    await addReason(page, /^refund reasons$/i, name)

    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete reason\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(page.getByText(name)).toHaveCount(0, { timeout: 15_000 })
  })
})
