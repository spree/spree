import { expect, type Page, test } from '@playwright/test'
import { deleteSeededRecords, gotoIndex, login, searchList, seedRecord } from './helpers'

const CTA = /add product/i
const SEARCH = /^search…$/i

/**
 * Does to the page what Google Translate does: every text node in the app is
 * swapped for `<font><font>translation</font></font>`, and the root element is
 * marked as translated. React keeps pointing at the original, now detached,
 * text nodes.
 */
async function translatePage(page: Page) {
  await page.evaluate(() => {
    document.documentElement.classList.add('translated-ltr')
    const root = document.getElementById('root') as HTMLElement
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
    const texts: Text[] = []
    while (walker.nextNode()) {
      const text = walker.currentNode as Text
      const inFont = text.parentElement?.closest('font')
      if (!inFont && text.nodeValue?.trim()) texts.push(text)
    }
    for (const text of texts) {
      const outer = document.createElement('font')
      const inner = document.createElement('font')
      inner.textContent = `«${text.nodeValue}»`
      outer.appendChild(inner)
      text.parentNode?.insertBefore(outer, text)
      text.parentNode?.removeChild(text)
    }
  })
}

test.describe('browser translation', () => {
  test.afterEach(({ page }) => deleteSeededRecords(page))

  test('the products list keeps working while the browser translates it', async ({ page }) => {
    const errors: string[] = []
    page.on('pageerror', (error) => errors.push(error.message))

    const session = await login(page)
    const stamp = `E2E Translated ${Date.now()}`
    for (const suffix of ['A', 'B']) {
      await seedRecord(page, session, '/products', {
        name: `${stamp} ${suffix}`,
        status: 'active',
        prices: [{ amount: '10.00', currency: 'USD' }],
      })
    }

    await gotoIndex(page, `/${session.store_id}/products`, CTA)
    await searchList(page, SEARCH, stamp)
    const rows = page.locator('tr').filter({ hasText: stamp })
    await expect(rows).toHaveCount(2)

    await translatePage(page)

    const checkbox = (suffix: string) =>
      page
        .locator('tr')
        .filter({ hasText: `${stamp} ${suffix}` })
        .getByRole('checkbox', { name: /select row/i })

    // Selecting swaps the translated column headings for the bulk-action bar.
    await checkbox('A').check()
    await expect(page.getByText(/^1 selected$/)).toBeVisible()

    // React now updates a count the translator has replaced: the page must
    // show the new count, not the stale translation of the old one.
    await translatePage(page)
    await checkbox('B').check()
    await expect(page.getByText(/2 selected/)).toBeVisible()

    // Clearing the selection removes translated text and brings the headings back.
    await checkbox('A').uncheck()
    await checkbox('B').uncheck()
    await expect(page.getByText(/^\W*\d+ selected\W*$/)).toHaveCount(0)
    await expect(rows).toHaveCount(2)

    expect(errors).toEqual([])
    await expect(page.getByText(/something went wrong/i)).toHaveCount(0)
  })
})
