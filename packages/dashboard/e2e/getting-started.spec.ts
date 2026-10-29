import { expect, test } from '@playwright/test'
import { login } from './helpers'

const GETTING_STARTED_PATH = (storeId: string) => `/${storeId}/getting-started`

test.describe('getting started', () => {
  test('shows setup progress and links each step to where it is done', async ({ page }) => {
    const creds = await login(page)
    await page.goto(GETTING_STARTED_PATH(creds.store_id))

    await expect(page.getByRole('heading', { name: /^getting started$/i })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText(/\d+ of \d+ completed/i)).toBeVisible()

    // The checklist opens on the first unfinished step, and other specs may
    // have finished this one already — so open it only if it is still shut.
    const step = page.getByRole('button', { name: /set up taxes collection/i })
    if ((await step.getAttribute('aria-expanded')) !== 'true') await step.click()
    await page.getByRole('link', { name: /^tax settings$/i }).click()

    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/settings/taxes/rates`))
    await expect(page.getByRole('button', { name: /add tax rate/i })).toBeVisible({
      timeout: 15_000,
    })
  })

  test('sidebar checklist goes straight to each step and minimizes', async ({ page }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/orders`)

    const checklist = page.getByRole('navigation', { name: /^getting started$/i })
    const header = checklist.getByRole('button', { name: /^getting started/i })
    await expect(header).toHaveAttribute('aria-expanded', 'true', { timeout: 15_000 })

    // Steps done in place open their dialog over the current page.
    await checklist.getByRole('button', { name: /set up storefront/i }).click()
    await expect(page.getByRole('heading', { name: /connect your storefront/i })).toBeVisible()
    await page.keyboard.press('Escape')
    await expect(page.getByRole('heading', { name: /connect your storefront/i })).toBeHidden()

    // Minimizing survives a reload, and the header brings the steps back.
    await header.click()
    await expect(checklist.getByRole('listitem')).toHaveCount(0)
    await page.reload()
    await expect(header).toHaveAttribute('aria-expanded', 'false', { timeout: 15_000 })
    await header.click()

    // Other steps link to the page where they are done.
    await checklist.getByRole('link', { name: /set up taxes collection/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/settings/taxes/rates(\\?|$)`))
    await expect(page.getByRole('button', { name: /add tax rate/i })).toBeVisible({
      timeout: 15_000,
    })
  })
  test('sidebar checklist is gone once every step is done', async ({ page }) => {
    // Finishing every step for real would change the shared store other specs
    // read, so the store payload reports them done instead.
    const storeUrl = /\/api\/v3\/admin\/store(\?|$)/
    await page.route(storeUrl, async (route) => {
      if (route.request().method() !== 'GET') return route.fallback()
      const response = await route.fetch()
      const store = await response.json()
      store.setup_tasks = store.setup_tasks.map((task: object) => ({ ...task, done: true }))
      await route.fulfill({ response, json: store })
    })

    const creds = await login(page)
    const storeLoaded = page.waitForResponse(storeUrl)
    await page.goto(`/${creds.store_id}/orders`)
    await storeLoaded

    await expect(page.getByRole('heading', { name: /^orders$/i })).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('link', { name: /^home$/i })).toBeVisible()
    await expect(page.getByRole('navigation', { name: /^getting started$/i })).toHaveCount(0)
  })
})
