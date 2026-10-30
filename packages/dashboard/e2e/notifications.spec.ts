import { expect, type Page, test } from '@playwright/test'
import { login } from './helpers'

const VERSION = '99.0.0'

// The update check and GitHub are both outside the test stack, so the spec
// answers them itself: a newer release exists, and GitHub returns its notes.
async function stubRelease(page: Page, bodyHtml: string) {
  await page.route('**/api/v3/admin/updates', (route) =>
    route.fulfill({
      json: {
        current_version: '6.0.1',
        enabled: true,
        checked_at: new Date().toISOString(),
        update_available: true,
        latest_version: VERSION,
        latest_release_url: `https://github.com/spree/spree/releases/tag/v${VERSION}`,
        latest_release_published_at: new Date().toISOString(),
      },
    }),
  )
  await page.route(`https://api.github.com/repos/spree/spree/releases/tags/v${VERSION}`, (route) =>
    route.fulfill({
      headers: { 'access-control-allow-origin': '*' },
      json: { tag_name: `v${VERSION}`, body_html: bodyHtml },
    }),
  )
}

async function openNotifications(page: Page) {
  const creds = await login(page)
  await page.goto(`/${creds.store_id}`)
  // The bell is mounted in the sidebar and in the phone's top bar.
  await page
    .getByRole('button', { name: /^notifications, 1 unread$/i })
    .filter({ visible: true })
    .first()
    .click({ timeout: 15_000 })
  return page.getByRole('dialog', { name: /notifications/i })
}

test.describe('notifications', () => {
  test('shows the release notes GitHub renders', async ({ page }) => {
    await stubRelease(
      page,
      [
        `<h1>Spree ${VERSION}</h1>`,
        '<p>A <strong>big</strong> release.</p>',
        '<ul><li>Fixed a thing <a href="https://github.com/spree/spree/pull/1">#1</a></li></ul>',
        '<p><img alt="Screenshot" src="https://github.com/user-attachments/assets/shot.png"></p>',
      ].join(''),
    )
    const dialog = await openNotifications(page)

    await expect(dialog.getByText(`Spree ${VERSION} is available`)).toBeVisible()
    await expect(
      dialog.getByRole('heading', { name: `Spree ${VERSION}`, exact: true }),
    ).toBeVisible()
    await expect(dialog.getByText('Fixed a thing')).toBeVisible()

    const link = dialog.getByRole('link', { name: '#1' })
    await expect(link).toHaveAttribute('target', '_blank')
    await expect(link).toHaveAttribute('rel', 'noopener noreferrer')
    await expect(dialog.getByRole('img', { name: 'Screenshot' })).toHaveAttribute('loading', 'lazy')
  })

  test('strips anything in the notes that could run script', async ({ page }) => {
    await stubRelease(
      page,
      [
        '<p>Safe text</p>',
        '<script>window.__pwned = 1</script>',
        '<img alt="Broken" src="x" onerror="window.__pwned = 2">',
        '<a href="javascript:window.__pwned = 3">Click me</a>',
        '<iframe src="https://evil.example"></iframe>',
        '<style>body { display: none }</style>',
        '<form action="https://evil.example"><input name="password"><button>Sign in</button></form>',
      ].join(''),
    )
    const dialog = await openNotifications(page)

    await expect(dialog.getByText('Safe text')).toBeVisible()
    const notes = dialog.locator('section')
    await expect(notes.locator('script, iframe, style, form, input, button')).toHaveCount(0)
    await expect(notes.locator('[onerror]')).toHaveCount(0)
    await expect(dialog.getByText('Click me')).not.toHaveAttribute('href', /javascript:/)
    expect(await page.evaluate(() => (window as { __pwned?: number }).__pwned)).toBeUndefined()
  })
})
