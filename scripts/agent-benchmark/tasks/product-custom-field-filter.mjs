import fs from 'node:fs'
import path from 'node:path'
import { apiClient, createProduct, sh } from '../lib/project.mjs'

async function check({ projectDir, port, keys }) {
  const api = apiClient(port, keys)
  const definitions = await api.admin(
    'GET',
    '/custom_field_definitions?q[namespace_eq]=specs&q[key_eq]=origin',
  )
  const definition = definitions.json?.data?.find(
    (row) => row.namespace === 'specs' && row.key === 'origin' && row.resource_type === 'product',
  )
  if (!definition) {
    return { passed: false, details: `No specs.origin product definition: ${definitions.text}` }
  }
  if (!definition.searchable && !definition.sortable) {
    return { passed: false, details: 'specs.origin exists but is neither searchable nor sortable.' }
  }

  const script = path.join(projectDir, 'scripts', 'products-by-origin.mjs')
  if (!fs.existsSync(script)) {
    return { passed: false, details: 'scripts/products-by-origin.mjs is missing.' }
  }

  const stamp = Date.now()
  const products = []
  try {
    for (const origin of ['Portugal', 'Spain']) {
      const product = await createProduct(api, {
        name: `Benchmark ${origin}`,
        sku: `BENCH-${origin}-${stamp}`,
      })
      products.push(product)
      const value = await api.admin('POST', `/products/${product.id}/custom_fields`, {
        body: { custom_field_definition_id: definition.id, value: origin },
      })
      if (value.status >= 300) {
        return { passed: false, details: `Setting origin failed (${value.status}): ${value.text}` }
      }
    }

    const result = await sh('node', [script, 'Portugal'], {
      cwd: projectDir,
      env: { SPREE_API_URL: `http://localhost:${port}`, SPREE_SECRET_KEY: keys.secret },
      timeoutMs: 120_000,
    })
    const ids = result.stdout.split(/\s+/).filter(Boolean)
    const [portugal, spain] = products
    const passed = result.code === 0 && ids.includes(portugal.id) && !ids.includes(spain.id)
    return {
      passed,
      details: `exit ${result.code}; expected ${portugal.id} and not ${spain.id}; got: ${ids.join(' ')}\n${result.stderr}`,
    }
  } finally {
    for (const product of products) await api.admin('DELETE', `/products/${product.id}`)
  }
}

export default {
  id: 'product-custom-field-filter',
  title: 'Add a product custom field and filter by it through the Admin API',
  project: { storefront: false },
  timeoutMinutes: 30,
  prompt: `We want to record each product's country of origin and find products by it.

1. Add an "origin" custom field for products, in the "specs" namespace (so specs.origin), as short text that can be used to filter products. Create it in this store.
2. Write scripts/products-by-origin.mjs, a Node script that takes a country name as its only argument and prints the ids of the products whose origin equals it, one per line, by filtering through the Admin API. It reads the API URL from SPREE_API_URL and a secret API key from SPREE_SECRET_KEY.

Try it on a couple of products before you finish.`,
  check,
}
