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

  test('reaches the forgot-password page from the login form', async ({ page }) => {
    await page.goto('/login')
    await page.getByRole('link', { name: /forgot password/i }).click()

    await expect(page).toHaveURL(/\/forgot-password/)
    await expect(page.getByText('Reset your password', { exact: true })).toBeVisible()
  })

  test('confirms the reset request without revealing whether the email exists', async ({
    page,
  }) => {
    // Same confirmation for a real and an unknown email — no account enumeration.
    for (const email of ['admin@example.com', 'nobody@example.com']) {
      await page.goto('/forgot-password')
      await page.getByLabel(/email/i).fill(email)
      await page.getByRole('button', { name: /send reset link/i }).click()

      await expect(page.getByText(/check your email/i)).toBeVisible({ timeout: 15_000 })
    }
  })

  test('shows an invalid-link message when the reset token is missing', async ({ page }) => {
    await page.goto('/reset-password')

    await expect(page.getByText(/invalid reset link/i)).toBeVisible()
    await expect(page.getByRole('link', { name: /request a new reset link/i })).toBeVisible()
  })
})
