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
    await expect(page.getByText(/1 selected/)).toBeVisible()

    // The count sits beside the bar's checkbox, so React updates its text node
    // in place: the page must show the new count, not the stale translation.
    await translatePage(page)
    await tick(1)
    await expect(page.getByText(/2 selected/)).toBeVisible()

    // Clearing the selection removes the translated bar and restores the title.
    await translatePage(page)
    await page.getByRole('checkbox', { name: /select all media/i }).click()
    await expect(page.getByText(/^\W*\d+ selected\W*$/)).toHaveCount(0)
    await expect(tiles).toHaveCount(2)

    expect(errors).toEqual([])
    await expect(page.getByText(/something went wrong/i)).toHaveCount(0)
  })
})
