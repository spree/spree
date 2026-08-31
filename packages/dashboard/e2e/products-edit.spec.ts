import { expect, test } from '@playwright/test'
import { FIXTURE_BULK_CHANNEL_NAME, login } from './helpers'
import { createProduct, publishingCard, typeDescription } from './products-helpers'

test.describe('product edit', () => {
  test('creates a product and lands on the edit page', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Product Create ${Date.now()}`

    await createProduct(page, creds.store_id, name, 'Initial description')

    // The Name input on the edit page mirrors the saved name.
    await expect(page.getByLabel(/^name$/i)).toHaveValue(name)
  })

  test('reflects list, quote and link formatting in the description editor', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Product Editor Styles ${Date.now()}`

    await createProduct(page, creds.store_id, name)

    const description = page.locator('#product-description')
    await typeDescription(page, 'Formatted line')
    await page.keyboard.press('ControlOrMeta+A')

    await page.getByRole('button', { name: /^bullet list$/i }).click()
    const bulletList = description.locator('ul')
    await expect(bulletList).toBeVisible()
    await expect(bulletList).toHaveCSS('list-style-type', 'disc')
    await expect(page.getByRole('button', { name: /^bullet list$/i })).toHaveAttribute(
      'aria-pressed',
      'true',
    )

    await page.getByRole('button', { name: /^ordered list$/i }).click()
    const orderedList = description.locator('ol')
    await expect(orderedList).toBeVisible()
    await expect(orderedList).toHaveCSS('list-style-type', 'decimal')
    await expect(page.getByRole('button', { name: /^ordered list$/i })).toHaveAttribute(
      'aria-pressed',
      'true',
    )

    await page.getByRole('button', { name: /^blockquote$/i }).click()
    const quote = description.locator('blockquote')
    await expect(quote).toBeVisible()
    await expect(quote).toHaveCSS('border-inline-start-width', '3px')
    await expect(page.getByRole('button', { name: /^blockquote$/i })).toHaveAttribute(
      'aria-pressed',
      'true',
    )

    page.once('dialog', (dialog) => dialog.accept('https://example.com'))
    await page.getByRole('button', { name: /^link$/i }).click()
    const link = description.locator('a[href="https://example.com"]')
    await expect(link).toBeVisible()
    await expect(link).toHaveCSS('text-decoration-line', 'underline')
    await expect(page.getByRole('button', { name: /^link$/i })).toHaveAttribute(
      'aria-pressed',
      'true',
    )
  })

  test('cmd+b bolds description text without collapsing the sidebar', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Product Editor Bold ${Date.now()}`

    await createProduct(page, creds.store_id, name)

    const sidebar = page.locator('[data-slot="sidebar"][data-state]').first()
    await expect(sidebar).toHaveAttribute('data-state', 'expanded')

    await typeDescription(page, 'Bold this')
    await page.keyboard.press('ControlOrMeta+A')
    await page.keyboard.press('ControlOrMeta+B')

    await expect(page.locator('#product-description strong')).toHaveText('Bold this')
    await expect(page.getByRole('button', { name: /^bold$/i })).toHaveAttribute(
      'aria-pressed',
      'true',
    )
    await expect(sidebar).toHaveAttribute('data-state', 'expanded')
  })

  test('preserves multi-paragraph description formatting across reload', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Product Rich Text ${Date.now()}`

    await createProduct(page, creds.store_id, name)

    // Type two paragraphs on the edit page so the save goes through the
    // update path (the reported bug scenario), not create.
    await typeDescription(page, 'First paragraph\nSecond paragraph')

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 15_000,
    })

    await page.reload()

    // The saved HTML must round-trip as two separate paragraphs. Before the
    // fix the form hydrated from the tag-stripped, whitespace-squished
    // plain-text `description`, collapsing both lines into a single block.
    const description = page.locator('#product-description')
    await expect(description.locator('p')).toHaveCount(2)
    await expect(description.locator('p').first()).toHaveText('First paragraph')
    await expect(description.locator('p').nth(1)).toHaveText('Second paragraph')
  })

  test('updates name on an existing product', async ({ page }) => {
    const creds = await login(page)
    const original = `E2E Product Update ${Date.now()}`
    const updated = `${original} (updated)`

    await createProduct(page, creds.store_id, original)

    await page.getByLabel(/^name$/i).fill(updated)
    await page.getByRole('button', { name: /save product/i }).click()

    // After a successful save the button disables again (RHF `isDirty`
    // resets via `reset(updatedValues)`). Asserting on disabled state avoids
    // coupling to toast strings, which aren't stable across i18n updates.
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 15_000,
    })

    await page.reload()
    await expect(page.getByLabel(/^name$/i)).toHaveValue(updated)
  })

  test('lists a product on an additional channel via the publishing card', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Product Publish ${Date.now()}`

    await createProduct(page, creds.store_id, name)

    // New products auto-publish on the store's default channel ("Online
    // Store"), so the card is non-empty from the start. Assert the bulk
    // channel isn't there yet, then add it via Manage.
    const card = publishingCard(page)
    await expect(card.getByText(new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i'))).not.toBeVisible()

    await card.getByRole('button', { name: /^manage$/i }).click()
    await expect(page.getByRole('heading', { name: /^manage sales channels$/i })).toBeVisible()

    await page
      .getByRole('dialog')
      .getByRole('button', { name: new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i') })
      .click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^done$/i })
      .click()

    await expect(card.getByText(new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i'))).toBeVisible()

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 15_000,
    })

    // After reload the publication is still attached.
    await page.reload()
    await expect(
      publishingCard(page).getByText(new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i')),
    ).toBeVisible()
  })

  test('unlists a product from a channel via the publishing card', async ({ page }) => {
    const creds = await login(page)
    const name = `E2E Product Unpublish ${Date.now()}`

    await createProduct(page, creds.store_id, name)
    const card = publishingCard(page)

    // Attach the bulk channel first so we have something to detach.
    await card.getByRole('button', { name: /^manage$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i') })
      .click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^done$/i })
      .click()
    await expect(card.getByText(new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i'))).toBeVisible()
    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 15_000,
    })

    // Re-open Manage and toggle the same channel off — exercises the
    // re-sync write path (POST product_publications without that channel)
    // and locks in the idempotent-channel + remove-missing behaviour
    // covered by the controller spec.
    await card.getByRole('button', { name: /^manage$/i }).click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i') })
      .click()
    await page
      .getByRole('dialog')
      .getByRole('button', { name: /^done$/i })
      .click()

    await expect(card.getByText(new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i'))).not.toBeVisible()

    await page.getByRole('button', { name: /save product/i }).click()
    await expect(page.getByRole('button', { name: /save product/i })).toBeDisabled({
      timeout: 15_000,
    })

    await page.reload()
    await expect(
      publishingCard(page).getByText(new RegExp(FIXTURE_BULK_CHANNEL_NAME, 'i')),
    ).not.toBeVisible()
  })
})
