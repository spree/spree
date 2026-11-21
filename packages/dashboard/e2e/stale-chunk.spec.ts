import { expect, type Page, test } from '@playwright/test'
import { login } from './helpers'

// A tab opened before a deploy asks for chunks the new build no longer has.
// The server's SPA fallback answers such a request with index.html, which the
// browser refuses to run as a module.
async function serveChunkAsIndexHtml(page: Page, times: number) {
  let served = 0
  await page.route(/json-preview-drawer[^/]*$/, async (route) => {
    if (served >= times) return route.continue()
    served += 1
    await route.fulfill({
      status: 200,
      contentType: 'text/html',
      body: '<!doctype html><html><body><div id="root"></div></body></html>',
    })
  })
}

function countPageLoads(page: Page) {
  let loads = 0
  page.on('load', () => {
    loads += 1
  })
  return () => loads
}

async function openJsonPreview(page: Page) {
  await page.getByRole('button', { name: 'More actions' }).click()
  await page.getByRole('menuitem', { name: 'View as JSON' }).click()
}

test.describe('a tab left open across a deploy', () => {
  test('reloads onto the current build when a chunk is gone', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings/store`)
    await serveChunkAsIndexHtml(page, 1)

    const reloaded = page.waitForEvent('load')
    await openJsonPreview(page)
    await reloaded

    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/settings/store$`))
    await openJsonPreview(page)
    await expect(page.getByRole('dialog').getByText(`"${creds.store_id}"`).first()).toBeVisible()
  })

  test('shows the error screen instead of reloading again when the chunk is still missing', async ({
    page,
  }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings/store`)
    await serveChunkAsIndexHtml(page, Number.POSITIVE_INFINITY)

    const reloaded = page.waitForEvent('load')
    await openJsonPreview(page)
    await reloaded
    const loads = countPageLoads(page)

    await openJsonPreview(page)

    await expect(page.getByText('Something went wrong')).toBeVisible()
    expect(loads()).toBe(0)
  })
})
