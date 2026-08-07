import { expect, type Page, test } from '@playwright/test'
import { login } from './helpers'

const ROLES_PATH = (storeId: string) => `/${storeId}/settings/roles`

async function gotoRoles(page: Page, storeId: string) {
  await page.goto(ROLES_PATH(storeId))
  await expect(page.getByRole('button', { name: /add role/i })).toBeVisible({ timeout: 15_000 })
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
    await expect(page.getByRole('heading', { name: /new role/i })).toBeVisible()

    await page.locator('#role-name').fill(name)
    await page.locator('#role-description').fill('Read-only support role')
    await page.getByRole('checkbox', { name: /view orders/i }).check()
    await page.getByRole('checkbox', { name: /view customers/i }).check()
    await page.getByRole('button', { name: /^save$/i }).click()

    // Back on the list with the new role and its permission badges.
    await expect(page.getByRole('cell', { name: new RegExp(name, 'i') })).toBeVisible({
      timeout: 15_000,
    })
    await expect(page.getByText('read_orders')).toBeVisible()

    // Round-trip: open the editor, grant manage on orders, save.
    await page.getByRole('cell', { name: new RegExp(name, 'i') }).click()
    await expect(page.getByRole('heading', { name: new RegExp(name, 'i') })).toBeVisible()

    const manageOrders = page.getByRole('checkbox', { name: /manage orders/i })
    await manageOrders.check()
    await page.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/role updated/i)).toBeVisible({ timeout: 15_000 })
  })

  test('starts from a template on the create page', async ({ page }) => {
    const creds = await login(page)
    await gotoRoles(page, creds.store_id)

    await page.getByRole('button', { name: /add role/i }).click()
    await page.getByRole('button', { name: /^support$/i }).click()

    // The template pre-fills the grid; "view orders" is part of Support.
    await expect(page.getByRole('checkbox', { name: /view orders/i })).toBeChecked()

    const name = `e2e-template-${Date.now()}`
    await page.locator('#role-name').fill(name)
    await page.getByRole('button', { name: /^save$/i }).click()

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
    await expect(page.getByText(/protected/i).first()).toBeVisible()
    await expect(page.getByRole('button', { name: /^save$/i })).toHaveCount(0)
    await expect(page.locator('#role-name')).toBeDisabled()
  })

  test('blocks deleting a role while staff hold it, allows after unassign', async ({ page }) => {
    const creds = await login(page)
    const name = `e2e-held-${Date.now()}`

    // Create the role.
    await gotoRoles(page, creds.store_id)
    await page.getByRole('button', { name: /add role/i }).click()
    await page.locator('#role-name').fill(name)
    await page.getByRole('checkbox', { name: /view orders/i }).check()
    await page.getByRole('button', { name: /^save$/i }).click()
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
    // The sheet closes on success and the badge leaves the staff row.
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
