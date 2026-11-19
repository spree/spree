import { expect, test } from '@playwright/test'
import {
  FIXTURE_LEDGER_SELLER,
  FIXTURE_SELLER_PASSWORD,
  FIXTURE_SELLER_USER_EMAIL,
  FIXTURE_SELLER_WRITER_EMAIL,
  login,
  rowButton,
  SELLER_PANEL,
  sellerLogin,
} from './helpers'

test.describe('seller panel — signing in', () => {
  test('signs in with the form and lands on the seller home', async ({ page }) => {
    await page.goto(`${SELLER_PANEL}/login`)
    await page.getByLabel(/^email$/i).fill(FIXTURE_SELLER_USER_EMAIL)
    await page.getByLabel(/^password$/i).fill(FIXTURE_SELLER_PASSWORD)
    await page.getByRole('button', { name: /^sign in$/i }).click()

    await expect(page).toHaveURL(/\/sel_[^/]+$/, { timeout: 20_000 })
    await expect(
      page.getByRole('heading', { name: `Hello, ${FIXTURE_LEDGER_SELLER}` }),
    ).toBeVisible()
  })

  test('refuses a wrong password', async ({ page }) => {
    await page.goto(`${SELLER_PANEL}/login`)
    await page.getByLabel(/^email$/i).fill(FIXTURE_SELLER_USER_EMAIL)
    await page.getByLabel(/^password$/i).fill('not-the-password')
    await page.getByRole('button', { name: /^sign in$/i }).click()

    await expect(page.getByText(/did not match a seller account/i)).toBeVisible({
      timeout: 15_000,
    })
    await expect(page).toHaveURL(/\/login/)
  })

  test('sends a password reset link', async ({ page }) => {
    await page.goto(`${SELLER_PANEL}/login`)
    await page.getByRole('link', { name: /forgot your password/i }).click()

    await page.getByLabel(/^email$/i).fill(FIXTURE_SELLER_USER_EMAIL)
    await page.getByRole('button', { name: /send reset link/i }).click()

    await expect(page.getByRole('heading', { name: /check your email/i })).toBeVisible({
      timeout: 15_000,
    })
  })

  test('signs out back to the sign-in page', async ({ page }) => {
    await sellerLogin(page)

    await page.getByRole('button', { name: /user menu/i }).click()
    await page.getByRole('menuitem', { name: /sign out|log out/i }).click()

    await expect(page).toHaveURL(/\/login/, { timeout: 15_000 })
    // The session is gone, not just the page: going back in asks again.
    await page.goto(SELLER_PANEL)
    await expect(page).toHaveURL(/\/login/, { timeout: 15_000 })
  })
})

test.describe('seller panel — home', () => {
  // `sellerLogin` opens the panel with a session but no remembered seller —
  // the cold start where the sidebar used to stay empty, because permissions
  // were fetched before a seller was chosen and never again.
  test('shows where the seller stands, and each section is a click away', async ({ page }) => {
    await sellerLogin(page)

    await expect(page.getByText(/^status$/i)).toBeVisible()
    await expect(page.getByText(/^approved$/i).first()).toBeVisible()
    await expect(page.getByText(/^team members$/i)).toBeVisible()

    for (const [link, heading] of [
      [/^products$/i, /^products$/i],
      [/^orders$/i, /^orders$/i],
      [/^earnings$/i, /^earnings$/i],
      [/^payouts$/i, /^payouts$/i],
    ] as const) {
      await page.getByRole('link', { name: link }).first().click()
      await expect(page.getByRole('heading', { name: heading, level: 1 })).toBeVisible({
        timeout: 15_000,
      })
    }
  })
})

test.describe('seller panel — setup', () => {
  test('accepting the marketplace terms ticks that step off', async ({ page }) => {
    await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    await page
      .getByRole('link', { name: /^setup/i })
      .first()
      .click()
    await expect(page.getByRole('heading', { name: /^setup$/i })).toBeVisible({
      timeout: 15_000,
    })

    const step = page.getByRole('button', { name: /accept terms/i })
    await expect(step).toBeVisible({ timeout: 15_000 })
    // Opens on the first outstanding step, which is usually this one.
    if ((await step.getAttribute('aria-expanded')) !== 'true') await step.click()
    await page.getByRole('button', { name: /accept the terms/i }).click()

    await expect(page.getByText(/terms accepted/i)).toBeVisible({ timeout: 15_000 })
    await expect(step.getByText(/^done$/i)).toBeVisible({ timeout: 15_000 })
  })

  test('complete profile says what is missing and links to where it is edited', async ({
    page,
  }) => {
    const home = await sellerLogin(page, FIXTURE_SELLER_WRITER_EMAIL)
    const save = page.getByRole('button', { name: /^save$/i }).first()

    await page.goto(`${home}/settings/profile`)
    await page.locator('#seller-about').click()
    await page.keyboard.press('ControlOrMeta+A')
    await page.keyboard.press('Backspace')
    if (await save.isEnabled()) {
      await save.click()
      await expect(page.getByText(/profile saved/i)).toBeVisible({ timeout: 15_000 })
    }

    await page.goto(`${home}/onboarding`)
    const step = page.getByRole('button', { name: /complete profile/i })
    await expect(step).toBeVisible({ timeout: 15_000 })
    if ((await step.getAttribute('aria-expanded')) !== 'true') await step.click()

    // A contact email is only asked for when the marketplace opts in.
    await expect(page.getByText(/still missing:.*a description/i)).toBeVisible()
    await expect(page.getByText(/still missing:.*contact email/i)).toHaveCount(0)
    await page
      .getByRole('link', { name: /^go there$/i })
      .first()
      .click()
    await expect(page).toHaveURL(/\/settings\/profile$/, { timeout: 15_000 })

    // The panel seller is shared across this shard, so put a description back.
    await page.locator('#seller-about').click()
    await page.locator('#seller-about').pressSequentially('Hand-thrown ceramics.')
    await save.click()
    await expect(page.getByText(/profile saved/i).first()).toBeVisible({ timeout: 15_000 })
  })

  // The contact email is opt-in, and it is edited on General rather than on
  // Profile, so a step waiting only for it links there.
  test('complete profile links to General when the contact email is all that is left', async ({
    page,
    browser,
  }) => {
    const creds = await login(page)
    const sheet = page.getByRole('dialog')
    const requireEmail = sheet.getByRole('switch', { name: /require contact email/i })
    async function setRequireEmail(on: boolean) {
      await page.goto(`/${creds.store_id}/settings/seller-requirements`)
      await rowButton(page, 'Complete profile').click()
      await expect(sheet).toBeVisible({ timeout: 15_000 })
      if ((await requireEmail.getAttribute('aria-checked')) !== String(on))
        await requireEmail.click()
      await sheet.getByRole('button', { name: /^save$/i }).click()
      await expect(sheet).toHaveCount(0, { timeout: 15_000 })
    }
    await setRequireEmail(true)

    const context = await browser.newContext()
    const seller = await context.newPage()
    const save = seller.getByRole('button', { name: /^save$/i }).first()
    let home = ''
    let originalEmail = ''
    try {
      home = await sellerLogin(seller, FIXTURE_SELLER_WRITER_EMAIL)

      // Everything public filled in, so the email is the only gap.
      await seller.goto(`${home}/settings/profile`)
      await seller.locator('#seller-about').click()
      await seller.keyboard.press('ControlOrMeta+A')
      await seller.locator('#seller-about').pressSequentially('Hand-thrown ceramics.')
      await seller
        .locator('input[type=file]')
        .first()
        .setInputFiles({
          name: 'logo.png',
          mimeType: 'image/png',
          buffer: Buffer.from(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
            'base64',
          ),
        })
      await expect(save).toBeEnabled({ timeout: 15_000 })
      await save.click()
      await expect(seller.getByText(/profile saved/i)).toBeVisible({ timeout: 15_000 })

      await seller.goto(`${home}/settings/general`)
      const email = seller.locator('#seller-contact-email')
      await expect(email).toBeVisible({ timeout: 15_000 })
      originalEmail = await email.inputValue()
      await email.fill('')
      if (await save.isEnabled()) {
        await save.click()
        await expect(seller.getByText(/profile saved/i).first()).toBeVisible({ timeout: 15_000 })
      }

      await seller.goto(`${home}/onboarding`)
      const step = seller.getByRole('button', { name: /complete profile/i })
      await expect(step).toBeVisible({ timeout: 15_000 })
      if ((await step.getAttribute('aria-expanded')) !== 'true') await step.click()
      await expect(seller.getByText(/^still missing: a contact email\.$/i)).toBeVisible()
      await seller
        .getByRole('link', { name: /^go there$/i })
        .first()
        .click()
      await expect(seller).toHaveURL(/\/settings\/general$/, { timeout: 15_000 })
    } finally {
      // The panel seller is shared across this shard, so put back the email it
      // had and switch the requirement off, whether or not the checks passed.
      try {
        if (originalEmail) {
          await seller.goto(`${home}/settings/general`)
          await seller.locator('#seller-contact-email').fill(originalEmail)
          if (await save.isEnabled()) {
            await save.click()
            await expect(seller.getByText(/profile saved/i).first()).toBeVisible({
              timeout: 15_000,
            })
          }
        }
      } finally {
        await context.close()
        await setRequireEmail(false)
      }
    }
  })
})
