import { expect, test } from '@playwright/test'
import { login } from './helpers'

const PROFILE_PATH = (storeId: string) => `/${storeId}/settings/profile`

// Serial: these tests mutate the shared admin user (name + selected_locale).
// The language test resets back to English so later tests/specs see English.
test.describe.configure({ mode: 'serial' })

test.describe('profile', () => {
  test('opens the profile page from the user menu', async ({ page }) => {
    await login(page)

    await page.getByRole('button', { name: /user menu/i }).click()
    await page.getByRole('menuitem', { name: /edit profile/i }).click()

    // The PageHeader title renders as an <h1>; the "Personal Details" CardTitle
    // is a <div>, so assert it as text rather than a heading role.
    await expect(page.getByRole('heading', { name: /^profile$/i })).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText('Personal Details', { exact: true })).toBeVisible()
    // Email is identity-bound and not editable via PATCH /me.
    await expect(page.locator('#profile-email')).toBeDisabled()
  })

  test('edits personal details and persists across reload', async ({ page }) => {
    const creds = await login(page)
    await page.goto(PROFILE_PATH(creds.store_id))
    await expect(page.locator('#profile-first-name')).toBeVisible({ timeout: 15_000 })

    const firstName = `E2E${Date.now()}`

    await page.locator('#profile-first-name').fill(firstName)
    await page.locator('#profile-last-name').fill('Admin')
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(page.getByText(/profile updated/i)).toBeVisible({ timeout: 15_000 })

    await page.reload()
    await expect(page.locator('#profile-first-name')).toHaveValue(firstName, { timeout: 15_000 })
  })

  test('switching the language translates the admin UI', async ({ page }) => {
    const creds = await login(page)
    await page.goto(PROFILE_PATH(creds.store_id))
    await expect(page.locator('#profile-language')).toBeVisible({ timeout: 15_000 })

    // Select Polish (endonym shown in the picker) and save. The save triggers a
    // reload into Polish, so we assert on stable translated chrome that's always
    // present (not the dirty-only Save button).
    await page.locator('#profile-language').click()
    await page.getByRole('option', { name: /polski/i }).click()
    await page.getByRole('button', { name: /^save$/i }).click()

    // Whole UI re-renders in Polish: card title "Personal Details" → "Dane
    // osobowe", and the nav "Products" → "Produkty" (proves table/nav labels
    // resolved at boot, not just live-subscribed components).
    await expect(page.getByText('Dane osobowe', { exact: true })).toBeVisible({ timeout: 15_000 })
    await expect(page.getByRole('link', { name: /produkty/i })).toBeVisible()

    // Survives a reload (locale persisted in localStorage + bundle loaded eagerly
    // at boot).
    await page.reload()
    await expect(page.getByText('Dane osobowe', { exact: true })).toBeVisible({ timeout: 15_000 })

    // Table-driven pages also translate: the Customers list column headers are
    // resolved from `i18n.t()` at module load, so they only render in Polish if
    // the bundle is registered before the table module evaluates (the reload +
    // eager-bundle path). "Total spent" → "Łączne wydatki".
    await page.goto(`/${creds.store_id}/customers`)
    await expect(page.getByRole('columnheader', { name: /łączne wydatki/i })).toBeVisible({
      timeout: 15_000,
    })

    // Back to the profile to reset to English so later tests/specs run against
    // English chrome. The language field label is now "Język".
    await page.goto(PROFILE_PATH(creds.store_id))
    await expect(page.locator('#profile-language')).toBeVisible({ timeout: 15_000 })
    await page.getByLabel(/^język$/i).click()
    await page.getByRole('option', { name: /english/i }).click()
    await page.getByRole('button', { name: /^zapisz$/i }).click()
    await expect(page.getByText('Personal Details', { exact: true })).toBeVisible({
      timeout: 15_000,
    })
  })

  test('switches the language from the top-bar menu and persists it', async ({ page }) => {
    await login(page)

    // Switch to Polish via the top-bar user menu → Language submenu. The
    // submenu trigger's accessible name is "Language <current>", so match by
    // prefix and hover to open the nested content.
    await page.getByRole('button', { name: /user menu/i }).click()
    await page.getByRole('menuitem', { name: /^language/i }).hover()
    await page.getByRole('menuitem', { name: /polski/i }).click()

    // The switch persists to the account (PATCH /me) so it survives the reload
    // instead of being reverted by the auth provider. Nav renders in Polish.
    await expect(page.getByRole('link', { name: /produkty/i })).toBeVisible({ timeout: 15_000 })

    // Reset to English via the top-bar menu (the submenu is now "Język …").
    await page.getByRole('button', { name: /menu użytkownika/i }).click()
    await page.getByRole('menuitem', { name: /^język/i }).hover()
    await page.getByRole('menuitem', { name: /english/i }).click()
    await expect(page.getByRole('link', { name: /^products$/i })).toBeVisible({ timeout: 15_000 })
  })
})
