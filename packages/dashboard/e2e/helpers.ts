import { readFileSync } from 'node:fs'
import { expect, type Locator, type Page } from '@playwright/test'
import { CREDENTIALS_FILE } from './paths'

/** A CSV to hand to a file input, one row per entry. */
export function csvFile(rows: string[]) {
  return {
    name: `e2e-import-${Date.now()}.csv`,
    mimeType: 'text/csv',
    buffer: Buffer.from(`${rows.join('\n')}\n`),
  }
}

/**
 * Adds a quantity break to the first variant in an open price spreadsheet.
 * The blank rung under the variant appends a break; its quantity and price
 * are spreadsheet cells, read-only until double-clicked.
 */
export async function addQuantityBreak(grid: Locator, quantity: string, price: string) {
  await grid
    .getByRole('button', { name: /^add quantity break$/i })
    .first()
    .click()
  const quantityCell = grid.getByLabel(/^from quantity$/i).first()
  await quantityCell.dblclick()
  await quantityCell.fill(quantity)
  await quantityCell.press('Enter')
  const rungPrice = grid.getByLabel(new RegExp(`^price for from qty ${quantity}$`, 'i'))
  await expect(rungPrice).toBeVisible()
  await rungPrice.dblclick()
  await rungPrice.fill(price)
  await rungPrice.press('Enter')
}

/**
 * Fixture records seeded once in `global-setup.ts`. Specs that exercise
 * resource pickers (promotion rule/action editors, etc.) reference them
 * by name to make matching deterministic.
 */
export const FIXTURE_PROMO_TAXON = 'E2E Promo Category'
// Permalinks are unique per store, names are not — the seed looks fixtures up by
// permalink so it can never match an unrelated category.
export const FIXTURE_PROMO_TAXON_PERMALINK = 'e2e-promo-category'
export const FIXTURE_PROMO_PRODUCT = 'E2E Promo Product'
/** The promo product's SKU — what a price-list CSV row names a variant by. */
export const FIXTURE_PROMO_SKU = 'E2E-PROMO'
/** Name prefix for catalog picker pagination E2E products; each run appends a timestamp. */
export const FIXTURE_CATALOG_PICKER_PRODUCT_PREFIX = 'E2E Catalog Picker Product'

/** Count used by the catalog picker pagination/select-all E2E. */
export const FIXTURE_CATALOG_PICKER_PRODUCT_COUNT = 30

/**
 * Seed products for the catalog picker pagination test via the Admin API.
 * Kept out of global-setup so the extra rows do not push bulk-operation
 * fixtures off the products index first page (default limit 25, newest first).
 */
export async function seedCatalogPickerProducts(
  page: Page,
  storeId: string,
  prefix: string,
  accessToken: string,
  count = FIXTURE_CATALOG_PICKER_PRODUCT_COUNT,
): Promise<string[]> {
  const headers = {
    'X-Spree-Store-Id': storeId,
    Authorization: `Bearer ${accessToken}`,
  }

  const ids: string[] = []
  try {
    for (let index = 0; index < count; index += 1) {
      const name = `${prefix} ${String(index + 1).padStart(2, '0')}`
      const res = await page.request.post('/api/v3/admin/products', {
        headers,
        data: { name, status: 'active', price: '9.99' },
      })
      if (!res.ok()) {
        throw new Error(
          `Failed to seed catalog picker product "${name}": ${res.status()} ${await res.text()}`,
        )
      }
      const body = (await res.json()) as { id: string }
      ids.push(body.id)
    }
  } catch (error) {
    if (ids.length > 0) {
      await deleteCatalogPickerProducts(page, storeId, accessToken, ids).catch(() => undefined)
    }
    throw error
  }

  return ids
}

/** Remove picker seed rows so they do not push bulk fixtures off the products index. */
export async function deleteCatalogPickerProducts(
  page: Page,
  storeId: string,
  accessToken: string,
  productIds: string[],
) {
  const headers = {
    'X-Spree-Store-Id': storeId,
    Authorization: `Bearer ${accessToken}`,
  }

  await Promise.all(
    productIds.map(async (id) => {
      const res = await page.request.delete(`/api/v3/admin/products/${id}`, { headers })
      if (!res.ok()) {
        throw new Error(
          `Failed to delete catalog picker product ${id}: ${res.status()} ${await res.text()}`,
        )
      }
    }),
  )
}
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
// Dedicated category seeded for the bulk-add-to-categories test; a top-level
// store category alongside `FIXTURE_PROMO_TAXON`.
export const FIXTURE_BULK_CATEGORY = 'E2E Bulk Category'
export const FIXTURE_BULK_CATEGORY_PERMALINK = 'e2e-bulk-category'
// Second channel beyond the seeded default `online`. Used by the
// channels bulk-action and filter specs.
export const FIXTURE_BULK_CHANNEL_CODE = 'e2e-bulk'

/**
 * Inventory-operations fixtures. A transfer needs two warehouses and stock at
 * the source before it can ship, and neither is creatable from the transfer
 * screens themselves.
 */
export const FIXTURE_TRANSFER_SOURCE = 'E2E Source Warehouse'
export const FIXTURE_TRANSFER_DESTINATION = 'E2E Destination Warehouse'
export const FIXTURE_TRANSFER_PRODUCT = 'E2E Transfer Product'
/** Unique so the transfer specs can resolve exactly the stocked variant. */
export const FIXTURE_TRANSFER_SKU = 'E2E-TRANSFER-SKU'
export const FIXTURE_SUPPLIER = 'E2E Supplier'
// The Inventory page: a SKU of its own so the figures it asserts are not
// moved by the transfer specs, stocked at the source and held by one
// checkout at the destination.
export const FIXTURE_INVENTORY_PRODUCT = 'E2E Inventory Product'
export const FIXTURE_INVENTORY_SKU = 'E2E-INVENTORY-SKU'
export const FIXTURE_INVENTORY_RESERVED = 3
export const FIXTURE_BULK_CHANNEL_NAME = 'E2E Bulk Channel'
/**
 * A seller with one settled sale and one payout still owed, so the ledger
 * screens have rows without a spec having to place and fulfil an order first.
 */
export const FIXTURE_LEDGER_SELLER = 'E2E Ledger Seller'
/** The settled payout the read-only specs assert against. */
export const FIXTURE_LEDGER_PAYOUT_AMOUNT = '120.0'
/**
 * A second payout, owed, for the mark-as-paid spec to consume. Separate from
 * the one above so completing it cannot change what another spec reads —
 * the suite is serial, and CI splits it across shards.
 */
export const FIXTURE_LEDGER_OWED_AMOUNT = '75.0'

/**
 * Seller panel accounts. `FIXTURE_SELLER_USER_EMAIL` runs the ledger seller, so
 * the panel's read-only screens have a sale and payouts to show;
 * `FIXTURE_SELLER_WRITER_EMAIL` runs `FIXTURE_PANEL_SELLER`, which the specs
 * that edit a profile, policy or team may change without moving what another
 * spec reads.
 */
export const FIXTURE_SELLER_USER_EMAIL = 'e2e-ledger-seller@example.com'
export const FIXTURE_SELLER_WRITER_EMAIL = 'e2e-panel-seller@example.com'
export const FIXTURE_SELLER_PASSWORD = 'spree123'
export const FIXTURE_PANEL_SELLER = 'E2E Panel Seller'

/** The marketplace seller panel, its own app on its own origin (see playwright.config.ts). */
export const SELLER_PANEL = `http://localhost:${process.env.E2E_SELLER_VITE_PORT || '5175'}`

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
  /** A store whose market writes a comma decimal (nl) and prices in EUR. */
  comma_store_id: string
}

/** Credentials plus the JWT from the login response (Admin API Bearer auth). */
export type E2ELoginSession = E2ECredentials & { accessToken: string }

let cached: E2ECredentials | null = null

export function getCredentials(): E2ECredentials {
  if (!cached) {
    cached = JSON.parse(readFileSync(CREDENTIALS_FILE, 'utf-8'))
  }
  return cached
}

/**
 * Establish an authenticated admin session as a precondition for any spec
 * that needs one. Returns the credentials so callers can immediately
 * navigate into a specific store (e.g. `/${creds.store_id}/products/options`).
 *
 * Logs in through the API rather than the login form: the POST plants the
 * refresh-token cookie in this context's cookie jar (`page.request` shares
 * it), and the SPA's boot-time silent refresh turns that into a session on
 * the next navigation. This skips a full SPA boot + form roundtrip per test.
 * A shared Playwright `storageState` can't do this cheaper — refresh tokens
 * are single-use (rotated on every refresh), so each context needs its own.
 *
 * Not used by `auth.spec.ts` — that spec exercises the login form itself.
 */
export async function login(page: Page): Promise<E2ELoginSession> {
  const creds = getCredentials()
  const res = await page.request.post('/api/v3/admin/auth/login', {
    data: { email: creds.admin_email, password: creds.admin_password },
  })
  if (!res.ok()) {
    throw new Error(`API login failed with ${res.status()}: ${await res.text()}`)
  }
  const { token: accessToken } = (await res.json()) as { token: string }
  if (!accessToken) {
    throw new Error('API login response missing token')
  }
  await page.goto('/')
  // Wait for the authenticated redirect to the store-scoped home — not just
  // "left /login", which is trivially true at `/` while the boot refresh is
  // still in flight. Returning early lets the spec's next `page.goto` boot a
  // second SPA instance that refreshes with the same single-use cookie; the
  // loser of that race gets a 401 that clears the cookie and bounces the
  // page to /login. The redirect only fires after auth init settles, so it
  // doubles as the refresh-complete barrier.
  await expect(page).toHaveURL(new RegExp(`/${creds.store_id}`), { timeout: 15_000 })
  return { ...creds, accessToken }
}

/**
 * The seller panel's counterpart to `login`: signs in through the Seller API,
 * then opens the panel and waits until it has settled on the seller's own
 * home — the same single-use refresh-cookie race `login` guards against.
 *
 * @returns The seller panel URL of the seller's home, e.g. `.../sel_x`.
 */
export async function sellerLogin(
  page: Page,
  email: string = FIXTURE_SELLER_USER_EMAIL,
): Promise<string> {
  const res = await page.request.post(`${SELLER_PANEL}/api/v3/seller/auth/login`, {
    data: { email, password: FIXTURE_SELLER_PASSWORD },
  })
  if (!res.ok()) {
    throw new Error(`Seller API login failed with ${res.status()}: ${await res.text()}`)
  }
  await page.goto(SELLER_PANEL)
  await expect(page).toHaveURL(/\/sel_[^/]+$/, { timeout: 20_000 })
  return page.url()
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
 * Open the edit-profile dialog from the top-bar user menu. The profile has no
 * page of its own, so every profile assertion starts here.
 *
 * @param menuLabel Accessible name of the user-menu button — pass a translated
 *   pattern when the dashboard is running in another language.
 * @param itemLabel Accessible name of the "Edit profile" menu item.
 */
export async function openProfileDialog(
  page: Page,
  menuLabel: RegExp = /user menu/i,
  itemLabel: RegExp = /edit profile/i,
) {
  await page.getByRole('button', { name: menuLabel }).click()
  await page.getByRole('menuitem', { name: itemLabel }).click()
  await expect(page.locator('#profile-first-name')).toBeVisible({ timeout: 15_000 })
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
 * Wait for every toast to leave. Toasts stack over the bottom-right corner,
 * where the last row's action menu sits, and a toast under the pointer pauses
 * its own timer — so the pointer is moved away first, or a click aimed at that
 * row can wait on it forever.
 */
export async function waitForToastsToClear(page: Page) {
  await page.mouse.move(0, 0)
  await expect(page.locator('[role="status"][data-type]')).toHaveCount(0, { timeout: 15_000 })
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

/**
 * Escapes regex metacharacters so a dynamic value (a generated name, an email
 * address) matches literally inside a `RegExp` locator.
 */
export function escapeRegex(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
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
 * The country and state pickers are button-triggered comboboxes: open the
 * field, type into the search box inside the popup, then click the option.
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
    await page.locator('#addr-country').click()
    await page.getByPlaceholder(/^search countries/i).fill(address.country)
    await page.getByRole('option', { name: address.country }).first().click()
  }
  if (address.state) {
    await page.locator('#addr-state').click()
    await page.getByPlaceholder(/^search states/i).fill(address.state)
    await page.getByRole('option', { name: address.state }).first().click()
  }
}

/**
 * Opens a transfer of `quantity` units of `sku` from the fixture source
 * warehouse to the fixture destination and marks it in transit, through the
 * API: the trip's middle is what these specs test, not the two warehouse
 * selects on the form. By SKU, not by search, so it resolves exactly the
 * variant whose stock global-setup put on the source shelf.
 */
export async function createInTransitTransfer(
  page: Page,
  accessToken: string,
  { sku, quantity }: { sku: string; quantity: number },
) {
  const headers = { Authorization: `Bearer ${accessToken}` }

  const locations = await page.request
    .get('/api/v3/admin/stock_locations', { headers, params: { limit: 100 } })
    .then((res) => res.json())
  const source = locations.data.find((l: { name: string }) => l.name === FIXTURE_TRANSFER_SOURCE)
  const destination = locations.data.find(
    (l: { name: string }) => l.name === FIXTURE_TRANSFER_DESTINATION,
  )

  const variants = await page.request
    .get('/api/v3/admin/variants', { headers, params: { 'q[sku_eq]': sku } })
    .then((res) => res.json())
  expect(variants.data, `no variant with SKU ${sku}`).not.toHaveLength(0)

  const created = await page.request.post('/api/v3/admin/stock_transfers', {
    headers,
    data: {
      source_location_id: source.id,
      destination_location_id: destination.id,
      reference: `E2E ${sku} ${Date.now()}`,
      items: [{ variant_id: variants.data[0].id, quantity_shipped: quantity }],
    },
  })
  expect(created.status(), await created.text()).toBe(201)
  const transfer = await created.json()

  const shipped = await page.request.patch(
    `/api/v3/admin/stock_transfers/${transfer.id}/mark_in_transit`,
    { headers },
  )
  expect(shipped.status(), await shipped.text()).toBe(200)

  return transfer
}

/**
 * The path an invitee opens to accept an invitation. The link carries the
 * invitation's token, so the listing never includes it; this fetches it the way
 * the "copy link" action does. `invitationPath` is the invitation's API path,
 * e.g. `/api/v3/admin/invitations/inv_x` or `/api/v3/admin/sellers/seller_x/invitations/inv_x`.
 */
export async function invitationAcceptancePath(
  page: Page,
  session: E2ELoginSession,
  invitationPath: string,
): Promise<string> {
  const res = await page.request.get(`${invitationPath}/acceptance_link`, {
    headers: {
      'X-Spree-Store-Id': session.store_id,
      Authorization: `Bearer ${session.accessToken}`,
    },
  })
  if (!res.ok()) {
    throw new Error(`Acceptance link request failed with ${res.status()}: ${await res.text()}`)
  }
  const { acceptance_url } = (await res.json()) as { acceptance_url: string }
  // Tolerate either path-only (no app origin configured) or an absolute URL.
  return acceptance_url.replace(/^https?:\/\/[^/]+/, '')
}

/**
 * A placed, paid and shipped order for the fixture customer, built through the
 * API — returns and claims can only be raised against goods that left. Paid
 * with store credit, because that is the payment method every seeded store
 * has; it also saves spec time over driving checkout.
 */
export async function createShippedOrder(page: Page, accessToken: string, quantity = 2) {
  return createPlacedOrder(page, accessToken, { quantity })
}

/**
 * Places an order for the promo customer, paid by store credit, and ships it
 * unless `ship` is false. `firstName` / `lastName` set the billing name, so a
 * list test can tell its own orders apart from everyone else's.
 */
export async function createPlacedOrder(
  page: Page,
  accessToken: string,
  { quantity = 2, ship = true, firstName = 'Promo', lastName = 'Customer' } = {},
) {
  const headers = { Authorization: `Bearer ${accessToken}` }
  const request = async (method: 'get' | 'post' | 'patch', path: string, data?: object) => {
    const res = await page.request[method](path, { headers, data })
    expect(res.ok(), `${method.toUpperCase()} ${path}: ${await res.text()}`).toBeTruthy()
    return res.json()
  }

  const customers = await request(
    'get',
    `/api/v3/admin/customers?q[email_eq]=${encodeURIComponent(FIXTURE_PROMO_CUSTOMER_EMAIL)}`,
  )
  const customerId = customers.data[0].id
  const variants = await request('get', `/api/v3/admin/variants?q[sku_eq]=${FIXTURE_PROMO_SKU}`)
  const address = {
    first_name: firstName,
    last_name: lastName,
    address1: '1 Main St',
    city: 'Los Angeles',
    country_code: 'US',
    state_code: 'CA',
    postal_code: '90001',
    phone: '5555555555',
  }

  const order = await request('post', '/api/v3/admin/orders', {
    customer_id: customerId,
    items: [{ variant_id: variants.data[0].id, quantity }],
    shipping_address: address,
    billing_address: address,
  })
  await request('post', `/api/v3/admin/customers/${customerId}/store_credits`, {
    amount: order.total,
    currency: order.currency,
    memo: `E2E payment for ${order.number}`,
  })
  await request('post', `/api/v3/admin/orders/${order.id}/store_credits`)
  await request('patch', `/api/v3/admin/orders/${order.id}/complete`)

  const fulfillments = await request('get', `/api/v3/admin/orders/${order.id}/fulfillments`)
  for (const fulfillment of ship ? fulfillments.data : []) {
    await request(
      'patch',
      `/api/v3/admin/orders/${order.id}/fulfillments/${fulfillment.id}/fulfill`,
    )
  }

  return order as { id: string; number: string; total: string }
}

/**
 * An Admin API call as the signed-in admin, for seeding the records a list
 * test filters. Fails the test with the response body when the call fails.
 */
export async function adminRequest<T = Record<string, unknown>>(
  page: Page,
  session: E2ELoginSession,
  method: 'get' | 'post' | 'patch' | 'delete',
  path: string,
  data?: object,
): Promise<T> {
  const res = await page.request[method](`/api/v3/admin${path}`, {
    headers: {
      Authorization: `Bearer ${session.accessToken}`,
      'X-Spree-Store-Id': session.store_id,
    },
    data,
  })
  expect(res.ok(), `${method.toUpperCase()} ${path}: ${await res.text()}`).toBeTruthy()
  return (res.status() === 204 ? {} : await res.json()) as T
}

/** Types into a list's search box. */
export async function searchList(page: Page, placeholder: RegExp, text: string) {
  await page.getByPlaceholder(placeholder).fill(text)
}

/**
 * Adds a typed filter from the list's Add filter panel: a text, number or
 * date field, an operator, then the value.
 */
export async function addTextFilter(page: Page, field: RegExp, operator: RegExp, value: string) {
  await page.getByRole('button', { name: /add filter/i }).click()
  await page.locator('[data-slot="filter-panel-item"]').getByText(field).click()
  const controls = page.locator('[data-slot="filter-panel-controls"]')
  await controls.getByRole('combobox').click()
  await page.getByRole('option', { name: operator }).click()
  await controls.getByPlaceholder(/filter…/i).fill(value)
  await controls.getByRole('button', { name: /^apply$/i }).click()
  await expect(controls).toBeHidden()
}

/** Adds a filter whose values are listed (a status, yes or no) by picking one. */
export async function addListFilter(page: Page, field: RegExp, value: RegExp) {
  await page.getByRole('button', { name: /add filter/i }).click()
  const items = page.locator('[data-slot="filter-panel-item"]')
  await items.getByText(field).click()
  await items.getByText(value).click()
}

/** Adds a filter on related records (categories, tags) by searching for one and ticking it. */
export async function addRecordFilter(page: Page, field: RegExp, value: string) {
  await page.getByRole('button', { name: /add filter/i }).click()
  await page.locator('[data-slot="filter-panel-item"]').getByText(field).click()
  await page.getByPlaceholder(/filter to…/i).fill(value)
  await page.getByRole('button', { name: value }).click()
  await page.keyboard.press('Escape')
}

/**
 * Narrows a quick filter in the toolbar to one value. Every value starts
 * ticked, so narrowing means unticking the rest.
 */
export async function narrowQuickFilter(page: Page, trigger: RegExp, keep: RegExp) {
  await page.getByRole('button', { name: trigger }).click()
  const items = page.getByRole('menuitemcheckbox')
  await expect(items.first()).toBeVisible()
  for (const item of await items.all()) {
    const name = (await item.textContent()) ?? ''
    if (!keep.test(name.trim()) && (await item.getAttribute('aria-checked')) === 'true') {
      await item.click()
    }
  }
  await page.keyboard.press('Escape')
}

/** Sorts a list by one of its columns, through the toolbar's Sort menu. */
export async function sortList(page: Page, field: RegExp, direction: 'ascending' | 'descending') {
  const trigger = page.getByRole('button', { name: /^sort$/i })
  await trigger.click()
  await page.getByRole('menuitemradio', { name: field }).click()
  const order = page.getByRole('menuitemradio', { name: new RegExp(`^${direction}$`, 'i') })
  if (!(await order.isVisible())) await trigger.click()
  await order.click()
  await page.keyboard.press('Escape')
}

/**
 * Switches the shared admin account and this browser to a dashboard language
 * together, and returns a function that hands the account back its previous
 * language. Call it before the page next loads (before `login`, or before a
 * `reload`), and the returned function in `afterEach`.
 *
 * Both must agree: when they differ the auth provider reloads to bring the
 * browser in line with the account, and a reload during the boot refresh
 * spends the single-use cookie twice — the loser is bounced to `/`
 * unauthenticated. Other specs leave the shared account on whatever language
 * they last saved, so this cannot assume it is unset.
 */
export async function switchAdminLocale(page: Page, locale: string): Promise<() => Promise<void>> {
  const authHeaders = async () => {
    const creds = getCredentials()
    const res = await page.request.post('/api/v3/admin/auth/login', {
      data: { email: creds.admin_email, password: creds.admin_password },
    })
    const { token } = (await res.json()) as { token: string }
    return { Authorization: `Bearer ${token}` }
  }

  await page.addInitScript((value) => localStorage.setItem('spree-admin-locale', value), locale)
  const headers = await authHeaders()
  const me = await page.request.get('/api/v3/admin/me', { headers })
  const saved = ((await me.json()) as { user: { selected_locale: string | null } }).user
    .selected_locale
  await page.request.patch('/api/v3/admin/me', { headers, data: { selected_locale: locale } })

  return async () => {
    await page.request.patch('/api/v3/admin/me', {
      headers: await authHeaders(),
      data: { selected_locale: saved },
    })
  }
}

// Records a list test seeded, deleted after the test so later specs in the
// shard see the store they expect (the products index's first page, the
// payment-method picker's providers).
let seededRecords: { path: string; session: E2ELoginSession }[] = []

/** Creates a record through the Admin API and deletes it after the test. */
export async function seedRecord<T extends { id: string } = { id: string }>(
  page: Page,
  session: E2ELoginSession,
  path: string,
  data: object,
): Promise<T> {
  const record = await adminRequest<T>(page, session, 'post', path, data)
  seededRecords.push({ path: `${path}/${record.id}`, session })
  return record
}

/** Deletes what {@link seedRecord} created; call from `test.afterEach`. */
export async function deleteSeededRecords(page: Page) {
  for (const { path, session } of seededRecords.reverse()) {
    await adminRequest(page, session, 'delete', path).catch(() => undefined)
  }
  seededRecords = []
}
