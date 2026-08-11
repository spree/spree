import { expect, type Page, test } from '@playwright/test'
import { login } from './helpers'

const ROLES_PATH = (storeId: string) => `/${storeId}/settings/roles`

async function gotoRoles(page: Page, storeId: string) {
  await page.goto(ROLES_PATH(storeId))
  await expect(page.getByRole('button', { name: /add role/i })).toBeVisible({ timeout: 15_000 })
}

function sheet(page: Page) {
  return page.getByRole('dialog')
}

test.describe('roles', () => {
  test('lists roles with the protected admin role', async ({ page }) => {
    const creds = await login(page)
    await gotoRoles(page, creds.store_id)

    await expect(page.getByRole('cell', { name: /admin/i }).first()).toBeVisible()
    await expect(page.getByText(/full access/i).first()).toBeVisible()
  })

  test('creates a role from the permission grid and edits it', async ({ page }) => {
    const creds = await login(page)
    await gotoRoles(page, creds.store_id)

    const name = `e2e-support-${Date.now()}`

    await page.getByRole('button', { name: /add role/i }).click()
    await expect(sheet(page)).toBeVisible()

    await page.locator('#role-name').fill(name)
    await page.locator('#role-description').fill('Read-only support role')
    await sheet(page)
      .getByRole('checkbox', { name: /view orders/i })
      .check()
    await sheet(page)
      .getByRole('checkbox', { name: /view customers/i })
      .check()
    await sheet(page)
      .getByRole('button', { name: /^save$/i })
      .click()

    // Sheet closes; the new role and its human-readable badges show in the list.
    await expect(sheet(page)).toHaveCount(0, { timeout: 15_000 })
    await expect(page.getByRole('cell', { name: new RegExp(name, 'i') })).toBeVisible()
    await expect(page.getByText('View Orders').first()).toBeVisible()

    // Round-trip: reopen the row, grant manage on orders, save.
    await page.getByRole('cell', { name: new RegExp(name, 'i') }).click()
    await expect(sheet(page).locator('#role-name')).toHaveValue(name, { timeout: 15_000 })

    await sheet(page)
      .getByRole('checkbox', { name: /manage orders/i })
      .check()
    await sheet(page)
      .getByRole('button', { name: /^save$/i })
      .click()

    await expect(page.getByText(/role updated/i)).toBeVisible({ timeout: 15_000 })
    await expect(sheet(page)).toHaveCount(0)
  })

  test('starts from a template', async ({ page }) => {
    const creds = await login(page)
    await gotoRoles(page, creds.store_id)

    await page.getByRole('button', { name: /add role/i }).click()
    await sheet(page)
      .getByRole('button', { name: /^support$/i })
      .click()

    // The template pre-fills the grid; "view orders" is part of Support.
    await expect(sheet(page).getByRole('checkbox', { name: /view orders/i })).toBeChecked()

    const name = `e2e-template-${Date.now()}`
    await page.locator('#role-name').fill(name)
    await sheet(page)
      .getByRole('button', { name: /^save$/i })
      .click()

    await expect(page.getByRole('cell', { name: new RegExp(name, 'i') })).toBeVisible({
      timeout: 15_000,
    })
  })

  test('the admin role opens read-only', async ({ page }) => {
    const creds = await login(page)
    await gotoRoles(page, creds.store_id)

    await page
      .getByRole('cell', { name: /^admin/i })
      .first()
      .click()
    await expect(
      sheet(page)
        .getByText(/protected/i)
        .first(),
    ).toBeVisible({ timeout: 15_000 })
    await expect(sheet(page).getByRole('button', { name: /^save$/i })).toHaveCount(0)
    await expect(sheet(page).locator('#role-name')).toBeDisabled()
  })

  test('duplicates a role', async ({ page }) => {
    const creds = await login(page)
    await gotoRoles(page, creds.store_id)

    const name = `e2e-dup-src-${Date.now()}`
    await page.getByRole('button', { name: /add role/i }).click()
    await page.locator('#role-name').fill(name)
    await sheet(page)
      .getByRole('checkbox', { name: /view orders/i })
      .check()
    await sheet(page)
      .getByRole('button', { name: /^save$/i })
      .click()
    await expect(page.getByRole('cell', { name: new RegExp(name, 'i') })).toBeVisible({
      timeout: 15_000,
    })

    await page
      .getByRole('row', { name: new RegExp(name, 'i') })
      .getByRole('button')
      .last()
      .click()
    await page.getByRole('menuitem', { name: /duplicate/i }).click()

    // The copy carries the source's permissions and a distinct name.
    await expect(sheet(page).getByRole('checkbox', { name: /view orders/i })).toBeChecked({
      timeout: 15_000,
    })
    await expect(sheet(page).locator('#role-name')).toHaveValue(new RegExp(name, 'i'))
  })

  test('blocks deleting a role while staff hold it, allows after unassign', async ({ page }) => {
    const creds = await login(page)
    const name = `e2e-held-${Date.now()}`

    // Create the role.
    await gotoRoles(page, creds.store_id)
    await page.getByRole('button', { name: /add role/i }).click()
    await page.locator('#role-name').fill(name)
    await sheet(page)
      .getByRole('checkbox', { name: /view orders/i })
      .check()
    await sheet(page)
      .getByRole('button', { name: /^save$/i })
      .click()
    await expect(page.getByRole('cell', { name: new RegExp(name, 'i') })).toBeVisible({
      timeout: 15_000,
    })

    // Assign it to the seed admin from the staff page.
    await page.goto(`/${creds.store_id}/settings/staff`)
    await page
      .getByRole('row', { name: /spree@example\.com/i })
      .getByRole('button')
      .last()
      .click()
    await page.getByRole('menuitem', { name: /edit/i }).click()
    await page.getByRole('checkbox', { name: new RegExp(name, 'i') }).check()
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(new RegExp(name, 'i')).first()).toBeVisible({ timeout: 15_000 })

    // Delete is disabled while the role is held.
    await gotoRoles(page, creds.store_id)
    const row = page.getByRole('row', { name: new RegExp(name, 'i') })
    await row.getByRole('button').last().click()
    await expect(page.getByRole('menuitem', { name: /delete/i })).toBeDisabled()
    await page.keyboard.press('Escape')

    // Unassign, then delete goes through.
    await page.goto(`/${creds.store_id}/settings/staff`)
    await page
      .getByRole('row', { name: /spree@example\.com/i })
      .getByRole('button')
      .last()
      .click()
    await page.getByRole('menuitem', { name: /edit/i }).click()
    await page.getByRole('checkbox', { name: new RegExp(name, 'i') }).uncheck()
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(
      page.getByRole('row', { name: /spree@example\.com/i }).getByText(new RegExp(name, 'i')),
    ).toHaveCount(0, { timeout: 15_000 })

    await gotoRoles(page, creds.store_id)
    await row.getByRole('button').last().click()
    await page.getByRole('menuitem', { name: /delete/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()
    await expect(page.getByRole('cell', { name: new RegExp(name, 'i') })).toHaveCount(0, {
      timeout: 15_000,
    })
  })
})
