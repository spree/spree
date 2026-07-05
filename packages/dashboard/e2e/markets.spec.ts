import { expect, type Page, test } from '@playwright/test'
import { gotoIndex, login, openRowMenu, rowButton } from './helpers'

const MARKETS_PATH = (storeId: string) => `/${storeId}/settings/markets`
const CTA = /add market/i

/**
 * Drive the "Add market" sheet. `countries` are picked through the
 * `CountryMultiCombobox` — same pattern as `fillAddressForm` in `helpers.ts`,
 * but we expect multiple matches per typed term so we click each one in turn.
 *
 * `currency`/`default_locale` default to the store's defaults (USD / en) and
 * are usually fine left alone — only override when the test cares about the
 * specific value.
 */
/** A supported locale to add: `search` is typed into the picker, `label`
 *  matches the rendered `CODE — Name` option (and the resulting chip). */
type LocalePick = { search: string; label: RegExp }

async function createMarket(
  page: Page,
  attrs: { name: string; countries: string[]; supportedLocales?: LocalePick[] },
) {
  await page.getByRole('button', { name: /add market/i }).click()
  await expect(page.getByRole('heading', { name: /add market/i })).toBeVisible()

  await page.locator('#market-name').fill(attrs.name)

  for (const country of attrs.countries) {
    await page.getByPlaceholder(/^search countries/i).fill(country)
    await page.getByRole('option', { name: country }).first().click()
  }

  for (const locale of attrs.supportedLocales ?? []) {
    await addSupportedLocale(page, locale)
  }

  await page.getByRole('button', { name: /create market/i }).click()
}

/**
 * Add one locale to the "Supported locales" chips picker (`LocaleSelect`,
 * multi-select). The picker offers the full canonical translation-locale set
 * (`Spree::Locales::ALL`) — including regional variants like `pt-BR` that the
 * store doesn't already use — so options are searchable: type, then click the
 * matching `CODE — Name` option.
 */
async function addSupportedLocale(page: Page, { search, label }: LocalePick) {
  const input = page.locator('#market-supported-locales')
  await input.click()
  await input.fill(search)
  await page.getByRole('option', { name: label }).first().click()
  // The selection renders as a chip with the same `CODE — Name` label.
  await expect(page.getByText(label).first()).toBeVisible()
}

// The seeded default store creates a default market for `US` via
// `Store#ensure_default_market` (anchored to `default_country_iso = 'US'`),
// plus a EUR market anchored to `Germany` (so the store is multi-currency —
// see `global-setup.ts`). `Spree::MarketCountry#country_unique_per_store`
// rejects re-assigning a country to a second market in the same store, so
// every test below picks from countries *not* already covered by the US or
// EUR markets — i.e. avoid `US`/`Germany`, drawing from the North America +
// EU_VAT shipping zones seeded in `global-setup.ts`.
test.describe('markets', () => {
  test('lists markets', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, MARKETS_PATH(creds.store_id), CTA)
  })

  test('creates a new market', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, MARKETS_PATH(creds.store_id), CTA)

    const name = `E2E Market ${Date.now()}`
    await createMarket(page, { name, countries: ['Canada'] })

    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })
  })

  test('creates a market with non-standard regional supported locales', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, MARKETS_PATH(creds.store_id), CTA)

    // Regional variants the store does not already use — these were unselectable
    // before the picker offered the full translation-locale set. Picking them
    // here exercises both selectability and persistence.
    const name = `E2E Locale Market ${Date.now()}`
    await createMarket(page, {
      name,
      countries: ['Mexico'],
      supportedLocales: [
        { search: 'pt-BR', label: /pt-br — /i },
        { search: 'zh-CN', label: /zh-cn — /i },
      ],
    })

    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    // Reopen the market and confirm the regional variants persisted as chips.
    await rowButton(page, name).click()
    await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
    await expect(page.getByText(/pt-br — /i).first()).toBeVisible()
    await expect(page.getByText(/zh-cn — /i).first()).toBeVisible()
  })

  test('edits a market', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, MARKETS_PATH(creds.store_id), CTA)

    const suffix = Date.now()
    const original = `E2E Edit Market ${suffix}`
    const updated = `${original} (updated)`

    // Austria, not Germany — the seeded EUR market already owns Germany.
    await createMarket(page, { name: original, countries: ['Austria'] })
    await expect(rowButton(page, original)).toBeVisible({ timeout: 15_000 })

    await rowButton(page, original).click()
    await expect(page.getByRole('heading', { name: original })).toBeVisible({ timeout: 15_000 })
    await expect(page.locator('#market-name')).toHaveValue(original)

    await page.locator('#market-name').fill(updated)
    await page.getByRole('button', { name: /^save$/i }).click()

    await expect(rowButton(page, updated)).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a market', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, MARKETS_PATH(creds.store_id), CTA)

    const name = `E2E Delete Market ${Date.now()}`
    // The seeded default market keeps the store from going empty, so deleting
    // this fresh non-default market is allowed. `can_be_deleted?` blocks the
    // default and the last-remaining market — neither applies here.
    await createMarket(page, { name, countries: ['France'] })
    await expect(rowButton(page, name)).toBeVisible({ timeout: 15_000 })

    // Delete lives on the row-action kebab.
    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete market\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })
})
