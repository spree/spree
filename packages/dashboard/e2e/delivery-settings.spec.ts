import { expect, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'

const DELIVERY_PROFILES_PATH = (storeId: string) => `/${storeId}/settings/delivery-profiles`
const PROFILE_CTA = /add profile/i

test.describe('delivery profiles', () => {
  test('lists delivery profiles including the store default', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, DELIVERY_PROFILES_PATH(creds.store_id), PROFILE_CTA)

    // Every store is seeded with a default profile, so the list is never empty.
    await expect(page.getByText(/^default$/i).first()).toBeVisible({ timeout: 15_000 })
  })

  test('creates a profile, a zone inside it, and a method inside the zone', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, DELIVERY_PROFILES_PATH(creds.store_id), PROFILE_CTA)

    const stamp = Date.now()
    const profileName = `E2E Profile ${stamp}`
    const zoneName = `E2E Zone ${stamp}`
    const methodName = `E2E Method ${stamp}`

    // ---- profile -----------------------------------------------------------
    await page.getByRole('button', { name: PROFILE_CTA }).click()
    await expect(page.getByRole('heading', { name: /new delivery profile/i })).toBeVisible()

    await page.locator('#name').fill(profileName)
    await page.getByRole('button', { name: /create profile/i }).click()

    // Creating a profile lands on its detail page, where zones and methods live.
    await expect(page.getByRole('heading', { name: profileName })).toBeVisible({ timeout: 15_000 })

    // ---- zone --------------------------------------------------------------
    await page.getByRole('button', { name: /add delivery zone/i }).click()
    await expect(page.getByRole('heading', { name: /new delivery zone/i })).toBeVisible()

    await page.locator('#name').fill(zoneName)

    // Coverage is picked from the store's market countries: search narrows the
    // list, then the country's own checkbox selects the whole country.
    const zoneSheet = page.getByRole('dialog')
    await zoneSheet.getByPlaceholder(/search countries and regions/i).fill('United States')
    await zoneSheet.getByRole('checkbox', { name: /^united states$/i }).check()

    await page.getByRole('button', { name: /create delivery zone/i }).click()

    await expect(page.getByText(zoneName)).toBeVisible({ timeout: 15_000 })

    // ---- method ------------------------------------------------------------
    await page
      .getByRole('button', { name: /add method/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /new delivery method/i })).toBeVisible({
      timeout: 15_000,
    })

    // The method form is a sheet over the profile, so the profile stays put
    // behind it rather than being navigated away from. The modal sheet marks
    // the page behind as aria-hidden, which removes it from role queries —
    // assert through a CSS locator instead.
    await expect(page.locator('h1', { hasText: profileName })).toBeVisible()

    // Started from inside a zone, so the zone is already answered — asking
    // again could silently file the method under a different one.
    await expect(page.getByRole('dialog').getByText(/^zone$/i)).toHaveCount(0)

    await page.getByRole('dialog').locator('#name').fill(methodName)
    await page.getByRole('button', { name: /create delivery method/i }).click()

    // Saving closes the sheet and the method appears under its zone.
    await expect(page.getByRole('heading', { name: /new delivery method/i })).toHaveCount(0, {
      timeout: 15_000,
    })
    await expect(page.getByText(methodName)).toBeVisible({ timeout: 15_000 })
  })

  // Opening a method is a search-param change, so the sheet must survive a
  // reload and a direct link — that is what keeps bookmarked methods working.
  test('opens the method sheet straight from a URL', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, DELIVERY_PROFILES_PATH(creds.store_id), PROFILE_CTA)

    const profileName = `E2E Deeplink Profile ${Date.now()}`

    await page.getByRole('button', { name: PROFILE_CTA }).click()
    await expect(page.getByRole('heading', { name: /new delivery profile/i })).toBeVisible()

    await page.locator('#name').fill(profileName)
    await page.getByRole('button', { name: /create profile/i }).click()

    await expect(page.getByRole('heading', { name: profileName })).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /offer pickup/i }).click()
    await expect(page.getByRole('heading', { name: /new delivery method/i })).toBeVisible({
      timeout: 15_000,
    })

    // Reloading the URL the sheet put in the address bar reopens it, over a
    // profile page that rendered underneath.
    await page.reload()
    await expect(page.getByRole('heading', { name: /new delivery method/i })).toBeVisible({
      timeout: 15_000,
    })
    // Behind a modal sheet the page is aria-hidden, so role queries can't see
    // the heading — a CSS locator proves it stayed rendered.
    await expect(page.locator('h1', { hasText: profileName })).toBeVisible()

    // Cancelling leaves the profile behind, with no sheet left open.
    await page.getByRole('button', { name: /^cancel$/i }).click()
    await expect(page.getByRole('heading', { name: /new delivery method/i })).toHaveCount(0)
    await expect(page.getByRole('heading', { name: profileName })).toBeVisible()
  })

  // Pickup is a separate card because it has no destination: the merchant
  // reaches the method form through it, and that form must drop the zone.
  test('offers pickup from a fresh profile, on a form with no zone', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, DELIVERY_PROFILES_PATH(creds.store_id), PROFILE_CTA)

    const profileName = `E2E Pickup Profile ${Date.now()}`

    await page.getByRole('button', { name: PROFILE_CTA }).click()
    await expect(page.getByRole('heading', { name: /new delivery profile/i })).toBeVisible()

    await page.locator('#name').fill(profileName)
    await page.getByRole('button', { name: /create profile/i }).click()

    await expect(page.getByRole('heading', { name: profileName })).toBeVisible({ timeout: 15_000 })

    // A brand-new profile collects nowhere yet, so the pickup card offers the
    // way in rather than listing methods.
    await expect(page.getByText(/customers cannot collect orders/i)).toBeVisible({
      timeout: 15_000,
    })

    await page.getByRole('button', { name: /offer pickup/i }).click()
    await expect(page.getByRole('heading', { name: /new delivery method/i })).toBeVisible({
      timeout: 15_000,
    })

    // Pickup preselected: collection counters replace the zone entirely.
    const sheet = page.getByRole('dialog')
    await expect(sheet.getByText(/collection locations/i)).toBeVisible({ timeout: 15_000 })
    await expect(sheet.getByText(/^zone$/i)).toHaveCount(0)
  })

  // The origin-group layer stays invisible until a profile is split, so this
  // covers both directions: splitting reveals the per-group sections, and
  // deleting the second group returns the page to its flat rendering.
  test('splits shipping origins into a second group, then collapses back', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, DELIVERY_PROFILES_PATH(creds.store_id), PROFILE_CTA)

    const profileName = `E2E Origins Profile ${Date.now()}`
    const groupName = 'EU warehouse'

    await page.getByRole('button', { name: PROFILE_CTA }).click()
    await expect(page.getByRole('heading', { name: /new delivery profile/i })).toBeVisible()

    await page.locator('#name').fill(profileName)
    await page.getByRole('button', { name: /create profile/i }).click()

    await expect(page.getByRole('heading', { name: profileName })).toBeVisible({ timeout: 15_000 })

    // A fresh profile has one nameless group, so no group header renders yet
    // ("Ships from" itself also appears in the Locations card — assert on the
    // group name, which cannot exist before the split).
    await expect(page.getByText(groupName)).toHaveCount(0)

    await page.getByRole('button', { name: /split shipping origins/i }).click()
    await expect(page.getByRole('heading', { name: /split shipping origins/i })).toBeVisible()

    await page.locator('#origin-group-name').fill(groupName)
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^split shipping origins$/i })
      .click()

    // Two groups now: the nameless default renders as "All locations", the new
    // one under its own name.
    await expect(page.getByText(groupName)).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(/ships from all locations/i)).toHaveCount(2)

    // Deleting the empty second group takes the profile back to one group,
    // and the group framing disappears with it.
    // The last actions menu on the page belongs to the group just created,
    // which renders below the default one.
    await page
      .getByRole('button', { name: /open actions/i })
      .last()
      .click()
    await page.getByRole('menuitem', { name: /delete/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(page.getByText(groupName)).toHaveCount(0, { timeout: 15_000 })
  })
})
