import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { expect, type Page, type Route, test } from '@playwright/test'
import { gotoIndex, login, withCustomFieldDefinition } from './helpers'
import { E2E_DIR } from './paths'
import { createProduct, mediaCard, PRODUCTS_PATH } from './products-helpers'

const MEDIA_PATH = (storeId: string) => `/${storeId}/products/media`
const FIXTURE_IMAGE = readFileSync(resolve(E2E_DIR, 'fixtures/test-image.png'))

/** Uploads the fixture image under a name of its own, so a search finds just this one. */
async function uploadImage(page: Page, name: string) {
  await page.locator('input[type="file"]').setInputFiles({
    name,
    mimeType: 'image/png',
    buffer: FIXTURE_IMAGE,
  })
  await expect(page.getByText(/1 file uploaded/i)).toBeVisible({ timeout: 20_000 })
}

async function findTile(page: Page, text: string) {
  await page.getByRole('searchbox').fill(text)
  const tile = page.getByRole('listitem').filter({ hasText: text }).getByRole('button')
  await expect(tile).toBeVisible({ timeout: 15_000 })
  return tile
}

/**
 * Holds GET requests for `ms`, to force the order in which reloads land. The
 * app may cancel a held request meanwhile (a newer refetch supersedes it); it
 * is already gone then, so letting it through is skipped.
 */
function holdGets(ms: number) {
  return async (route: Route) => {
    if (route.request().method() === 'GET') await new Promise((resolve) => setTimeout(resolve, ms))
    await route.continue().catch(() => {})
  }
}

/** A library image with a description of its own, for the product media card to show by name. */
async function uploadDescribedImage(page: Page, storeId: string) {
  await page.goto(MEDIA_PATH(storeId))
  await expect(page.getByRole('heading', { name: /^media$/i })).toBeVisible({ timeout: 15_000 })
  const stamp = Date.now()
  const name = `e2e-picked-${stamp}.png`
  const alt = `Library swatch ${stamp}`
  await uploadImage(page, name)
  await (await findTile(page, name)).click()
  const sheet = page.getByRole('dialog')
  await sheet.locator('#media-alt').fill(alt)
  await sheet.getByRole('button', { name: /^save$/i }).click()
  await expect(page.getByText(/^saved$/i).first()).toBeVisible({ timeout: 15_000 })
  await sheet.getByRole('button', { name: /^cancel$/i }).click()
  return { stamp, name, alt }
}

/** On a product's edit page, adds a library file through the picker. */
async function addFromLibrary(page: Page, name: string, alt: string) {
  await page.getByRole('button', { name: /add from library/i }).click()
  const picker = page.getByRole('dialog')
  await picker.getByPlaceholder(/search by name/i).fill(name)
  await picker.getByRole('button', { name: alt }).click()
  await picker.getByRole('button', { name: /^add selected$/i }).click()
  await expect(picker).toBeHidden()
  await expect(page.getByRole('img', { name: alt })).toBeVisible()
}

test.describe('media library', () => {
  test('lists files as rows and sorts them by name', async ({ page }) => {
    const creds = await login(page)
    await page.goto(MEDIA_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^media$/i })).toBeVisible({ timeout: 15_000 })
    const name = `e2e-sorted-${Date.now()}.png`
    await uploadImage(page, name)

    // A pick closes the view menu, and the row shows the file's details.
    await page.getByRole('button', { name: /^view$/i }).click()
    await page.getByRole('menuitemradio', { name: /^list view$/i }).click()
    await expect(page.getByRole('menu')).toBeHidden()
    const row = page.getByRole('listitem').filter({ hasText: name })
    await expect(row).toContainText(/png/i)
    await expect(row).toContainText(/not used yet/i)

    // Sorting is kept in the URL, like the page's filters. Name and size
    // order by the stored file rather than the media row, so the request
    // itself is checked: a failed sort leaves the previous rows on screen.
    const sortedBy = (field: string) =>
      page.waitForResponse(
        (r) =>
          r.url().includes('/media') &&
          new RegExp(`sort=(-|%2D)?${field}\\b`).test(r.url()) &&
          r.request().method() === 'GET',
      )
    await page.getByRole('button', { name: /^sort$/i }).click()
    let response = sortedBy('filename')
    await page.getByRole('menuitemradio', { name: /^file name$/i }).click()
    expect((await response).status()).toBe(200)
    await page.getByRole('menuitemradio', { name: /^ascending$/i }).click()
    await expect(page).toHaveURL(/sort=filename/)
    await expect(page).toHaveURL(/direction=asc/)

    response = sortedBy('byte_size')
    await page.getByRole('menuitemradio', { name: /^file size$/i }).click()
    expect((await response).status()).toBe(200)
    await expect(page).toHaveURL(/sort=byte_size/)
    await page.keyboard.press('Escape')
    await expect(row).toBeVisible()
  })

  test('uploads an image and describes it for screen readers', async ({ page }) => {
    const creds = await login(page)
    await page.goto(MEDIA_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^media$/i })).toBeVisible({ timeout: 15_000 })

    const name = `e2e-library-${Date.now()}.png`
    await uploadImage(page, name)

    await (await findTile(page, name)).click()
    const sheet = page.getByRole('dialog')
    await expect(sheet.getByRole('heading', { name })).toBeVisible()
    // Freshly uploaded, so nothing uses it yet.
    await expect(sheet.getByText(/not used anywhere/i)).toBeVisible()

    await sheet.locator('#media-alt').fill('A red test swatch')
    await sheet.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/^saved$/i).first()).toBeVisible({ timeout: 15_000 })
    // The grid captions a file by its description once it has one.
    await sheet.getByRole('button', { name: /^cancel$/i }).click()
    await expect(page.getByRole('listitem').filter({ hasText: 'A red test swatch' })).toBeVisible()
  })

  test('uploads into the library from the picker, finds it by filter and adds it', async ({
    page,
  }) => {
    const creds = await login(page)
    const stamp = Date.now()
    const name = `e2e-picker-upload-${stamp}.png`
    await createProduct(page, creds.store_id, `Picker upload ${stamp}`)

    await page.getByRole('button', { name: /add from library/i }).click()
    const picker = page.getByRole('dialog', { name: /media library/i })
    await picker.locator('input[type="file"]').setInputFiles({
      name,
      mimeType: 'image/png',
      buffer: FIXTURE_IMAGE,
    })
    // A new upload arrives picked, ready to add.
    const tile = picker.getByRole('button', { name: new RegExp(name) })
    await expect(tile).toHaveAttribute('aria-pressed', 'true', { timeout: 20_000 })

    // Not on any product yet, so the "not in use" filter keeps it, in the list view too.
    await picker.getByRole('button', { name: /^usage/i }).click()
    await page.getByRole('menuitemradio', { name: /^not in use$/i }).click()
    await picker.getByRole('button', { name: /^view$/i }).click()
    await page.getByRole('menuitemradio', { name: /^list view$/i }).click()
    await expect(picker.getByRole('button', { name: new RegExp(name) })).toHaveAttribute(
      'aria-pressed',
      'true',
    )

    await picker.getByRole('button', { name: /^add selected$/i }).click()
    await expect(picker).toBeHidden()
    await expect(page.getByRole('img', { name })).toBeVisible({ timeout: 15_000 })
  })

  test('a file added to a product from the library keeps its preview after saving', async ({
    page,
  }) => {
    // Uploads, picks and saves with reloads held back on purpose — longer
    // than the default budget, especially against a loaded CI runner.
    test.slow()
    const creds = await login(page)
    const { stamp, name, alt } = await uploadDescribedImage(page, creds.store_id)
    await createProduct(page, creds.store_id, `Library pick ${stamp}`)
    await addFromLibrary(page, name, alt)

    // After the save, the media list landing while the product is still
    // reloading is the ordering that blanked new tiles and refilled the form
    // from the pre-save product. Slowing both reloads makes it certain.
    const mediaReload = /\/api\/v3\/admin\/products\/prod_[^/?]+\/media(\?|$)/
    const productReload = /\/api\/v3\/admin\/products\/prod_[^/?]+\?/
    await page.route(mediaReload, holdGets(2_000))
    await page.route(productReload, holdGets(4_000))
    const renamed = `Library pick ${stamp} (renamed)`
    await page.getByLabel(/^name$/i).fill(renamed)
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByText(/product saved/i)).toBeVisible({ timeout: 30_000 })
    // Read once, without retrying: a form refilled from the pre-save product
    // shows the old name only until the slowed reload lands.
    expect(await page.getByLabel(/^name$/i).inputValue()).toBe(renamed)
    await expect(page.getByRole('img', { name: alt })).toBeVisible({ timeout: 15_000 })
    // A held request the app cancelled never completes, so drop the holds
    // without waiting on them before the reload below.
    await page.unrouteAll({ behavior: 'ignoreErrors' })

    await page.reload()
    await expect(page.getByRole('img', { name: alt })).toBeVisible({ timeout: 15_000 })
  })

  test('a new library file stays on the product when the media reload after saving fails', async ({
    page,
  }) => {
    // Uploads, picks and saves with reloads held back on purpose — longer
    // than the default budget, especially against a loaded CI runner.
    test.slow()
    const creds = await login(page)
    const { stamp, name, alt } = await uploadDescribedImage(page, creds.store_id)
    await createProduct(page, creds.store_id, `Library pick ${stamp}`)
    await addFromLibrary(page, name, alt)

    // The media reload fails, and the product reload lands after the save —
    // the order in which the form used to refill from the pre-save media.
    const mediaReload = /\/api\/v3\/admin\/products\/prod_[^/?]+\/media(\?|$)/
    const productReload = /\/api\/v3\/admin\/products\/prod_[^/?]+\?/
    await page.route(mediaReload, (route) =>
      route.request().method() === 'GET'
        ? route.fulfill({ status: 500, json: { error: { code: 'internal', message: 'boom' } } })
        : route.continue(),
    )
    await page.route(productReload, holdGets(3_000))
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByText(/product saved/i)).toBeVisible({ timeout: 30_000 })
    // A failed reload has nothing to show, so give the media retry and the
    // slowed product reload time to land before checking the form kept the
    // submitted tile.
    await page.waitForTimeout(5_000)
    await expect(page.getByRole('img', { name: alt })).toBeVisible()
    await page.unrouteAll({ behavior: 'ignoreErrors' })
  })

  // The probes in src/testing/slot-probes.tsx stand in for a plugin.
  test('a plugin field saves with the file and a plugin item joins the grid menu', async ({
    page,
  }) => {
    const creds = await login(page)
    await page.goto(MEDIA_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^media$/i })).toBeVisible({ timeout: 15_000 })

    const name = `e2e-slots-${Date.now()}.png`
    await uploadImage(page, name)

    const tile = await findTile(page, name)
    await tile.click({ button: 'right' })
    await expect(page.getByRole('menuitem', { name: 'Probe menu action' })).toBeVisible()
    await page.keyboard.press('Escape')

    await tile.click()
    const sheet = page.getByRole('dialog')
    await sheet.getByLabel('Probe library credit').fill('Photo by Jane')
    await sheet.getByRole('button', { name: /^save$/i }).click()
    await expect(page.getByText(/^saved$/i).first()).toBeVisible({ timeout: 15_000 })
    await sheet.getByRole('button', { name: /^cancel$/i }).click()

    await page.reload()
    await (await findTile(page, name)).click()
    await expect(page.getByRole('dialog').getByLabel('Probe library credit')).toHaveValue(
      'Photo by Jane',
    )
  })

  test('deletes a file from the grid after confirming', async ({ page }) => {
    const creds = await login(page)
    await page.goto(MEDIA_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^media$/i })).toBeVisible({ timeout: 15_000 })

    const name = `e2e-doomed-${Date.now()}.png`
    await uploadImage(page, name)

    await (await findTile(page, name)).click({ button: 'right' })
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete this file\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(page.getByText(/no files match your filters/i)).toBeVisible({ timeout: 15_000 })
  })

  // Usage references name their owner by short type (`product`), which is
  // what turns a placement into a link back to the record using the file.
  test('links a file to the product it is used on', async ({ page }) => {
    const creds = await login(page)
    const suffix = Date.now()
    const productName = `E2E Media Owner ${suffix}`
    const fileName = `e2e-used-${suffix}.png`

    await gotoIndex(page, PRODUCTS_PATH(creds.store_id), /add product/i)
    await page.getByRole('button', { name: /add product/i }).click()
    await expect(page.getByRole('heading', { name: /^new product$/i })).toBeVisible()
    await page.getByLabel(/^name$/i).fill(productName)
    await mediaCard(page)
      .locator('input[type="file"]')
      .setInputFiles({ name: fileName, mimeType: 'image/png', buffer: FIXTURE_IMAGE })
    await expect(mediaCard(page).locator('img[src]').first()).toBeVisible({ timeout: 15_000 })
    await expect(mediaCard(page).locator('.animate-spin')).toHaveCount(0, { timeout: 15_000 })
    await page.getByRole('button', { name: /^create product$/i }).click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 30_000,
    })

    await page.goto(MEDIA_PATH(creds.store_id))
    await expect(page.getByRole('heading', { name: /^media$/i })).toBeVisible({ timeout: 15_000 })
    await (await findTile(page, fileName)).click()
    const sheet = page.getByRole('dialog')
    const usage = sheet.getByRole('link', { name: productName })
    await expect(usage).toBeVisible({ timeout: 15_000 })

    await usage.click()
    await expect(page).toHaveURL(new RegExp(`/${creds.store_id}/products/prod_[^/]+$`), {
      timeout: 15_000,
    })
  })

  test('saves a custom field with the file, beside its alt text', async ({ page }) => {
    const creds = await login(page)
    await withCustomFieldDefinition(page, creds, 'media', async (label) => {
      await page.goto(MEDIA_PATH(creds.store_id))
      await expect(page.getByRole('heading', { name: /^media$/i })).toBeVisible({ timeout: 15_000 })
      const name = `e2e-custom-field-${Date.now()}.png`
      await uploadImage(page, name)

      await (await findTile(page, name)).click()
      const sheet = page.getByRole('dialog')
      await sheet.getByLabel(label).fill('Licensed until 2027')
      await sheet.getByRole('button', { name: /^save$/i }).click()
      await expect(page.getByText(/^saved$/i).first()).toBeVisible({ timeout: 15_000 })
      await sheet.getByRole('button', { name: /^cancel$/i }).click()

      await page.reload()
      await (await findTile(page, name)).click()
      await expect(page.getByRole('dialog').getByLabel(label)).toHaveValue('Licensed until 2027', {
        timeout: 15_000,
      })
    })
  })
})
