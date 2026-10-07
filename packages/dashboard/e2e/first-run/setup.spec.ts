import { readFileSync } from 'node:fs'
import { expect, type Page, test } from '@playwright/test'
import { FIRST_RUN_CREDENTIALS_FILE } from '../paths'

// The link the seed printed, token included — the one a new merchant opens.
const { setup_url: setupUrl } = JSON.parse(readFileSync(FIRST_RUN_CREDENTIALS_FILE, 'utf-8')) as {
  setup_url: string
}

const merchant = {
  storeName: `First Run Store ${Date.now()}`,
  firstName: 'Ada',
  lastName: 'Merchant',
  email: `owner-${Date.now()}@example.com`,
  password: 'first-run-123',
}

async function fillSetupForm(page: Page) {
  await expect(page.getByRole('heading', { name: 'Set up Spree' })).toBeVisible()

  await page.getByLabel('Store name').fill(merchant.storeName)

  // Picking a country brings its currency and language with it.
  await page.getByLabel('Country').click()
  await page.getByPlaceholder('Search countries').fill('Poland')
  await page.getByRole('option', { name: /Poland/ }).click()
  await expect(page.getByLabel('Currency')).toContainText('PLN')
  await expect(page.getByLabel('Language')).toContainText('Polish')

  // The admin's dashboard follows this language, and the rest of the spec
  // reads English copy.
  await page.getByLabel('Language').click()
  await page.getByRole('option', { name: 'English' }).click()
  await expect(page.getByLabel('Currency')).toContainText('PLN')

  await page.getByLabel('First name').fill(merchant.firstName)
  await page.getByLabel('Last name').fill(merchant.lastName)
  await page.getByLabel('Email').fill(merchant.email)
  await page.getByLabel('Password', { exact: true }).fill(merchant.password)
  await page.getByLabel('Confirm password').fill(merchant.password)

  // Sample data downloads product images for minutes — not part of this flow.
  await page.getByRole('checkbox', { name: 'Load sample data' }).uncheck()
}

// Serial and in order: completing setup closes it for the rest of the run.
test.describe
  .serial('first-run setup', () => {
    test('the sign-in page points a fresh installation to setup', async ({ page }) => {
      await page.goto('/login')

      await expect(page.getByText("This installation isn't set up yet")).toBeVisible()
      await page.getByRole('link', { name: 'Go to setup' }).click()

      // That link carries no token — only the printed one does.
      await expect(page.getByRole('heading', { name: 'Setup link required' })).toBeVisible()
    })

    test('refuses a setup link with the wrong token', async ({ page }) => {
      await page.goto(setupUrl.replace(/token=[^&]+/, 'token=not-the-token'))
      await fillSetupForm(page)
      await page.getByRole('button', { name: 'Complete setup' }).click()

      await expect(
        page.getByText(
          'This installation is already set up. Sign in with your admin account instead.',
        ),
      ).toBeVisible()
      await expect(page).toHaveURL(/\/setup/)
    })

    test('creates the admin account, sets up the store and signs the merchant in', async ({
      page,
    }) => {
      await page.goto(setupUrl)
      await fillSetupForm(page)
      await page.getByRole('button', { name: 'Complete setup' }).click()

      await expect(page.getByText('Welcome, your store is now ready!')).toBeVisible({
        timeout: 20_000,
      })
      await expect(page).toHaveURL(/\/getting-started/)
      await expect(page.getByRole('heading', { name: 'Getting Started' })).toBeVisible()
      await expect(page.getByText(merchant.storeName).first()).toBeVisible()

      await page.getByRole('button', { name: 'User menu' }).click()
      await page.getByRole('menuitem', { name: 'Log out' }).click()
      await expect(page).toHaveURL(/\/login/)
    })

    test('closes setup once an admin exists', async ({ page }) => {
      await page.goto('/login')
      await expect(page.getByRole('heading', { name: 'Welcome back' })).toBeVisible()
      await expect(page.getByText("This installation isn't set up yet")).toBeHidden()

      await page.goto(setupUrl)
      await expect(page.getByRole('heading', { name: 'Setup is not available' })).toBeVisible()
    })

    test('the new admin signs in with the account created during setup', async ({ page }) => {
      await page.goto('/login')
      await page.getByLabel('Email').fill(merchant.email)
      await page.getByLabel('Password').fill(merchant.password)
      await page.getByRole('button', { name: 'Sign in' }).click()

      await expect(page).not.toHaveURL(/\/login/, { timeout: 15_000 })
      await expect(page.getByText(merchant.storeName).first()).toBeVisible()
    })
  })
