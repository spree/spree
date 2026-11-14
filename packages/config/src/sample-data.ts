/**
 * `@spree/config/sample-data` — the demo store: a catalog of home appliances,
 * customers, a wholesale buyer with their company and trade prices. A recipe
 * of store files and CSV imports, run through the Admin API.
 */
import { listAll } from './client.js'
import {
  CATALOG_FILE,
  CUSTOMERS_CSV,
  PRICE_LIST_PRICES_CSV,
  PRODUCT_TRANSLATIONS_CSV,
  PRODUCTS_CSV,
  SETUP_FILE,
  WHOLESALE_FILE,
} from './generated/sample-data.js'
import { deployStep, importStep, type RecipeClient, type RecipeStep } from './recipe.js'
import type { LiveRecord } from './types.js'

export type { RecipeClient, RecipeProgress, RecipeStep } from './recipe.js'
export { RecipeError, runRecipe } from './recipe.js'

const DIGITAL_PRODUCT = 'the-spree-commerce-handbook'
const WHOLESALE_PRICE_LIST = 'Wholesale'

// A minimal valid PDF: what a buyer of the digital product downloads.
const HANDBOOK_PDF = [
  '%PDF-1.4',
  '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj',
  '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj',
  '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]>>endobj',
  'trailer<</Root 1 0 R>>',
  '%%EOF',
  '',
].join('\n')

async function first(client: RecipeClient, path: string, attribute: string, value: string) {
  const { data } = await client.request<{ data: LiveRecord[] }>('GET', path, {
    params: { [`q[${attribute}_eq]`]: value, limit: 1 },
  })
  return data[0]
}

/** Sample data builds on the defaults every store gets at setup. */
const provisioned: RecipeStep = {
  title: 'Checking the store',
  async run(client) {
    const { data } = await client.request<{ data: LiveRecord[] }>('GET', '/stock_locations', {
      params: { 'q[default_eq]': true, 'q[seller_id_null]': 1, limit: 1 },
    })
    if (!data.length) {
      throw new Error(
        'this store has not been set up yet: finish first-run setup, or run `spree config provision`',
      )
    }
  },
}

/** The one thing a CSV row cannot carry: the file buyers of the digital product download. */
const digitalFile: RecipeStep = {
  title: 'Attaching the digital product file',
  async run(client) {
    const product = await first(client, '/products', 'slug', DIGITAL_PRODUCT)
    if (!product) return
    const assets = await client.request<{ data: LiveRecord[] }>(
      'GET',
      `/products/${product.id}/digital_assets`,
    )
    if (assets.data.length) return
    const upload = await client.files.upload(
      new Blob([HANDBOOK_PDF], { type: 'application/pdf' }),
      {
        visibility: 'private',
        filename: `${DIGITAL_PRODUCT}.pdf`,
        contentType: 'application/pdf',
        method: 'multipart',
      },
    )
    await client.request('PATCH', `/products/${product.id}`, {
      body: { digital_assets: [{ signed_id: upload.signed_id }] },
    })
  },
}

/** Every sample product is sold on every channel, so each channel has a catalog to show. */
const publication: RecipeStep = {
  title: 'Publishing products on every channel',
  async run(client) {
    const [products, channels] = await Promise.all([
      listAll(client, '/products', { fields: 'id', 'q[seller_id_null]': 1 }),
      listAll(client, '/channels', { fields: 'id' }),
    ])
    if (!products.length || !channels.length) return
    await client.request('POST', '/products/bulk_add_to_channels', {
      body: {
        ids: products.map((product) => product.id),
        channel_ids: channels.map((channel) => channel.id),
      },
    })
  },
}

/** The demo store, step by step. Safe to run again: every step only adds what is missing or resets what it declares. */
export function sampleData(): RecipeStep[] {
  return [
    provisioned,
    deployStep('Setting up product types, delivery and payments', SETUP_FILE, async (client) => {
      const store = await client.request<{ default_currency: string }>('GET', '/store')
      return { STORE_CURRENCY: store.default_currency }
    }),
    importStep('Importing products', {
      type: 'products',
      csv: PRODUCTS_CSV,
      filename: 'products.csv',
    }),
    digitalFile,
    publication,
    importStep('Importing product translations', {
      type: 'product_translations',
      csv: PRODUCT_TRANSLATIONS_CSV,
      filename: 'product_translations.csv',
    }),
    deployStep('Creating collections', CATALOG_FILE),
    importStep('Importing customers', {
      type: 'customers',
      csv: CUSTOMERS_CSV,
      filename: 'customers.csv',
    }),
    deployStep('Setting up wholesale', WHOLESALE_FILE),
    importStep('Importing wholesale prices', {
      type: 'price_list_prices',
      csv: PRICE_LIST_PRICES_CSV,
      filename: 'price_list_prices.csv',
      async attributes(client) {
        const list = await first(client, '/price_lists', 'name', WHOLESALE_PRICE_LIST)
        if (!list) throw new Error(`the ${WHOLESALE_PRICE_LIST} price list does not exist`)
        return { price_list_id: list.id }
      },
    }),
  ]
}
