import { readFileSync } from 'node:fs'
import { expect, type Page } from '@playwright/test'
import { CREDENTIALS_FILE } from './paths'

/**
 * Fixture records seeded once in `global-setup.ts`. Specs that exercise
 * resource pickers (promotion rule/action editors, etc.) reference them
 * by name to make matching deterministic.
 */
export const FIXTURE_PROMO_TAXON = 'E2E Promo Category'
export const FIXTURE_PROMO_PRODUCT = 'E2E Promo Product'
// Active products used by products-bulk.spec.ts. Each test owns a disjoint
// pair so the serial suite doesn't cross-contaminate (status mutations on
// A/B don't shift the rows that the category/tag tests target). Kept here
// so the seed step and the spec stay in sync.
export const FIXTURE_BULK_PRODUCT_A = 'E2E Bulk Product A'
export const FIXTURE_BULK_PRODUCT_B = 'E2E Bulk Product B'
export const FIXTURE_BULK_PRODUCT_C = 'E2E Bulk Product C'
export const FIXTURE_BULK_PRODUCT_D = 'E2E Bulk Product D'
export const FIXTURE_BULK_PRODUCT_E = 'E2E Bulk Product E'
export const FIXTURE_BULK_PRODUCT_F = 'E2E Bulk Product F'
export const FIXTURE_BULK_PRODUCT_G = 'E2E Bulk Product G'
export const FIXTURE_BULK_PRODUCT_H = 'E2E Bulk Product H'
export const FIXTURE_BULK_PRODUCT_I = 'E2E Bulk Product I'
export const FIXTURE_BULK_PRODUCT_J = 'E2E Bulk Product J'
// Disjoint pair for the bulk-add-to-channels test (K/L) and the
// bulk-remove-from-channels test (M/N). M/N are pre-listed on
// FIXTURE_BULK_CHANNEL by the seed so the remove flow has something
// to undo.
export const FIXTURE_BULK_PRODUCT_K = 'E2E Bulk Product K'
export const FIXTURE_BULK_PRODUCT_L = 'E2E Bulk Product L'
export const FIXTURE_BULK_PRODUCT_M = 'E2E Bulk Product M'
export const FIXTURE_BULK_PRODUCT_N = 'E2E Bulk Product N'
// Dedicated category seeded for the bulk-add-to-categories test; lives under
// the `Categories` taxonomy alongside `FIXTURE_PROMO_TAXON`.
export const FIXTURE_BULK_CATEGORY = 'E2E Bulk Category'
// Second channel beyond the seeded default `online`. Used by the
// channels bulk-action and filter specs.
export const FIXTURE_BULK_CHANNEL_CODE = 'e2e-bulk'
export const FIXTURE_BULK_CHANNEL_NAME = 'E2E Bulk Channel'
export const FIXTURE_PROMO_CUSTOMER_EMAIL = 'e2e-promo-customer@example.com'
export const FIXTURE_PROMO_CUSTOMER_FIRST_NAME = 'Promo'
export const FIXTURE_PROMO_CUSTOMER_FULL_NAME = 'Promo Customer'
export const FIXTURE_PROMO_CUSTOMER_GROUP = 'E2E Promo Group'
export const FIXTURE_PROMO_COUNTRY = 'United States'

export interface E2ECredentials {
  api_url: string
  admin_email: string
  admin_password: string
  store_id: string
  store_name: string
}

let cached: E2ECredentials | null = null

export function getCredentials(): E2ECredentials {
  if (!cached) {
    cached = JSON.parse(readFileSync(CREDENTIALS_FILE, 'utf-8'))
  }
  return cached
}

/**
 * Drive the admin login flow as a precondition for any spec that needs an
 * authenticated session. Returns the credentials so callers can immediately
 * navigate into a specific store (e.g. `/${creds.store_id}/products/options`).
 *
 * Not used by `auth.spec.ts` — that spec exercises the login flow itself.
 */
export async function login(page: Page): Promise<E2ECredentials> {
  const creds = getCredentials()
  await page.goto('/login')
  await page.getByLabel(/email/i).fill(creds.admin_email)
  await page.getByLabel(/password/i).fill(creds.admin_password)
  await page.getByRole('button', { name: /^sign in$/i }).click()
  await expect(page).not.toHaveURL(/\/login/, { timeout: 15_000 })
  return creds
}

/**
 * Navigate to a resource index page and wait for it to settle. Every new
 * spec needs the same shape: visit the URL, wait for the page's primary
 * call-to-action button to appear (proves auth + data have loaded).
 */
export async function gotoIndex(page: Page, path: string, ctaButtonName: RegExp) {
  await page.goto(path)
  await expect(page.getByRole('button', { name: ctaButtonName })).toBeVisible({ timeout: 15_000 })
}

/**
 * Open the row-action kebab menu for the row whose cell text contains
 * `rowText`. Mirrors the universal `admin.row_actions.menu_label` aria-label
 * ("Open actions") across every resource table.
 */
export async function openRowMenu(page: Page, rowText: string) {
  await page
    .locator('tr')
    .filter({ hasText: rowText })
    .getByRole('button', { name: /open actions/i })
    .click()
}

/**
 * Click a bulk action by name. The `<BulkActionBar>` measures available width
 * and pushes overflowing actions into a "More actions" dropdown — at the
 * Playwright viewport (1280px) most rows show 4–5 inline actions and the rest
 * live in overflow. This helper tries the inline button first and falls back
 * to opening the dropdown and selecting the menu item.
 */
export async function clickBulkAction(page: Page, name: RegExp) {
  const inline = page.getByRole('button', { name }).first()
  const visible = await inline.isVisible().catch(() => false)
  if (visible) {
    await inline.click()
    return
  }
  await page.getByRole('button', { name: /more actions/i }).click()
  await page.getByRole('menuitem', { name }).click()
}

/**
 * Locator for the `<ResourceNameCell>` button on a resource index table.
 * The cell's accessible name is `"<name> <secondary?>"` and a sibling icon
 * `<Button aria-label="Edit <name>">` may exist, so we anchor with `^` plus
 * a word-boundary follow-up to disambiguate. `escapeRegex` keeps dynamic
 * test names (`"E2E Foo (updated)"`) from being parsed as regex syntax.
 */
export function rowButton(page: Page, name: string) {
  return page.getByRole('button', { name: new RegExp(`^${escapeRegex(name)}(\\s|$)`) })
}

function escapeRegex(s: string) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

export interface AddressInput {
  firstName?: string
  lastName?: string
  address1?: string
  city?: string
  postalCode?: string
  phone?: string
  /** Custom label shown when the address-form-dialog renders one (only on some surfaces). */
  label?: string
  /** Country name to pick in the `<CountryCombobox>`. Server requires it. */
  country?: string
  /** State name to pick when the country has a state list. Omit for countries without one. */
  state?: string
}

/**
 * Fill the shared `<AddressFormDialog>` Sheet ("Add address" / "Edit address").
 * The country picker is a Base UI Combobox; we drive it by typing into the
 * input (placeholder "Search countries...") and clicking the matching option.
 * Same pattern for the state combobox when the country needs one.
 */
export async function fillAddressForm(page: Page, address: AddressInput) {
  if (address.label !== undefined) await page.locator('#addr-label').fill(address.label)
  if (address.firstName !== undefined) await page.locator('#addr-fn').fill(address.firstName)
  if (address.lastName !== undefined) await page.locator('#addr-ln').fill(address.lastName)
  if (address.address1 !== undefined) await page.locator('#addr-a1').fill(address.address1)
  if (address.city !== undefined) await page.locator('#addr-city').fill(address.city)
  if (address.postalCode !== undefined) await page.locator('#addr-zip').fill(address.postalCode)
  if (address.phone !== undefined) await page.locator('#addr-phone').fill(address.phone)
  if (address.country) {
    await page.getByPlaceholder(/^search countries/i).fill(address.country)
    await page.getByRole('option', { name: address.country }).first().click()
  }
  if (address.state) {
    await page.getByPlaceholder(/^search states/i).fill(address.state)
    await page.getByRole('option', { name: address.state }).first().click()
  }
}
