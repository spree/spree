import type { RunContext } from '../context.js'
import type { CategoryEntry, ProductEntry, VariantEntry } from '../schema.js'
import type { LiveRecord } from '../types.js'
import { type Payload, pick, present, refs, type Section } from './section.js'

// --- Categories ------------------------------------------------------------

function parentPermalink(permalink: string): string | null {
  const index = permalink.lastIndexOf('/')
  return index === -1 ? null : permalink.slice(0, index)
}

const CATEGORY_ATTRIBUTES: (keyof CategoryEntry)[] = [
  'permalink',
  'name',
  'description',
  'meta_title',
  'meta_description',
  'meta_keywords',
]

export const categories: Section<CategoryEntry> = {
  name: 'categories',
  introspectByDefault: true,
  sequential: true,
  path: '/categories',
  keyAttribute: 'permalink',
  filterable: true,
  liveKey: (live) => String(live.permalink),
  fileKeys: (config) => (config.categories ?? []).map((category) => category.permalink),
  // Parents before children, so a child's reference resolves within the run.
  entries: (config) =>
    [...(config.categories ?? [])].sort(
      (left, right) => left.permalink.split('/').length - right.permalink.split('/').length,
    ),
  entryKey: (entry) => entry.permalink,
  async desired(entry, ctx, path) {
    const parent = parentPermalink(entry.permalink)
    return {
      ...pick(entry, CATEGORY_ATTRIBUTES),
      parent_id: parent ? await ctx.ref('categories', parent, path) : null,
    }
  },
  async current(live) {
    return live
  },
  async toFile(live) {
    return present(live as unknown as CategoryEntry, CATEGORY_ATTRIBUTES) as CategoryEntry
  },
}

// --- Products --------------------------------------------------------------

const PRODUCT_EXPAND = [
  'variants',
  'variants.prices',
  'variants.stock_levels',
  'variants.option_values',
  'categories',
  'product_publications',
]

const PRODUCT_ATTRIBUTES: (keyof ProductEntry)[] = [
  'slug',
  'name',
  'status',
  'description',
  'tags',
  'meta_title',
  'meta_description',
]

const VARIANT_ATTRIBUTES: (keyof VariantEntry)[] = [
  'sku',
  'barcode',
  'weight',
  'height',
  'width',
  'depth',
  'track_inventory',
  'cost_price',
]

interface LivePrice {
  currency: string
  amount: string | null
  compare_at_amount: string | null
  price_list_id: string | null
  min_quantity: number
}

interface LiveStockLevel {
  stock_location_id: string
  count_on_hand: number
}

interface LiveOptionValue {
  name: string
  option_type_name: string
}

interface LiveVariant extends LiveRecord {
  sku: string | null
  prices?: LivePrice[]
  stock_levels?: LiveStockLevel[]
  option_values?: LiveOptionValue[]
}

interface LivePublication {
  channel_id: string
  unpublished_at: string | null
}

/** The variants a product entry declares: its list, or the one simple-product variant. */
function entryVariants(entry: ProductEntry): VariantEntry[] {
  if (entry.variants) return entry.variants
  if (!entry.sku && !entry.prices && !entry.stock) return []
  return [
    {
      sku: entry.sku ?? entry.slug.toUpperCase(),
      ...(entry.prices ? { prices: entry.prices } : {}),
      ...(entry.compare_at_prices ? { compare_at_prices: entry.compare_at_prices } : {}),
      ...(entry.stock ? { stock: entry.stock } : {}),
    },
  ]
}

async function variantPayload(
  variant: VariantEntry,
  ctx: RunContext,
  path: string,
): Promise<Payload> {
  const payload: Payload = pick(variant, VARIANT_ATTRIBUTES)
  if (variant.options) {
    payload.options = Object.entries(variant.options)
      .map(([name, value]) => ({ name, value }))
      .sort((left, right) => left.name.localeCompare(right.name))
  }
  if (variant.prices || variant.compare_at_prices) {
    const currencies = new Set([
      ...Object.keys(variant.prices ?? {}),
      ...Object.keys(variant.compare_at_prices ?? {}),
    ])
    payload.prices = [...currencies].sort().map((currency) => ({
      currency,
      ...(variant.prices?.[currency] !== undefined ? { amount: variant.prices[currency] } : {}),
      ...(variant.compare_at_prices?.[currency] !== undefined
        ? { compare_at_amount: variant.compare_at_prices[currency] }
        : {}),
    }))
  }
  if (variant.stock) {
    const levels = await Promise.all(
      Object.entries(variant.stock).map(async ([location, count]) => ({
        stock_location_id: await ctx.ref('stock_locations', location, path),
        count_on_hand: count,
      })),
    )
    payload.stock_levels = levels
  }
  return payload
}

/**
 * Rails' `parameterize`, which is how the API keys option types and values:
 * `Red` and `red` name the same value, and the file may use either.
 */
export function parameterize(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

type OptionPair = { name: string; value: string }

/**
 * Live option values in the file's own spelling where they parameterize the
 * same, so a file that says `Red` compares equal to a stored `red`.
 */
function liveOptions(live: LiveVariant, desired: Payload | undefined): OptionPair[] {
  const wanted = (desired?.options as OptionPair[] | undefined) ?? []
  return (live.option_values ?? []).map((value) => {
    const match = wanted.find(
      (option) =>
        parameterize(option.name) === parameterize(value.option_type_name) &&
        parameterize(option.value) === parameterize(value.name),
    )
    return match ?? { name: value.option_type_name, value: value.name }
  })
}

/** A live variant in the payload vocabulary, trimmed to what the entry's variant mentions. */
function liveVariantPayload(live: LiveVariant, desired: Payload | undefined): Payload {
  const payload: Payload = { ...pick(live as unknown as VariantEntry, VARIANT_ATTRIBUTES) }
  payload.options = liveOptions(live, desired).sort((left, right) =>
    left.name.localeCompare(right.name),
  )
  const wantedCurrencies = new Set(
    ((desired?.prices as { currency: string }[] | undefined) ?? []).map((price) => price.currency),
  )
  payload.prices = (live.prices ?? [])
    .filter((price) => price.price_list_id === null && price.min_quantity <= 1)
    .filter((price) => wantedCurrencies.has(price.currency))
    .sort((left, right) => left.currency.localeCompare(right.currency))
    .map((price) => ({
      currency: price.currency,
      amount: price.amount,
      compare_at_amount: price.compare_at_amount,
    }))
  const wantedLocations = new Set(
    ((desired?.stock_levels as { stock_location_id: unknown }[] | undefined) ?? []).map((level) =>
      String(level.stock_location_id),
    ),
  )
  payload.stock_levels = (live.stock_levels ?? [])
    .filter((level) => wantedLocations.has(String(level.stock_location_id)))
    .map((level) => ({
      stock_location_id: level.stock_location_id,
      count_on_hand: level.count_on_hand,
    }))
  return payload
}

function sortVariants(variants: Payload[]): Payload[] {
  return [...variants].sort((left, right) => String(left.sku).localeCompare(String(right.sku)))
}

function sortStockLevels(payload: Payload): Payload {
  const levels = payload.stock_levels as { stock_location_id: unknown }[] | undefined
  if (!levels) return payload
  return {
    ...payload,
    stock_levels: [...levels].sort((left, right) =>
      String(left.stock_location_id).localeCompare(String(right.stock_location_id)),
    ),
  }
}

function publishedChannelIds(live: LiveRecord): string[] {
  return ((live.product_publications as LivePublication[] | undefined) ?? [])
    .filter((publication) => !publication.unpublished_at)
    .map((publication) => publication.channel_id)
}

export const products: Section<ProductEntry> = {
  name: 'products',
  introspectByDefault: false,
  path: '/products',
  keyAttribute: 'slug',
  filterable: true,
  expand: PRODUCT_EXPAND,
  liveKey: (live) => String(live.slug),
  fileKeys: (config) => (config.products ?? []).map((product) => product.slug),
  entries: (config) => config.products ?? [],
  entryKey: (entry) => entry.slug,
  async desired(entry, ctx, path) {
    const payload: Payload = pick(entry, PRODUCT_ATTRIBUTES)
    if (entry.product_type)
      payload.product_type_id = await ctx.ref('product_types', entry.product_type, path)
    if (entry.tax_category)
      payload.tax_category_id = await ctx.ref('tax_categories', entry.tax_category, path)
    const categoryIds = await refs(ctx, 'categories', entry.categories, path)
    if (categoryIds) payload.category_ids = categoryIds
    // Channels are compared as codes and written through the bulk endpoints
    // in afterWrite, since the product payload has no channel list.
    if (entry.channels) payload.channels = [...entry.channels].sort()
    const variants = entryVariants(entry)
    if (variants.length) {
      payload.variants = sortVariants(
        await Promise.all(variants.map((variant) => variantPayload(variant, ctx, path))),
      ).map(sortStockLevels)
    }
    return payload
  },
  async current(live, ctx, entry) {
    const desired = entry ? await this.desired(entry, ctx, '') : {}
    const desiredVariants = (desired.variants as Payload[] | undefined) ?? []
    const liveVariants = (live.variants as LiveVariant[] | undefined) ?? []
    const channels = (
      await Promise.all(publishedChannelIds(live).map((id) => ctx.keyOf('channels', id)))
    ).filter((code): code is string => code !== null)
    return {
      ...live,
      category_ids: ((live.categories as LiveRecord[] | undefined) ?? []).map(
        (category) => category.id,
      ),
      channels: channels.sort(),
      variants: sortVariants(
        liveVariants.map((variant) => {
          const wanted = desiredVariants.find((candidate) => candidate.sku === variant.sku)
          return sortStockLevels(liveVariantPayload(variant, wanted))
        }),
      ),
    }
  },
  async create(payload, _entry, ctx) {
    const { channels: _channels, ...body } = payload
    return ctx.client.request<LiveRecord>('POST', '/products', {
      params: { expand: PRODUCT_EXPAND.join(',') },
      body,
    })
  },
  async update(live, payload, _entry, ctx) {
    const { channels: _channels, ...body } = payload
    // A variant already on the product is addressed by id, so the full
    // replacement the API performs updates it in place instead of recreating it.
    const liveVariants = (live.variants as LiveVariant[] | undefined) ?? []
    if (Array.isArray(body.variants)) {
      body.variants = (body.variants as Payload[]).map((variant) => {
        const match = liveVariants.find((candidate) => candidate.sku === variant.sku)
        return match ? { id: match.id, ...variant } : variant
      })
    }
    return ctx.client.request<LiveRecord>('PATCH', `/products/${live.id}`, {
      params: { expand: PRODUCT_EXPAND.join(',') },
      body,
    })
  },
  async afterWrite(entry, live, _changes, ctx) {
    if (!entry.channels) return
    const wanted = await Promise.all(
      entry.channels.map(async (code) => {
        const channel = await ctx.find('channels', code)
        if (!channel) throw new Error(`channel "${code}" does not exist`)
        return channel.id
      }),
    )
    const current = publishedChannelIds(live)
    const add = wanted.filter((id) => !current.includes(id))
    const remove = current.filter((id) => !wanted.includes(id))
    if (add.length) {
      await ctx.client.request('POST', '/products/bulk_add_to_channels', {
        body: { ids: [live.id], channel_ids: add },
      })
    }
    if (remove.length) {
      await ctx.client.request('POST', '/products/bulk_remove_from_channels', {
        body: { ids: [live.id], channel_ids: remove },
      })
    }
  },
  async toFile(live, ctx) {
    const entry: ProductEntry = present(
      live as unknown as ProductEntry,
      PRODUCT_ATTRIBUTES,
    ) as ProductEntry
    if (live.product_type_id) {
      const type = await ctx.keyOf('product_types', String(live.product_type_id))
      if (type) entry.product_type = type
    }
    if (live.tax_category_id) {
      const category = await ctx.keyOf('tax_categories', String(live.tax_category_id))
      if (category) entry.tax_category = category
    }
    const categories = ((live.categories as LiveRecord[] | undefined) ?? []).map((category) =>
      String(category.permalink),
    )
    if (categories.length) entry.categories = categories
    const channels = (
      await Promise.all(publishedChannelIds(live).map((id) => ctx.keyOf('channels', id)))
    ).filter((code): code is string => code !== null)
    if (channels.length) entry.channels = channels

    const variants = await Promise.all(
      ((live.variants as LiveVariant[] | undefined) ?? []).map((variant) =>
        variantToFile(variant, ctx),
      ),
    )
    const simple = variants.length === 1 && !variants[0].options
    if (simple) {
      const [only] = variants
      entry.sku = only.sku
      if (only.prices) entry.prices = only.prices
      if (only.compare_at_prices) entry.compare_at_prices = only.compare_at_prices
      if (only.stock) entry.stock = only.stock
    } else if (variants.length) {
      entry.variants = variants
    }
    return entry
  },
}

async function variantToFile(live: LiveVariant, ctx: RunContext): Promise<VariantEntry> {
  const entry = present(live as unknown as VariantEntry, VARIANT_ATTRIBUTES) as VariantEntry
  if (entry.track_inventory === true) delete entry.track_inventory
  // Unset dimensions read back as 0; a file has no reason to say so.
  for (const dimension of ['weight', 'height', 'width', 'depth'] as const) {
    if (entry[dimension] === 0) delete entry[dimension]
  }
  if (!entry.sku) entry.sku = String(live.id)
  const options = Object.fromEntries(
    (live.option_values ?? []).map((value) => [value.option_type_name, value.name]),
  )
  if (Object.keys(options).length) entry.options = options
  const prices: Record<string, number> = {}
  const compareAt: Record<string, number> = {}
  for (const price of live.prices ?? []) {
    if (price.price_list_id !== null || price.min_quantity > 1) continue
    if (price.amount !== null) prices[price.currency] = Number(price.amount)
    if (price.compare_at_amount !== null)
      compareAt[price.currency] = Number(price.compare_at_amount)
  }
  if (Object.keys(prices).length) entry.prices = prices
  if (Object.keys(compareAt).length) entry.compare_at_prices = compareAt
  const stock: Record<string, number> = {}
  for (const level of live.stock_levels ?? []) {
    const location = await ctx.keyOf('stock_locations', String(level.stock_location_id))
    if (location) stock[location] = level.count_on_hand
  }
  if (Object.keys(stock).length) entry.stock = stock
  return entry
}
