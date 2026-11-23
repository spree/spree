import { expect, type Page, test } from '@playwright/test'
import { deleteSeededRecords, login, searchList, seedRecord } from './helpers'

const rows = (page: Page, text: string) => page.getByRole('row').filter({ hasText: text })

test.afterEach(({ page }) => deleteSeededRecords(page))

test.describe('list sorting', () => {
  test('sorts a list by clicking its column headers', async ({ page }) => {
    const session = await login(page)
    const id = `${Date.now()}`
    const first = `https://admin-${id}.example.com`
    const last = `https://shop-${id}.example.com`
    for (const origin of [first, last]) {
      await seedRecord(page, session, '/allowed_origins', { origin })
    }

    await page.goto(`/${session.store_id}/settings/allowed-origins`)
    await searchList(page, /search by origin/i, id)
    await expect(rows(page, id)).toHaveCount(2, { timeout: 15_000 })

    const originHeader = page.getByRole('columnheader', { name: /^origin$/i })
    const createdHeader = page.getByRole('columnheader', { name: /^created at$/i })

    // The list opens sorted by origin, A to Z.
    await expect(originHeader).toHaveAttribute('aria-sort', 'ascending')
    await expect(rows(page, id).first()).toContainText(first)

    // Clicking the sorted column flips it.
    await page.getByRole('button', { name: /^sort by origin$/i }).click()
    await expect(originHeader).toHaveAttribute('aria-sort', 'descending')
    await expect(rows(page, id).first()).toContainText(last)

    // Another column sorts by itself, ascending, and the first one lets go.
    await page.getByRole('button', { name: /^sort by created at$/i }).click()
    await expect(createdHeader).toHaveAttribute('aria-sort', 'ascending')
    await expect(originHeader).not.toHaveAttribute('aria-sort', /.*/)
    await expect(rows(page, id).first()).toContainText(first)
  })
})
