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

  test('does not reload again, and keeps the page, when the chunk is still missing', async ({
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

    // Only the drawer is lost, and the user is told: the page stays, with no
    // error screen in its place.
    await expect(page.getByText("Couldn't load this")).toBeVisible()
    await expect(
      page.getByText('The dashboard was updated. Reload the page to continue.'),
    ).toBeVisible()
    await expect(page.locator('#store-name')).toBeVisible()
    await expect(page.getByRole('dialog')).toHaveCount(0)
    await expect(page.getByText('Something went wrong')).toHaveCount(0)
    expect(loads()).toBe(0)

    // The toast offers the reload the tab will not do again by itself.
    const reloadedByUser = page.waitForEvent('load')
    await page.getByRole('button', { name: 'Reload page' }).click()
    await reloadedByUser
  })

  test('keeps the page and its unsaved edits when the reload is cancelled, and reloads again after a minute', async ({
    page,
  }) => {
    await page.clock.install()
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/settings/store`)
    const storeName = page.locator('#store-name')
    await expect(storeName).toBeVisible({ timeout: 15_000 })
    const edited = `Unsaved ${Date.now()}`
    await storeName.fill(edited)
    await serveChunkAsIndexHtml(page, Number.POSITIVE_INFINITY)
    const loads = countPageLoads(page)

    // The unsaved-changes guard asks before the reload; stay on the page.
    const prompt = page.waitForEvent('dialog')
    page.once('dialog', (dialog) => dialog.dismiss())
    await openJsonPreview(page)
    expect((await prompt).type()).toBe('beforeunload')

    await expect(storeName).toHaveValue(edited)
    expect(loads()).toBe(0)
    // The page stayed, so the user is told the drawer could not load.
    await expect(page.getByText("Couldn't load this")).toBeVisible()

    // Within the minute it does not ask again.
    let promptedAgain = false
    page.on('dialog', (dialog) => {
      promptedAgain = true
      void dialog.dismiss()
    })
    await openJsonPreview(page)
    await expect(storeName).toHaveValue(edited)
    expect(promptedAgain).toBe(false)

    // A minute later, recovery tries again.
    await page.clock.fastForward(61_000)
    page.removeAllListeners('dialog')
    const promptAfterCooldown = page.waitForEvent('dialog')
    page.once('dialog', (dialog) => dialog.accept())
    const reloaded = page.waitForEvent('load')
    await openJsonPreview(page)
    expect((await promptAfterCooldown).type()).toBe('beforeunload')
    await reloaded
    expect(loads()).toBe(1)
  })
})
