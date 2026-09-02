import { expect, type Page, test } from '@playwright/test'
import {
  deleteCatalogPickerProducts,
  FIXTURE_CATALOG_PICKER_PRODUCT_COUNT,
  FIXTURE_CATALOG_PICKER_PRODUCT_PREFIX,
  FIXTURE_PROMO_PRODUCT,
  gotoIndex,
  login,
  seedCatalogPickerProducts,
} from './helpers'

const CATALOGS_PATH = (storeId: string) => `/${storeId}/products/catalogs`
const CTA = /add catalog/i

// New catalog is a full-window wizard dialog — Details, Audience, Products,
// Pricing, Review — that writes nothing until Create on the last step.
async function createCatalog(page: Page, name: string) {
  await page.getByRole('button', { name: CTA }).click()

  const wizard = page.getByRole('dialog')
  await expect(wizard.getByRole('heading', { name: /new catalog/i })).toBeVisible()
  await wizard.locator('#catalog-name').fill(name)

  // Audience, Products and Pricing are all answered by their defaults: no
  // audience, no assortment and base prices are each a legitimate agreement.
  //
  // Each step is confirmed from the rail before the next click: Next and
  // Create occupy the same slot in the footer, so clicking without knowing
  // where the wizard is submits the form a step early.
  const onStep = (label: RegExp) =>
    expect(wizard.getByRole('button', { name: label })).toHaveAttribute('aria-current', 'step')

  await onStep(/^details$/i)
  for (const step of [/^audience$/i, /^products$/i, /^pricing$/i, /^review$/i]) {
    await wizard.getByRole('button', { name: /^next$/i }).click()
    await onStep(step)
  }

  // `noWaitAfter`: Create closes the dialog and navigates, and a click that
  // waits for its own element to settle races that teardown. The outcome is
  // what matters, and the next assertion is the one that proves it.
  await wizard.getByRole('button', { name: /create catalog/i }).click({ noWaitAfter: true })

  // On success the dialog closes onto the new catalog's detail page.
  await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 15_000 })
}

async function saveCatalog(page: Page) {
  await page
    .getByRole('main')
    .getByRole('button', { name: /^save$/i })
    .first()
    .click()
}

// The catalog detail page saves in one shot: settings and staged product
// changes flush together from the header Save, same as the price list editor.
test.describe('catalogs', () => {
  test('creates a catalog', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATALOGS_PATH(creds.store_id), CTA)

    const name = `E2E Catalog ${Date.now()}`
    await createCatalog(page, name)

    await page.goto(CATALOGS_PATH(creds.store_id))
    await expect(page.getByText(name)).toBeVisible({ timeout: 15_000 })
  })

  test('stages product membership and persists it on Save', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATALOGS_PATH(creds.store_id), CTA)

    const name = `E2E Catalog Products ${Date.now()}`
    await createCatalog(page, name)

    // Fresh catalog: the products card shows its empty state.
    await expect(page.getByText(/no products in this catalog yet/i)).toBeVisible({
      timeout: 15_000,
    })

    // Stage a product through the picker sheet — it renders immediately with
    // the "New" badge but is not persisted yet.
    await page.getByRole('button', { name: /add products/i }).click()
    const picker = page.getByRole('dialog')
    await expect(picker.getByRole('heading', { name: /add products to catalog/i })).toBeVisible()
    await picker.getByRole('searchbox').fill(FIXTURE_PROMO_PRODUCT)
    const option = picker
      .getByRole('button', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
      .first()
    await expect(option).toBeVisible({ timeout: 15_000 })
    await option.click()
    await picker.getByRole('button', { name: /^add 1$/i }).click()
    await expect(picker).toBeHidden({ timeout: 15_000 })

    const productRow = page.getByRole('row', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
    await expect(productRow).toBeVisible({ timeout: 15_000 })
    await expect(productRow.getByText(/^new$/i)).toBeVisible()

    // Save flushes the staged addition; the badge disappears once the row
    // comes back from the server.
    await saveCatalog(page)
    await expect(productRow.getByText(/^new$/i)).toHaveCount(0, { timeout: 15_000 })

    // Reload and prove the membership actually persisted.
    await page.reload()
    await expect(productRow).toBeVisible({ timeout: 15_000 })

    // Removing marks the row (restore stays available) and only Save makes
    // it real.
    await productRow.getByRole('button', { name: /remove from catalog/i }).click()
    await expect(productRow.getByRole('button', { name: /restore/i })).toBeVisible()

    // A product staged for removal is re-pickable — the picker must not lock
    // it as "already added", or the row's restore arrow is the only way back.
    await page.getByRole('button', { name: /add products/i }).click()
    const rePicker = page.getByRole('dialog')
    await rePicker.getByRole('searchbox').fill(FIXTURE_PROMO_PRODUCT)
    const reOption = rePicker
      .getByRole('button', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
      .first()
    await expect(reOption).toBeEnabled({ timeout: 15_000 })
    await reOption.click()
    await rePicker.getByRole('button', { name: /^add 1$/i }).click()
    await expect(rePicker).toBeHidden({ timeout: 15_000 })
    // Re-picking cancels the removal rather than staging a duplicate.
    await expect(productRow.getByRole('button', { name: /restore/i })).toHaveCount(0)
    await expect(productRow).toHaveCount(1)

    // Remove it again, for real this time.
    await productRow.getByRole('button', { name: /remove from catalog/i }).click()
    await expect(productRow.getByRole('button', { name: /restore/i })).toBeVisible()

    await saveCatalog(page)
    await expect(page.getByText(/no products in this catalog yet/i)).toBeVisible({
      timeout: 15_000,
    })

    // Reload and prove the removal persisted too.
    await page.reload()
    await expect(page.getByText(/no products in this catalog yet/i)).toBeVisible({
      timeout: 15_000,
    })
  })

  // An owned price list prices the catalog's assortment and nothing else, so
  // the spreadsheet has to open on the products the catalog actually holds —
  // and drop the ones on their way out.
  test('prices the assortment, and omits a product staged for removal', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATALOGS_PATH(creds.store_id), CTA)

    const name = `E2E Catalog Prices ${Date.now()}`
    await createCatalog(page, name)

    // Products first, then pricing — the order a merchant works in.
    await page.getByRole('button', { name: /add products/i }).click()
    const picker = page.getByRole('dialog')
    await expect(picker.getByRole('heading', { name: /add products to catalog/i })).toBeVisible()
    await picker.getByRole('searchbox').fill(FIXTURE_PROMO_PRODUCT)
    const option = picker
      .getByRole('button', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
      .first()
    await expect(option).toBeVisible({ timeout: 15_000 })
    await option.click()
    await picker.getByRole('button', { name: /^add 1$/i }).click()
    await expect(picker).toBeHidden({ timeout: 15_000 })

    await page.locator('#catalog-pricing-mode').click()
    await page.getByRole('option', { name: /prices i enter for this catalog/i }).click()
    await saveCatalog(page)

    // The list is created by Save and seeded from the assortment, so the
    // spreadsheet opens on a priceable row rather than empty.
    //
    // `.first()`: the button sits on the pricing card and on the products
    // card — pricing the rows being priced belongs there too — and both open
    // this one grid.
    const openPrices = page.getByRole('button', { name: /^enter prices$/i }).first()
    await expect(openPrices).toBeVisible({ timeout: 15_000 })
    await openPrices.click()
    const grid = page.getByRole('dialog')
    const cell = grid.getByLabel(/^price for/i).first()
    await expect(cell).toBeVisible({ timeout: 15_000 })

    // Entering a price has to reach the assortment rows behind the grid: they
    // carry what the agreement charges, so closing onto the old amount is the
    // merchant being shown a price that is no longer true.
    // The grid is a spreadsheet: a cell is read-only until it is opened for
    // editing, which is a double click, exactly as a merchant does it.
    await cell.dblclick()
    await cell.fill('12.34')
    await cell.press('Enter')

    // Save is disabled until the grid registers the edit, and it disables
    // again once the write lands — which is also what tells us the close
    // below will not be caught by the unsaved-changes guard.
    const savePrices = grid.getByRole('button', { name: /^save prices$/i })
    await expect(savePrices).toBeEnabled({ timeout: 15_000 })
    await savePrices.click()
    await expect(savePrices).toBeDisabled({ timeout: 15_000 })

    await grid.getByRole('button', { name: /^close$/i }).click()
    await expect(grid).toBeHidden({ timeout: 15_000 })

    await expect(page.getByText('$12.34')).toBeVisible({ timeout: 15_000 })

    // Staging the product for removal takes it out of the grid: its prices
    // survive until Save, but pricing something on its way out is wasted work.
    const productRow = page.getByRole('row', { name: new RegExp(FIXTURE_PROMO_PRODUCT, 'i') })
    await productRow.getByRole('button', { name: /remove from catalog/i }).click()
    await expect(productRow.getByRole('button', { name: /restore/i })).toBeVisible()

    await openPrices.click()
    const emptyGrid = page.getByRole('dialog')
    await expect(emptyGrid.getByLabel(/^price for/i)).toHaveCount(0, { timeout: 15_000 })
  })

  // An automatic agreement is a percentage plus the quantity it starts at.
  // Both have to survive a reload, and a second Save must not fail on the
  // rule the first one wrote
  // (docs/plans/6.0-price-list-automatic-pricing.md).
  test('keeps the percentage and its quantity threshold across saves', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATALOGS_PATH(creds.store_id), CTA)

    const name = `E2E Catalog Volume ${Date.now()}`
    await createCatalog(page, name)

    await page.locator('#catalog-pricing-mode').click()
    await page.getByRole('option', { name: /percentage off/i }).click()
    await page.locator('#catalog-adjustment-magnitude').fill('10')
    await page.locator('#catalog-minimum-quantity').fill('10')
    await saveCatalog(page)

    await page.reload()
    await expect(page.locator('#catalog-adjustment-magnitude')).toHaveValue('10', {
      timeout: 15_000,
    })
    await expect(page.locator('#catalog-minimum-quantity')).toHaveValue('10')

    // Saving again re-sends the same rule; it must update the row rather
    // than try to add a second of its kind.
    await page.locator('#catalog-adjustment-magnitude').fill('20')
    await saveCatalog(page)
    await page.reload()
    await expect(page.locator('#catalog-adjustment-magnitude')).toHaveValue('20', {
      timeout: 15_000,
    })
    await expect(page.locator('#catalog-minimum-quantity')).toHaveValue('10')
  })

  // The threshold survives a switch away from automatic pricing, where its
  // field is no longer rendered. Judging it then would block Save over
  // something the merchant cannot see or correct. The input refuses letters
  // on its own, so the value that gets here is a number the rule still
  // rejects — zero gates nothing.
  test('does not judge the quantity once the agreement prices by hand', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATALOGS_PATH(creds.store_id), CTA)

    const name = `E2E Catalog Switch ${Date.now()}`
    await createCatalog(page, name)

    await page.locator('#catalog-pricing-mode').click()
    await page.getByRole('option', { name: /percentage off/i }).click()
    await page.locator('#catalog-adjustment-magnitude').fill('10')
    await page.locator('#catalog-minimum-quantity').fill('0')

    await page.locator('#catalog-pricing-mode').click()
    await page.getByRole('option', { name: /prices i enter for this catalog/i }).click()
    await expect(page.locator('#catalog-minimum-quantity')).toHaveCount(0)

    await saveCatalog(page)

    // Saved: the list exists, so the price spreadsheet is reachable — from the
    // pricing card and from the assortment rows alike.
    await expect(page.getByRole('button', { name: /^enter prices$/i }).first()).toBeVisible({
      timeout: 15_000,
    })
  })

  // The order minimums stage like everything else on the page: nothing is
  // written until Save, and Discard is the undo.
  test('stages an order minimum and persists it on Save', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATALOGS_PATH(creds.store_id), CTA)

    const name = `E2E Catalog Minimum ${Date.now()}`
    await createCatalog(page, name)

    await page.getByRole('button', { name: /^add$/i }).first().click()
    await page.getByLabel(/minimum amount/i).fill('500')

    // Still unsaved: a reload before Save must lose it.
    await page.reload()
    await expect(page.getByLabel(/minimum amount/i)).toHaveCount(0, { timeout: 15_000 })

    await page.getByRole('button', { name: /^add$/i }).first().click()
    await page.getByLabel(/minimum amount/i).fill('500')
    await saveCatalog(page)

    await page.reload()
    await expect(page.getByLabel(/minimum amount/i)).toHaveValue('500.0', { timeout: 15_000 })
  })

  test('renames a catalog from the header Save', async ({ page }) => {
    const creds = await login(page)
    await gotoIndex(page, CATALOGS_PATH(creds.store_id), CTA)

    const name = `E2E Catalog Rename ${Date.now()}`
    await createCatalog(page, name)

    const renamed = `${name} v2`
    await page.locator('#catalog-name').fill(renamed)
    await saveCatalog(page)
    await expect(page.getByRole('heading', { name: renamed })).toBeVisible({ timeout: 15_000 })

    await page.reload()
    await expect(page.locator('#catalog-name')).toHaveValue(renamed, { timeout: 15_000 })
  })

  test('paginates the product picker and selects all matching search results', async ({ page }) => {
    const creds = await login(page)
    const productPrefix = `${FIXTURE_CATALOG_PICKER_PRODUCT_PREFIX} ${Date.now()}`
    const seededProductIds = await seedCatalogPickerProducts(
      page,
      creds.store_id,
      productPrefix,
      creds.accessToken,
    )

    try {
      await gotoIndex(page, CATALOGS_PATH(creds.store_id), CTA)

      const name = `E2E Catalog Picker ${Date.now()}`
      await createCatalog(page, name)

      await page.getByRole('button', { name: /add products/i }).click()
      const picker = page.getByRole('dialog')
      await expect(picker.getByRole('heading', { name: /add products to catalog/i })).toBeVisible()

      await picker.getByRole('searchbox').fill(productPrefix)

      const productButtons = picker.getByRole('button', {
        name: new RegExp(productPrefix, 'i'),
      })
      await expect(productButtons.first()).toBeVisible({ timeout: 15_000 })
      await expect(productButtons).toHaveCount(25, { timeout: 15_000 })

      await picker.getByRole('button', { name: /load more/i }).click()
      await expect(productButtons).toHaveCount(FIXTURE_CATALOG_PICKER_PRODUCT_COUNT, {
        timeout: 15_000,
      })

      await picker
        .getByRole('button', {
          name: new RegExp(`select all ${FIXTURE_CATALOG_PICKER_PRODUCT_COUNT} matches`, 'i'),
        })
        .click()
      await picker
        .getByRole('button', {
          name: new RegExp(`^add ${FIXTURE_CATALOG_PICKER_PRODUCT_COUNT}$`, 'i'),
        })
        .click()
      await expect(picker).toBeHidden({ timeout: 15_000 })

      await expect(page.getByText(/^new$/i)).toHaveCount(FIXTURE_CATALOG_PICKER_PRODUCT_COUNT, {
        timeout: 15_000,
      })
    } finally {
      await deleteCatalogPickerProducts(page, creds.store_id, creds.accessToken, seededProductIds)
    }
  })
})
