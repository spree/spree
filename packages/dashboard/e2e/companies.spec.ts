import { expect, type Page, test } from '@playwright/test'
import {
  FIXTURE_PROMO_CUSTOMER_EMAIL,
  fillAddressForm,
  gotoIndex,
  login,
  openRowMenu,
  rowButton,
  saveCustomFieldOnCard,
  withCustomFieldDefinition,
} from './helpers'

const COMPANIES_PATH = (storeId: string) => `/${storeId}/companies`
const CTA = /add company/i

/** One of the detail page's cards, found by its title. */
function card(page: Page, title: RegExp) {
  return page
    .locator('[data-slot="card"]')
    .filter({ has: page.locator('[data-slot="card-title"]', { hasText: title }) })
}

/** Creates a company from the list; creating opens its page. */
async function createCompany(page: Page, storeId: string, name: string) {
  await gotoIndex(page, COMPANIES_PATH(storeId), CTA)
  await page.getByRole('button', { name: CTA }).click()
  await expect(page.getByRole('heading', { name: /^new company$/i })).toBeVisible()
  await page.locator('#name').fill(name)
  await page.getByRole('button', { name: /create company/i }).click()

  await expect(page).toHaveURL(/\/companies\/[a-z]+_/, { timeout: 15_000 })
  await expect(page.getByRole('heading', { name })).toBeVisible()
}

/** Adds an address to the open company's address book through its sheet. */
async function addCompanyAddress(page: Page, label: string, address1: string) {
  await card(page, /^address book/i)
    .getByRole('button', { name: /add address/i })
    .click()
  await expect(page.getByRole('heading', { name: /^new address$/i })).toBeVisible()
  await fillAddressForm(page, {
    label,
    address1,
    city: 'Los Angeles',
    postalCode: '90001',
    // Country starts at the store's own, the United States.
    state: 'California',
  })
  await page
    .getByRole('dialog')
    .getByRole('button', { name: /^save$/i })
    .click()
}

test.describe('companies', () => {
  test('creates a company and requires PO numbers on its orders', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Acme ${Date.now()}`
    await createCompany(page, creds.store_id, name)

    const profile = card(page, /^company$/i)
    await profile.getByRole('switch', { name: /require a po number/i }).click()
    await profile.getByRole('button', { name: /^save$/i }).click()
    await expect(profile.getByRole('button', { name: /^save$/i })).toBeDisabled({
      timeout: 15_000,
    })

    await page.reload()
    await expect(
      card(page, /^company$/i).getByRole('switch', { name: /require a po number/i }),
    ).toBeChecked({ timeout: 15_000 })
  })

  test('adds a division under a company', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Holdings ${Date.now()}`
    await createCompany(page, creds.store_id, name)

    const subUnits = card(page, /sub-units/i)
    await expect(subUnits.getByText(/no sub-units yet/i)).toBeVisible()
    await subUnits.getByRole('button', { name: /add sub-unit/i }).click()
    const dialog = page.getByRole('dialog')
    await dialog.locator('#sub-unit-name').fill(`${name} West`)
    await dialog.getByRole('button', { name: /^create$/i }).click()

    const division = subUnits.getByRole('link', { name: new RegExp(`${name} West`) })
    await expect(division).toBeVisible({ timeout: 15_000 })
    await expect(division.getByText(/^division$/i)).toBeVisible()

    // The sub-unit is a node of its own, reached from its parent.
    await division.click()
    await expect(page.getByRole('heading', { name: `${name} West` })).toBeVisible({
      timeout: 15_000,
    })
  })

  test('adds an existing customer as a member and removes them', async ({ page }) => {
    const creds = await login(page)
    await createCompany(page, creds.store_id, `E2E Buyers ${Date.now()}`)

    const members = card(page, /^members/i)
    await members.getByRole('button', { name: /add member/i }).click()
    await page.locator('#member-email').fill(FIXTURE_PROMO_CUSTOMER_EMAIL)
    await page.getByRole('dialog').getByRole('button', { name: /^add$/i }).click()

    const member = members.getByRole('link', { name: FIXTURE_PROMO_CUSTOMER_EMAIL })
    await expect(member).toBeVisible({ timeout: 15_000 })

    await members.getByRole('button', { name: /actions/i }).click()
    await page.getByRole('menuitem', { name: /remove member/i }).click()
    await expect(page.getByRole('heading', { name: /remove this member\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /remove member/i })
      .click()

    await expect(member).toHaveCount(0, { timeout: 15_000 })
    await expect(members.getByText(/no members yet/i)).toBeVisible()
  })

  test('invites an email with no account, then revokes the invitation', async ({ page }) => {
    const creds = await login(page)
    await createCompany(page, creds.store_id, `E2E Invites ${Date.now()}`)

    const email = `e2e-company-buyer-${Date.now()}@example.com`
    const members = card(page, /^members/i)
    await members.getByRole('button', { name: /add member/i }).click()
    await page.locator('#member-email').fill(email)
    await page.getByRole('dialog').getByRole('button', { name: /^add$/i }).click()

    await expect(members.getByText(/pending invitations/i)).toBeVisible({ timeout: 15_000 })
    await expect(members.getByText(email)).toBeVisible()

    await members.getByRole('button', { name: /revoke invitation/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /revoke invitation/i })
      .click()

    await expect(members.getByText(email)).toHaveCount(0, { timeout: 15_000 })
  })

  test('requires a state when saving a company address for the United States', async ({ page }) => {
    const creds = await login(page)
    await createCompany(page, creds.store_id, `E2E Austin ${Date.now()}`)

    const addressBook = card(page, /^address book/i)
    await addressBook.getByRole('button', { name: /add address/i }).click()
    await expect(page.getByRole('heading', { name: /^new address$/i })).toBeVisible()
    await fillAddressForm(page, {
      address1: '1 Test Street',
      city: 'Austin',
      postalCode: '78701',
    })
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()

    await expect(page.getByText(/state \/ province (is required|can't be blank)/i)).toBeVisible({
      timeout: 15_000,
    })
    await expect(addressBook.getByText('1 Test Street')).toHaveCount(0)
  })

  test('adds, edits, promotes to default and deletes addresses', async ({ page }) => {
    const creds = await login(page)
    await createCompany(page, creds.store_id, `E2E Depots ${Date.now()}`)

    const addressBook = card(page, /^address book/i)
    await expect(addressBook.getByText(/no addresses yet/i)).toBeVisible()
    await addCompanyAddress(page, 'Main warehouse', '400 Dock Rd')
    await expect(addressBook.getByText('400 Dock Rd')).toBeVisible({ timeout: 15_000 })

    await addressBook.getByRole('button', { name: /open actions/i }).click()
    await page.getByRole('menuitem', { name: /^edit$/i }).click()
    await expect(page.getByRole('heading', { name: /^edit address$/i })).toBeVisible()
    await fillAddressForm(page, { label: 'North warehouse' })
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()
    await expect(addressBook.getByText('North warehouse')).toBeVisible({ timeout: 15_000 })

    // A new address is saved as both defaults, so adding a second takes them
    // over and leaves the first to be promoted back.
    await addCompanyAddress(page, 'Dock 2', '500 Pier Ave')
    const first = addressBook.locator('[data-slot="item"]').filter({ hasText: '400 Dock Rd' })
    const second = addressBook.locator('[data-slot="item"]').filter({ hasText: '500 Pier Ave' })
    await expect(second.getByText(/^default shipping$/i)).toBeVisible({ timeout: 15_000 })
    await expect(first.getByText(/^default shipping$/i)).toHaveCount(0)
    await first.getByRole('button', { name: /open actions/i }).click()
    await page.getByRole('menuitem', { name: /set as default shipping/i }).click()
    await expect(first.getByText(/^default shipping$/i)).toBeVisible({ timeout: 15_000 })
    await expect(second.getByText(/^default shipping$/i)).toHaveCount(0)

    await second.getByRole('button', { name: /open actions/i }).click()
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await expect(page.getByRole('heading', { name: /delete this address\?/i })).toBeVisible()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()
    await expect(addressBook.getByText('500 Pier Ave')).toHaveCount(0, { timeout: 15_000 })
    await expect(addressBook.getByText('400 Dock Rd')).toBeVisible()
  })

  // A division ships to the sites it inherits, but they stay its parent's to
  // change: the row names where it comes from and offers no actions.
  test("shows a parent's address on a division as inherited and read-only", async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Parent ${Date.now()}`
    await createCompany(page, creds.store_id, name)
    await addCompanyAddress(page, 'Headquarters', '1 Main St')
    await expect(card(page, /^address book/i).getByText('1 Main St')).toBeVisible({
      timeout: 15_000,
    })

    const subUnits = card(page, /sub-units/i)
    await subUnits.getByRole('button', { name: /add sub-unit/i }).click()
    await page.getByRole('dialog').locator('#sub-unit-name').fill(`${name} West`)
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^create$/i })
      .click()
    await subUnits.getByRole('link', { name: new RegExp(`${name} West`) }).click()
    await expect(page.getByRole('heading', { name: `${name} West` })).toBeVisible({
      timeout: 15_000,
    })

    const addressBook = card(page, /^address book/i)
    await expect(addressBook.getByText('1 Main St')).toBeVisible({ timeout: 15_000 })
    await expect(addressBook.getByText(`Inherited from ${name}`)).toBeVisible()
    await expect(addressBook.getByRole('button', { name: /open actions/i })).toHaveCount(0)
  })

  // The document goes to private storage: a PDF is refused by the public
  // allowlist, so this fails if the field ever uploads publicly again.
  test('adds a tax exemption certificate with a PDF document', async ({ page }) => {
    const creds = await login(page)
    await createCompany(page, creds.store_id, `E2E Exempt ${Date.now()}`)

    const certificates = card(page, /exemption certificates/i)
    await certificates.getByRole('button', { name: /add certificate/i }).click()
    const sheet = page.getByRole('dialog')
    await expect(sheet.getByText(/add exemption certificate/i)).toBeVisible()

    const certificateNumber = `RESALE-${Date.now()}`
    await sheet.locator('#certificate_number').fill(certificateNumber)
    await sheet.locator('#tax_exemption_reason_id').click()
    await page.getByRole('option', { name: /^resale$/i }).click()
    await sheet.locator('input[type="file"]').setInputFiles({
      name: 'certificate.pdf',
      mimeType: 'application/pdf',
      buffer: Buffer.from('%PDF-1.4\n%%EOF\n'),
    })

    // Creating mid-upload would save the certificate without its document.
    await expect(sheet.getByText(/attached file/i)).toBeVisible({ timeout: 30_000 })
    await sheet.getByRole('button', { name: /^create$/i }).click()

    await expect(certificates.getByText(certificateNumber)).toBeVisible({ timeout: 15_000 })
    await expect(certificates.getByRole('button', { name: /certificate\.pdf/i })).toBeVisible()
  })

  // Certificates point at the store's own reasons: the picker offers the
  // active ones only, and renaming a reason renames it on every certificate.
  test('picks a tax exemption reason the store added', async ({ page }) => {
    const creds = await login(page)
    const suffix = Date.now()
    const offered = `E2E Diplomatic ${suffix}`
    const retired = `E2E Retired ${suffix}`
    const renamed = `E2E Embassy ${suffix}`
    const reasons = card(page, /^tax exemption reasons$/i)

    await page.goto(`/${creds.store_id}/settings/taxes/exemption-reasons`)
    for (const [name, code] of [
      [offered, `DIPLOMATIC_${suffix}`],
      [retired, `RETIRED_${suffix}`],
    ]) {
      await reasons.getByRole('button', { name: /add reason/i }).click()
      await page.locator('#reason-name').fill(name)
      await page.locator('#reason-code').fill(code)
      await page
        .getByRole('dialog')
        .getByRole('button', { name: /^create$/i })
        .click()
      await expect(reasons.getByText(name)).toBeVisible({ timeout: 15_000 })
    }
    await openRowMenu(page, retired)
    await page.getByRole('menuitem', { name: /^edit$/i }).click()
    await page.getByRole('switch', { name: /available on new records/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()
    await expect(
      reasons
        .getByRole('row')
        .filter({ hasText: retired })
        .getByText(/^inactive$/i),
    ).toBeVisible({ timeout: 15_000 })

    await createCompany(page, creds.store_id, `E2E Consulate ${suffix}`)
    const certificates = card(page, /exemption certificates/i)
    await certificates.getByRole('button', { name: /add certificate/i }).click()
    const sheet = page.getByRole('dialog')
    const certificateNumber = `DIP-${suffix}`
    await sheet.locator('#certificate_number').fill(certificateNumber)
    await sheet.locator('#tax_exemption_reason_id').click()
    await expect(page.getByRole('option', { name: retired })).toHaveCount(0)
    await page.getByRole('option', { name: offered }).click()
    await sheet.getByRole('button', { name: /^create$/i }).click()

    await expect(certificates.getByText(certificateNumber)).toBeVisible({ timeout: 15_000 })
    await expect(certificates.getByText(offered)).toBeVisible()

    const companyUrl = page.url()
    await page.goto(`/${creds.store_id}/settings/taxes/exemption-reasons`)
    await openRowMenu(page, offered)
    await page.getByRole('menuitem', { name: /^edit$/i }).click()
    await page.locator('#reason-name').fill(renamed)
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()
    await expect(reasons.getByText(renamed)).toBeVisible({ timeout: 15_000 })

    await page.goto(companyUrl)
    await expect(
      card(page, /exemption certificates/i)
        .getByText(renamed)
        .first(),
    ).toBeVisible({ timeout: 15_000 })
  })

  test('deletes a company from the list', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Dissolved ${Date.now()}`
    await createCompany(page, creds.store_id, name)

    await gotoIndex(page, COMPANIES_PATH(creds.store_id), CTA)
    await openRowMenu(page, name)
    await page.getByRole('menuitem', { name: /^delete$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^delete$/i })
      .click()

    await expect(rowButton(page, name)).toHaveCount(0, { timeout: 15_000 })
  })

  test('records a custom field on the company', async ({ page }) => {
    const creds = await login(page)
    await withCustomFieldDefinition(page, creds, 'company', async (label) => {
      await createCompany(page, creds.store_id, `E2E Custom Field Co ${Date.now()}`)
      await saveCustomFieldOnCard(page, label, 'Key account')
    })
  })
})
