import { spawn } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { apiClient, createProduct, freePort, sh } from '../lib/project.mjs'

const ADDRESS = {
  firstName: 'Ada',
  lastName: 'Lovelace',
  address1: '350 Fifth Avenue',
  city: 'New York',
  postalCode: '10118',
  stateCode: 'NY',
  countryCode: 'US',
  phone: '+12125550100',
}

async function waitFor(url, timeoutMs = 120_000) {
  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    try {
      await fetch(url)
      return true
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 1000))
    }
  }
  return false
}

export function orderMismatch(order, { variantId, quantity, email }) {
  if (order.email?.toLowerCase() !== email.toLowerCase()) {
    return `email is ${order.email}, expected ${email}`
  }
  const items = (order.items ?? []).map((item) => `${item.variant_id} x ${item.quantity}`)
  const expected = `${variantId} x ${quantity}`
  if (items.length !== 1 || items[0] !== expected) {
    return `items are [${items.join(', ')}], expected [${expected}]`
  }
  return null
}

async function check({ projectDir, port, keys }) {
  const shopDir = path.join(projectDir, 'apps', 'shop')
  const manifest = path.join(shopDir, 'package.json')
  if (!fs.existsSync(manifest))
    return { passed: false, details: 'apps/shop/package.json is missing.' }
  const pkg = JSON.parse(fs.readFileSync(manifest, 'utf8'))
  if (!{ ...pkg.dependencies, ...pkg.devDependencies }['@spree/sdk']) {
    return { passed: false, details: 'apps/shop does not depend on @spree/sdk.' }
  }

  const env = { SPREE_API_URL: `http://localhost:${port}`, SPREE_PUBLISHABLE_KEY: keys.publishable }
  if (!fs.existsSync(path.join(shopDir, 'node_modules')))
    await sh('npm', ['install'], { cwd: shopDir })
  const build = await sh('npm', ['run', 'build'], { cwd: shopDir, env })
  if (build.code !== 0) {
    return { passed: false, details: `npm run build failed:\n${build.stdout}\n${build.stderr}` }
  }

  const api = apiClient(port, keys)
  const product = await createProduct(api, { name: 'Benchmark Mug', sku: `BENCH-${Date.now()}` })
  const variantId =
    product.default_variant?.id ?? product.variants?.[0]?.id ?? product.default_variant_id
  if (!variantId) return { passed: false, details: `No variant id in ${JSON.stringify(product)}` }

  const shopPort = await freePort(4100)
  const server = spawn('npx', ['next', 'start', '-p', String(shopPort)], {
    cwd: shopDir,
    env: { ...process.env, ...env },
    stdio: 'ignore',
    detached: true,
  })
  try {
    if (!(await waitFor(`http://localhost:${shopPort}/`))) {
      return { passed: false, details: 'next start did not answer within two minutes.' }
    }
    const submitted = { variantId, quantity: 1, email: `ada+${Date.now()}@example.com` }
    const response = await fetch(`http://localhost:${shopPort}/api/bench/checkout`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ ...submitted, address: ADDRESS }),
    })
    const body = await response.text()
    if (!response.ok)
      return { passed: false, details: `Route answered ${response.status}: ${body}` }
    const { orderId } = JSON.parse(body)
    const order = await api.admin('GET', `/orders/${orderId}?expand=items`)
    const placed = order.status === 200 && Boolean(order.json?.completed_at)
    if (!placed) {
      return {
        passed: false,
        details: `Order ${orderId} is not placed (${order.status}): ${order.text}`,
      }
    }
    // The order must be the one just submitted, not any completed order.
    const mismatch = orderMismatch(order.json, submitted)
    return {
      passed: !mismatch,
      details: mismatch
        ? `Order ${order.json.number} does not match the checkout request: ${mismatch}`
        : `Order ${order.json.number} placed.`,
    }
  } finally {
    try {
      process.kill(-server.pid)
    } catch {
      // Already gone.
    }
  }
}

export default {
  id: 'storefront-checkout',
  title: 'Build a checkout in Next.js with @spree/sdk',
  project: { storefront: false },
  timeoutMinutes: 60,
  prompt: `Build a small Next.js storefront in apps/shop (App Router, TypeScript) on top of this Spree backend, using the @spree/sdk package.

It needs a product listing page, a product page with "add to cart", a cart page, and a guest checkout: email, shipping address, delivery method, payment, and an order confirmation page.

Read the API URL and publishable key from the SPREE_API_URL and SPREE_PUBLISHABLE_KEY environment variables.

So we can test it end to end, also add a route handler at POST /api/bench/checkout that takes
  {"variantId": "...", "quantity": 1, "email": "...", "address": {"firstName", "lastName", "address1", "city", "postalCode", "stateCode", "countryCode", "phone"}}
runs the whole guest checkout through the same code the pages use (picking the first delivery option and a payment method that needs no card), and answers {"orderId": "<the placed order's id>"}.

If the store is not yet able to take such an order (for example it has no delivery method or no suitable payment method), set it up. "npm run build" must pass.`,
  check,
}
