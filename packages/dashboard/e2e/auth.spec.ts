import { expect, test } from '@playwright/test'
import { getCredentials } from './helpers'

test.describe('admin authentication', () => {
  test('signs in via the login form and lands on the dashboard', async ({ page }) => {
    const creds = getCredentials()

    await page.goto('/login')
    await expect(page.getByText(/welcome back/i)).toBeVisible()

    await page.getByLabel(/email/i).fill(creds.admin_email)
    await page.getByLabel(/password/i).fill(creds.admin_password)
    await page.getByRole('button', { name: /^sign in$/i }).click()

    // The /_authenticated/ index resolves the active store and redirects to
    // /$storeId. We just need to leave /login.
    await expect(page).not.toHaveURL(/\/login/, { timeout: 15_000 })
    await expect(page.url()).not.toContain('/login')
  })

  test('rejects invalid credentials with an inline error', async ({ page }) => {
    await page.goto('/login')

    await page.getByLabel(/email/i).fill('admin@example.com')
    await page.getByLabel(/password/i).fill('wrong-password-123')
    await page.getByRole('button', { name: /^sign in$/i }).click()

    await expect(page.getByText(/invalid email or password/i)).toBeVisible()
    expect(page.url()).toContain('/login')
  })
})
