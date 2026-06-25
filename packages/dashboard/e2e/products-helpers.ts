import { expect, type Locator, type Page } from '@playwright/test'
import { gotoIndex } from './helpers'

/** Storefront-equivalent route paths used by the products specs. */
export const PRODUCTS_PATH = (storeId: string) => `/${storeId}/products`
export const OPTIONS_PATH = (storeId: string) => `/${storeId}/products/options`

/**
 * Drive the New Product form and land on the edit page. The minimum input the
 * form accepts is a name — pass a `description` when the spec specifically
 * verifies how rich-text data round-trips. The description field is a tiptap
 * `RichTextEditor` (contenteditable), not a textarea, so `.fill()` is wrong;
 * we click to focus and `keyboard.type` instead.
 */
export async function createProduct(
  page: Page,
  storeId: string,
  name: string,
  description?: string,
): Promise<void> {
  await gotoIndex(page, PRODUCTS_PATH(storeId), /add product/i)
  await page.getByRole('button', { name: /add product/i }).click()
  await expect(page.getByRole('heading', { name: /^new product$/i })).toBeVisible()
  await page.getByLabel(/^name$/i).fill(name)
  if (description) {
    const editor = page.getByLabel(/^description$/i)
    await editor.click()
    await page.keyboard.type(description)
  }
  await page.getByRole('button', { name: /^create product$/i }).click()
  // Lands on `/$storeId/products/$productId` (not `/new`).
  await expect(page).toHaveURL(new RegExp(`/${storeId}/products/prod_[^/]+$`), { timeout: 15_000 })
}

/**
 * Drive the New Option Type sheet to create a fresh option type with the given
 * value rows. Returns the human-readable label the test can match in pickers
 * (e.g. the Variants card's option-type combobox). Each call generates a
 * timestamped suffix so concurrent specs don't collide.
 */
export async function seedOptionType(
  page: Page,
  storeId: string,
  baseName: string,
  values: string[],
): Promise<string> {
  const suffix = Date.now() + Math.floor(Math.random() * 1000)
  const internalName = `${baseName}-${suffix}`
  const label = `E2E ${baseName.charAt(0).toUpperCase() + baseName.slice(1)} ${suffix}`

  await gotoIndex(page, OPTIONS_PATH(storeId), /add option type/i)
  await page.getByRole('button', { name: /add option type/i }).click()
  await expect(page.getByRole('heading', { name: /create option type/i })).toBeVisible()
  await page.locator('#label').fill(label)
  await page.locator('#name').fill(internalName)

  for (const [i, value] of values.entries()) {
    await page.getByRole('button', { name: /add option value/i }).click()
    const row = page
      .locator('tbody tr')
      .filter({ has: page.getByLabel('Internal name') })
      .nth(i)
    await row.getByLabel('Internal name').fill(value)
    await row.getByLabel('Label').fill(value.charAt(0).toUpperCase() + value.slice(1))
  }

  await page.getByRole('button', { name: /create option type/i }).click()
  await expect(page.getByRole('heading', { name: /create option type/i })).toBeHidden({
    timeout: 15_000,
  })
  return label
}

/**
 * Add an option type (already seeded) plus a set of value toggles to the
 * currently-open product's Variants card, then confirm. Scoped to the
 * Variants card by title so it doesn't fight the page-level "Add" buttons.
 */
export async function addOptionToVariants(
  page: Page,
  optionTypeLabel: string,
  valueLabels: string[],
): Promise<void> {
  const card = variantsCard(page)
  await card.getByRole('button', { name: /add option/i }).click()
  // Base UI Select renders the selected value as the trigger label, so we
  // open the listbox and click an item by name rather than typing.
  await card.getByRole('combobox').first().click()
  await page.getByRole('option', { name: optionTypeLabel, exact: true }).click()
  for (const label of valueLabels) {
    await card.getByRole('button', { name: label, exact: true }).click()
  }
  await card.getByRole('button', { name: /^done$/i }).click()
}

/**
 * Scope a locator to the product edit page's named card. `<CardTitle>` is a
 * `<div>` (not a heading), so we anchor on the `data-slot` shadcn emits.
 * Title matches are exact to avoid catching "Categorization" when the caller
 * asked for "Categories" or similar prefix collisions.
 */
function card(page: Page, title: RegExp): Locator {
  return page
    .locator('[data-slot="card"]')
    .filter({ has: page.locator('[data-slot="card-title"]', { hasText: title }) })
}

export const variantsCard = (page: Page) => card(page, /^Variants$/)
export const mediaCard = (page: Page) => card(page, /^Media$/)

/**
 * Click a hover-revealed action on the first media thumbnail. Scrolls the
 * Media card below the sticky TopBar + PageHeader stack first — restoring
 * sticky headers (PR #14218) made Playwright's default scroll-into-view land
 * the bottom overlay buttons under the header chrome.
 */
export async function clickMediaThumbnailAction(
  media: Locator,
  action: 'edit' | 'delete',
): Promise<void> {
  const thumb = media.locator('img[src]').first()
  const button = media.getByRole('button', {
    name: action === 'edit' ? /^edit image$/i : /^delete image$/i,
  })

  await thumb.scrollIntoViewIfNeeded()
  // Keep the card below the stacked sticky TopBar + PageHeader. Playwright's
  // default click scrolls the target back into view, so we also force-click
  // after hover — otherwise the header chrome intercepts pointer events.
  await media.evaluate((el) => {
    const headerHeight =
      Number.parseFloat(
        getComputedStyle(document.documentElement).getPropertyValue('--spacing-header-height'),
      ) || 58
    const stickyOffset = headerHeight * 2 + 24
    const top = el.getBoundingClientRect().top
    if (top < stickyOffset) window.scrollBy(0, top - stickyOffset)
  })

  await thumb.hover()
  await expect(button).toBeVisible()
  await button.click({ force: true })
}
export const customFieldsCard = (page: Page) => card(page, /^Custom fields$/)
export const inventoryCard = (page: Page) => card(page, /^Inventory$/)
export const pricesCard = (page: Page) => card(page, /^Prices$/)
export const publishingCard = (page: Page) => card(page, /^Publishing$/)
