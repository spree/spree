import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login } from './helpers'

// Validation copy reaches the merchant by two routes, and this spec pins both:
//
// - client-side, from the form's own schema (`admin.validation.required`),
//   which fires before anything is sent, and
// - server-side, from a 422 whose Rails error *code* the dashboard translates
//   (`admin.validation.codes.*`), in the admin's interface language rather
//   than the store's.
//
// The two share a parent key and once collided: a Rails `required` (a missing
// association, "must exist") landed under every required input in the
// dashboard. Each case below names the message the merchant should read and
// the one they must never see.

const NEVER = /must exist/i

const PRODUCTS_PATH = (storeId: string) => `/${storeId}/products`
const CATALOGS_PATH = (storeId: string) => `/${storeId}/products/catalogs`
const CHANNELS_PATH = (storeId: string) => `/${storeId}/settings/channels`

// A channel code the client schema accepts (`^[a-z0-9_-]*$`) and the server
// refuses the second time: uniqueness is enforced only by the API, so the
// error can only arrive as a 422 — the case that exercises code translation.
function uniqueCode() {
  return `e2e-val-${Date.now()}`
}

async function submitBlankProduct(page: Page, storeId: string, createButton: RegExp) {
  await page.goto(`${PRODUCTS_PATH(storeId)}/new`)
  const name = page.locator('#product-name')
  await expect(name).toBeVisible({ timeout: 15_000 })
  // The Publishing card seeds the store's default channel once its query
  // lands, and that seed resets the form. Submitting before it arrives is
  // silently undone, so wait for the seeded channel (data, so the same text
  // in every UI language) before touching anything.
  await expect(page.getByText(/online store/i).first()).toBeVisible({ timeout: 15_000 })
  // Create stays disabled until something changes, so type a name and take
  // it back — which is also exactly how a merchant ends up submitting a
  // blank one.
  await name.fill('x')
  await name.fill('')
  const create = page.getByRole('button', { name: createButton }).first()
  await expect(create).toBeEnabled()
  await create.click()
}

async function createChannel(page: Page, name: string, code: string, cta: RegExp) {
  await page.getByRole('button', { name: cta }).click()
  const sheet = page.getByRole('dialog')
  await sheet.locator('#name').fill(name)
  await sheet.locator('#code').fill(code)
  await sheet.locator('button[type="submit"]').click()
  return sheet
}

test.describe('validation messages', () => {
  test('a required product field says it is required, not "must exist"', async ({ page }) => {
    const creds = await login(page)
    await submitBlankProduct(page, creds.store_id, /create product/i)

    await expect(page.getByText(/^name is required$/i)).toBeVisible({ timeout: 5_000 })
    await expect(page.getByText(NEVER)).toHaveCount(0)
  })

  test('the catalog wizard marks a blank name the same way', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATALOGS_PATH(creds.store_id), /add catalog/i)

    await page.getByRole('button', { name: /add catalog/i }).click()
    const wizard = page.getByRole('dialog')
    await expect(wizard.getByRole('heading', { name: /new catalog/i })).toBeVisible()
    // Leave the name empty and try to move on.
    await wizard.getByRole('button', { name: /^next$/i }).click()

    await expect(wizard.getByText(/^name is required$/i)).toBeVisible({ timeout: 5_000 })
    await expect(wizard.getByText(NEVER)).toHaveCount(0)
  })

  test('a server-side failure renders under its field with the Rails wording', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CHANNELS_PATH(creds.store_id), /new sales channel/i)

    const code = uniqueCode()
    const first = await createChannel(page, `E2E Val Channel A ${code}`, code, /new sales channel/i)
    await expect(first).toBeHidden({ timeout: 15_000 })

    // Same code again: the client schema is satisfied, so only the API can
    // object, and it does with the `taken` code.
    const second = await createChannel(
      page,
      `E2E Val Channel B ${code}`,
      code,
      /new sales channel/i,
    )

    await expect(second.getByText(/^has already been taken$/i)).toBeVisible({ timeout: 15_000 })
    await expect(second.getByText(NEVER)).toHaveCount(0)
  })

  test.describe('in the admin’s own language', () => {
    // The choice a merchant makes in the top bar is remembered here; setting
    // it before the app boots is what a returning German-speaking admin sees.
    // The store itself stays English, so anything still reading the store's
    // locale would show through as English below.
    test.beforeEach(async ({ page }) => {
      await page.addInitScript(() => {
        localStorage.setItem('spree-admin-locale', 'de')
      })
    })

    test('a required field is explained in German', async ({ page }) => {
      const creds = await login(page)
      await submitBlankProduct(page, creds.store_id, /produkt erstellen/i)

      await expect(page.getByText(/^name ist erforderlich$/i)).toBeVisible({ timeout: 5_000 })
      await expect(page.getByText(/is required|must exist/i)).toHaveCount(0)
    })

    test('a server-side code is translated, not echoed in the store’s locale', async ({ page }) => {
      const creds = await login(page)
      await gotoIndex(page, CHANNELS_PATH(creds.store_id), /neuer verkaufskanal/i)

      const code = uniqueCode()
      const first = await createChannel(
        page,
        `E2E Val Kanal A ${code}`,
        code,
        /neuer verkaufskanal/i,
      )
      await expect(first).toBeHidden({ timeout: 15_000 })

      const second = await createChannel(
        page,
        `E2E Val Kanal B ${code}`,
        code,
        /neuer verkaufskanal/i,
      )

      // The API resolved this error in the store's English; the dashboard
      // renders its own German for the code instead of reprinting that text.
      await expect(second.getByText(/^ist bereits vergeben$/i)).toBeVisible({ timeout: 15_000 })
      await expect(second.getByText(/has already been taken/i)).toHaveCount(0)
    })
  })
})
