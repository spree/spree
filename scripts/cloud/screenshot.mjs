#!/usr/bin/env node
// Screenshot a page from the cloud session's headless Chromium, so the agent
// can look at the dashboard it is changing (Read the PNG afterwards).
//
//   node scripts/cloud/screenshot.mjs <url> [out.png] [--login] [--full]
//
// --login signs in with the seeded admin first (or SPREE_LOGIN_EMAIL /
// SPREE_LOGIN_PASSWORD, e.g. a seller on :5175). Browser console errors are
// printed, since a blank page usually explains itself there.
import { createRequire } from 'node:module'

const require = createRequire(new URL('../../packages/dashboard/package.json', import.meta.url))
const { chromium } = require('@playwright/test')

const args = process.argv.slice(2)
const [url, out = '/tmp/screenshot.png'] = args.filter((arg) => !arg.startsWith('--'))
if (!url) {
  console.error('Usage: node scripts/cloud/screenshot.mjs <url> [out.png] [--login] [--full]')
  process.exit(64)
}

const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } })
page.on('console', (message) => {
  if (message.type() === 'error') console.log(`console error: ${message.text()}`)
})

try {
  if (args.includes('--login')) {
    await page.goto(new URL('/login', url).href)
    await page.getByLabel(/email/i).fill(process.env.SPREE_LOGIN_EMAIL ?? 'spree@example.com')
    await page.getByLabel(/password/i).fill(process.env.SPREE_LOGIN_PASSWORD ?? 'spree123')
    await page.getByRole('button', { name: /^sign in$/i }).click()
    await page.waitForURL((current) => !current.pathname.startsWith('/login'), { timeout: 15_000 })
  }
  await page.goto(url, { waitUntil: 'networkidle' })
  await page.screenshot({ path: out, fullPage: args.includes('--full') })
  console.log(`Saved ${out} (${page.url()})`)
} finally {
  await browser.close()
}
