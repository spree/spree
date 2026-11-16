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

// Fetches the storefront pages the prompt asks for and returns what is wrong
// with them, or null. `get(path)` answers { status, text, path } after
// redirects, where path is the one it ended on.
// The pages must render server-side, so the names are in the HTML itself.
export async function pageProblems(
  get,
  { productName, productPaths, orderNumber, confirmationUrl },
) {
  // The problem with the page at path, or null when it answers 200 and shows text.
  const problem = async (label, path, text, { stay = false } = {}) => {
    let page
    try {
      page = await get(path)
    } catch (error) {
      return `${label} (${path}) failed: ${error.message}`
    }
    if (page.status !== 200) return `${label} (${path}) answered ${page.status}`
    if (stay && page.path !== path) return `${label} (${path}) redirects to ${page.path}`
    if (text && !page.text.includes(text)) {
      return `${label} (${path}) does not show ${JSON.stringify(text)}`
    }
    return null
  }
  const problems = [await problem('The product listing', '/', productName)]
  // The product page may live at the product's slug or its id.
  let productProblem = 'The product has neither a slug nor an id'
  for (const path of productPaths) {
    productProblem = await problem('The product page', path, productName)
    if (!productProblem) break
  }
  problems.push(productProblem)
  problems.push(await problem('The cart page', '/cart'))
  // A checkout that only redirects to the cart is not a checkout page.
  problems.push(await problem('The checkout page', '/checkout', null, { stay: true }))
  const isShopPath =
    typeof confirmationUrl === 'string' &&
    confirmationUrl.startsWith('/') &&
    !confirmationUrl.startsWith('//')
  problems.push(
    isShopPath
      ? await problem('The confirmation page', confirmationUrl, orderNumber)
      : `confirmationUrl ${JSON.stringify(confirmationUrl)} is not a path on the shop`,
  )
  const found = problems.filter(Boolean)
  return found.length ? found.join('\n') : null
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
  const server = spawn('npx', ['next', 'start', '-H', '127.0.0.1', '-p', String(shopPort)], {
    cwd: shopDir,
    env: { ...process.env, ...env },
    stdio: 'ignore',
    detached: true,
  })
  try {
    if (!(await waitFor(`http://127.0.0.1:${shopPort}/`))) {
      return { passed: false, details: 'next start did not answer within two minutes.' }
    }
    const submitted = { variantId, quantity: 1, email: `ada+${Date.now()}@example.com` }
    const response = await fetch(`http://127.0.0.1:${shopPort}/api/bench/checkout`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ ...submitted, address: ADDRESS }),
    })
    const body = await response.text()
    if (!response.ok)
      return { passed: false, details: `Route answered ${response.status}: ${body}` }
    const { orderId, confirmationUrl } = JSON.parse(body)
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
    if (mismatch) {
      return {
        passed: false,
        details: `Order ${order.json.number} does not match the checkout request: ${mismatch}`,
      }
    }
    // The route alone is not a storefront: the pages must answer too.
    const shop = `http://127.0.0.1:${shopPort}`
    const pages = await pageProblems(
      async (path) => {
        const page = await fetch(new URL(path, shop))
        const landed = new URL(page.url)
        return {
          status: page.status,
          text: await page.text(),
          path: landed.pathname + landed.search,
        }
      },
      {
        productName: product.name,
        productPaths: [product.slug, product.id].filter(Boolean).map((key) => `/products/${key}`),
        orderNumber: order.json.number,
        confirmationUrl,
      },
    )
    return {
      passed: !pages,
      details: pages
        ? `Order ${order.json.number} placed, but the pages fall short:\n${pages}`
        : `Order ${order.json.number} placed, and every page answers.`,
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

It needs these pages, rendered on the server so their content is in the HTML the server sends:
- a product listing at /,
- a product page with "add to cart" at /products/<the product's slug or id>,
- a cart page at /cart,
- a guest checkout at /checkout: email, shipping address, delivery method and payment,
- an order confirmation page that shows the order number.

The cart and checkout pages must also load for a visitor with no cart yet, at their own address rather than redirecting.

Read the API URL and publishable key from the SPREE_API_URL and SPREE_PUBLISHABLE_KEY environment variables.

So we can test it end to end, also add a route handler at POST /api/bench/checkout that takes
  {"variantId": "...", "quantity": 1, "email": "...", "address": {"firstName", "lastName", "address1", "city", "postalCode", "stateCode", "countryCode", "phone"}}
runs the whole guest checkout through the same code the pages use (picking the first delivery option and a payment method that needs no card), and answers {"orderId": "<the placed order's id>", "confirmationUrl": "<the path of that order's confirmation page>"}.

If the store is not yet able to take such an order (for example it has no delivery method or no suitable payment method), set it up. "npm run build" must pass.`,
  check,
}
