import { expect, type Page, test } from '@playwright/test'
import { createTaxRate, login } from './helpers'

const STORE_URL = /\/api\/v3\/admin\/store(\?|$)/

/**
 * Reports setup progress on the store payload instead of finishing steps for
 * real, which would change the shared store other specs read. `done` answers
 * per task name, read at the time of each request.
 */
async function fakeSetupTasks(page: Page, done: (taskName: string) => boolean) {
  await page.route(STORE_URL, async (route) => {
    if (route.request().method() !== 'GET') return route.fallback()
    const response = await route.fetch()
    const store = await response.json()
    store.setup_tasks = store.setup_tasks.map((task: { name: string }) => ({
      ...task,
      done: done(task.name),
    }))
    await route.fulfill({ response, json: store })
  })
}

/** Saves the address sheet, filling only the required fields left blank. */
async function saveStoreAddress(page: Page) {
  const sheet = page.getByRole('dialog', { name: /add your shipping address/i })
  await expect(sheet).toBeVisible()
  const fillIfBlank = async (id: string, value: string) => {
    const field = sheet.locator(`#${id}`)
    if (!(await field.inputValue())) await field.fill(value)
  }
  await fillIfBlank('addr-co', 'E2E Store')
  await fillIfBlank('addr-a1', '1 Main St')
  await fillIfBlank('addr-city', 'Anytown')
  await fillIfBlank('addr-zip', '12345')
  // Other specs create locations of their own, so the one this edits may have
  // no state yet. US, the fixture store's country, requires one.
  const state = sheet.locator('#addr-state')
  if (/select a state/i.test(await state.innerText())) {
    await state.click()
    await page.getByPlaceholder(/^search states/i).fill('California')
    await page.getByRole('option', { name: 'California' }).first().click()
  }
  // Another spec may have filled the address in already, and Save waits for a
  // change, so this always makes one.
  await sheet.locator('#addr-a2').fill(`Suite ${Date.now()}`)
  await sheet.getByRole('button', { name: /^save$/i }).click()
}

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

  test('sidebar checklist opens its steps in a popover and goes straight to each', async ({
    page,
  }) => {
    const creds = await login(page)
    await page.goto(`/${creds.store_id}/orders`)

    // One row in the sidebar: the steps never push the navigation down.
    const checklist = page.getByRole('navigation', { name: /^getting started$/i })
    const trigger = checklist.getByRole('button', { name: /^getting started \d+\/\d+$/i })
    await expect(trigger).toBeVisible({ timeout: 15_000 })
    await expect(checklist.getByRole('listitem')).toHaveCount(0)

    // Steps done in place open their dialog over the current page.
    await trigger.click()
    const steps = page.getByRole('dialog', { name: /^getting started$/i })
    await steps.getByRole('button', { name: /set up storefront/i }).click()
    await expect(page.getByRole('heading', { name: /connect your storefront/i })).toBeVisible()
    await page.keyboard.press('Escape')
    await expect(page.getByRole('heading', { name: /connect your storefront/i })).toBeHidden()

    // Other steps link to the page where they are done, closing the popover.
    await trigger.click()
    await steps.getByRole('link', { name: /set up taxes collection/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/settings/taxes/rates(\\?|$)`))
    await expect(steps).toBeHidden()
    await expect(page.getByRole('button', { name: /add tax rate/i })).toBeVisible({
      timeout: 15_000,
    })
  })

  test('sidebar checklist is gone once every step is done', async ({ page }) => {
    await fakeSetupTasks(page, () => true)

    const creds = await login(page)
    const storeLoaded = page.waitForResponse(STORE_URL)
    await page.goto(`/${creds.store_id}/orders`)
    await storeLoaded

    await expect(page.getByRole('heading', { name: /^orders$/i })).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('link', { name: /^home$/i })).toBeVisible()
    await expect(page.getByRole('navigation', { name: /^getting started$/i })).toHaveCount(0)
    // A store that loads already set up is not congratulated again.
    await expect(page.getByText(/^your store is set up$/i)).toHaveCount(0)
  })

  test('saving the address from the sidebar checklist confirms it', async ({ page }) => {
    await fakeSetupTasks(page, (name) => name !== 'setup_address')

    const creds = await login(page)
    await page.goto(`/${creds.store_id}/orders`)

    const checklist = page.getByRole('navigation', { name: /^getting started$/i })
    await checklist.getByRole('button', { name: /^getting started \d+\/\d+$/i }).click({
      timeout: 15_000,
    })
    await page
      .getByRole('dialog', { name: /^getting started$/i })
      .getByRole('button', { name: /add your shipping address/i })
      .click()

    await saveStoreAddress(page)

    await expect(page.getByText(/^shipping address saved$/i)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('dialog', { name: /add your shipping address/i })).toBeHidden()
  })

  test('finishing the last step in the sidebar checklist says the store is set up', async ({
    page,
  }) => {
    let addressSaved = false
    await fakeSetupTasks(page, (name) => name !== 'setup_address' || addressSaved)
    page.on('request', (request) => {
      if (request.method() === 'PATCH' && /\/stock_locations\//.test(request.url())) {
        addressSaved = true
      }
    })

    const creds = await login(page)
    await page.goto(`/${creds.store_id}/orders`)

    const checklist = page.getByRole('navigation', { name: /^getting started$/i })
    const trigger = checklist.getByRole('button', { name: /^getting started \d+\/\d+$/i })
    await expect(trigger).toBeVisible({ timeout: 15_000 })
    await trigger.click()
    await page
      .getByRole('dialog', { name: /^getting started$/i })
      .getByRole('button', { name: /add your shipping address/i })
      .click()

    await saveStoreAddress(page)

    await expect(page.getByText(/^your store is set up$/i)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(/every getting started step is done/i)).toBeVisible()
    // The checklist has nothing left to show, so it goes.
    await expect(checklist).toHaveCount(0)
  })

  test('creating a tax rate finishes its step in the sidebar checklist', async ({ page }) => {
    let rateCreated = false
    await fakeSetupTasks(page, (name) => name !== 'setup_taxes_collection' || rateCreated)
    page.on('request', (request) => {
      if (request.method() === 'POST' && /\/tax_rates(\?|$)/.test(request.url())) {
        rateCreated = true
      }
    })

    const creds = await login(page)
    await page.goto(`/${creds.store_id}/orders`)

    const checklist = page.getByRole('navigation', { name: /^getting started$/i })
    await checklist.getByRole('button', { name: /^getting started \d+\/\d+$/i }).click({
      timeout: 15_000,
    })
    await page
      .getByRole('dialog', { name: /^getting started$/i })
      .getByRole('link', { name: /set up taxes collection/i })
      .click()
    await expect(page.getByRole('button', { name: /add tax rate/i })).toBeVisible({
      timeout: 15_000,
    })

    await createTaxRate(page, { name: `E2E Setup Rate ${Date.now()}`, ratePercent: '5' })

    // The checklist re-reads the store after the save, without a reload.
    await expect(page.getByText(/^your store is set up$/i)).toBeVisible({ timeout: 15_000 })
    await expect(checklist).toHaveCount(0)
  })
})
