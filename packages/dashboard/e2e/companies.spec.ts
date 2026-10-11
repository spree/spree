import { expect, type Page, test } from '@playwright/test'
import {
  FIXTURE_PROMO_CUSTOMER_EMAIL,
  fillAddressForm,
  gotoIndex,
  login,
  openRowMenu,
  rowButton,
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

  test('adds an address to the address book', async ({ page }) => {
    const creds = await login(page)
    await createCompany(page, creds.store_id, `E2E Depots ${Date.now()}`)

    const addressBook = card(page, /^address book/i)
    await expect(addressBook.getByText(/no addresses yet/i)).toBeVisible()
    await addressBook.getByRole('button', { name: /add address/i }).click()
    await expect(page.getByRole('heading', { name: /^new address$/i })).toBeVisible()
    await fillAddressForm(page, {
      label: 'Main warehouse',
      address1: '400 Dock Rd',
      city: 'Los Angeles',
      postalCode: '90001',
      // Country starts at the store's own, the United States.
      state: 'California',
    })
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^save$/i })
      .click()

    await expect(addressBook.getByText('400 Dock Rd')).toBeVisible({ timeout: 15_000 })
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
    await sheet.locator('#reason_code').click()
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
})
