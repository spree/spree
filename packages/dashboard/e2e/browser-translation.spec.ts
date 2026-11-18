import { expect, type Page, test } from '@playwright/test'
import { login } from './helpers'
import { createProduct, mediaCard } from './products-helpers'

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
      if (!text.parentElement?.closest('font') && text.nodeValue?.trim()) texts.push(text)
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
  // Sentry SANDBOX-V2-DASHBOARD-C: with the product page translated, ticking a
  // media tile's checkbox crashed the dashboard to its error screen.
  test('the product page keeps working while the browser translates it', async ({ page }) => {
    const errors: string[] = []
    page.on('pageerror', (error) => errors.push(error.message))

    const creds = await login(page)
    await createProduct(page, creds.store_id, `E2E Translated ${Date.now()}`)

    const media = mediaCard(page)
    const attach = media.getByRole('button', { name: 'Probe attach video' })
    await attach.click()
    await attach.click()
    // Found by attributes from here on: a translator rewrites text, not markup.
    const tiles = page.locator('[data-slot="media-thumbnail"]')
    await expect(tiles).toHaveCount(2)
    const card = page.locator('[data-slot="card"]').filter({ has: tiles.first() })
    const selectAll = card.getByRole('checkbox', { name: /select all media/i })
    // The bar's count is the text beside its select-all checkbox.
    const count = selectAll.locator('xpath=..')
    const tick = async (index: number) => {
      await tiles.nth(index).hover()
      await tiles.nth(index).getByRole('checkbox').click()
      // React's error boundary catches the crash, so it shows as the error
      // screen rather than as a page error.
      await expect(page.getByText(/something went wrong/i)).toHaveCount(0)
      expect(errors).toEqual([])
    }

    // Selecting swaps the translated card title for the selection bar.
    await translatePage(page)
    await tick(0)
    await expect(count).toHaveText('1 selected')

    // The count sits beside the bar's checkbox, so React updates its text node
    // in place: the page must show the new count, not the stale translation.
    await translatePage(page)
    await tick(1)
    await expect(count).toHaveText('2 selected')

    // Clearing the selection removes the translated bar and restores the title.
    await translatePage(page)
    await selectAll.click()
    await expect(selectAll).toHaveCount(0)
    // The selection bar keeps a screen-reader-only title, which still counts as
    // visible to Playwright, so check it is the shown one.
    const title = card.locator('[data-slot="card-title"]')
    await expect(title).toHaveText('Media')
    await expect(title).toBeVisible()
    await expect(title).not.toHaveClass(/(?:^|\s)sr-only(?:\s|$)/)
    await expect(tiles).toHaveCount(2)

    expect(errors).toEqual([])
    await expect(page.getByText(/something went wrong/i)).toHaveCount(0)
  })

  test('text React changes in the same task as the translation still shows', async ({ page }) => {
    await login(page)

    // The translator swaps the text and the new text lands before the
    // document's MutationObserver has delivered the swap.
    const shown = await page.evaluate(() => {
      const holder = document.createElement('div')
      const text = document.createTextNode('1 selected')
      holder.appendChild(text)
      document.body.appendChild(holder)
      const font = document.createElement('font')
      font.textContent = '«1 selected»'
      holder.insertBefore(font, text)
      holder.removeChild(text)
      text.nodeValue = '2 selected'
      const result = holder.textContent
      holder.remove()
      return result
    })

    expect(shown).toBe('2 selected')
  })
})
