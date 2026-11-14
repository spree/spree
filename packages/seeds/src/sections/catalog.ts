import type {
  Category as SdkCategory,
  Collection as SdkCollection,
  OptionType as SdkOptionType,
  Product as SdkProduct,
  ProductType as SdkProductType,
} from '@spree/admin-sdk'
import type { RunContext } from '../context.js'
import { SeedsError } from '../errors.js'
import {
  CATEGORY_ATTRIBUTES,
  type CategoryEntry,
  COLLECTION_ATTRIBUTES,
  type CollectionEntry,
  OPTION_TYPE_ATTRIBUTES,
  type OptionTypeEntry,
  PRODUCT_ATTRIBUTES,
  PRODUCT_TYPE_ATTRIBUTES,
  type ProductEntry,
  type ProductTypeEntry,
  type VariantEntry,
} from '../schema.js'
import { decimalString } from '../spec.js'
import type { LiveRecord } from '../types.js'
import {
  customFieldReferences,
  customFieldsPayload,
  customFieldsToFile,
  definitionKey,
  liveCustomFields,
  withCustomFieldsBody,
} from './custom-fields.js'
import { desiredMembers, liveMembers, membersToFile, syncMembers } from './membership.js'
import { sortedRules } from './rules.js'
import {
  FIRST_PARTY,
  keysOf,
  type Payload,
  pick,
  plainSection,
  present,
  refs,
  type Section,
} from './section.js'

// The SDK's generated types plus the index signature, so a section can read
// both declared attributes and the associations an `expand` adds.
type Category = SdkCategory & LiveRecord
type Collection = SdkCollection & LiveRecord
type OptionType = SdkOptionType & LiveRecord
type Product = SdkProduct & LiveRecord
type ProductType = SdkProductType & LiveRecord

// --- Option types ----------------------------------------------------------

interface LiveOptionValueRow {
  id: string
  name: string
  label?: string
  position?: number
  color_code?: string | null
}

const liveValues = (live: OptionType) =>
  [...((live.option_values as LiveOptionValueRow[] | undefined) ?? [])].sort(
    (left, right) => (left.position ?? 0) - (right.position ?? 0),
  )

export const optionTypes: Section<OptionTypeEntry, OptionType> = {
  name: 'option_types',
  scope: 'write_products',
  introspectByDefault: true,
  path: '/option_types',
  keyAttribute: 'name',
  filterable: true,
  expand: ['option_values'],
  entries: (config) => config.option_types ?? [],
  entryKey: (entry) => entry.name,
  async desired(entry) {
    return {
      ...pick(entry, OPTION_TYPE_ATTRIBUTES),
      // The order of the list is the display order.
      ...(entry.values
        ? {
            option_values: entry.values.map((value, index) => ({ ...value, position: index + 1 })),
          }
        : {}),
    }
  },
  async current(live, _ctx, desired) {
    if (!desired.option_values) return live
    // Positions are compared as an order, since the store may number them
    // from any start.
    return {
      ...live,
      option_values: liveValues(live).map((value, index) => ({ ...value, position: index + 1 })),
    }
  },
  // A value already on the type is addressed by id, so the replacement the
  // API performs changes it in place: variants keep the value they hold.
  async update(live, payload, _entry, ctx) {
    const existing = liveValues(live)
    const body = Array.isArray(payload.option_values)
      ? {
          ...payload,
          option_values: (payload.option_values as Payload[]).map((value) => {
            const match = existing.find((candidate) => candidate.name === value.name)
            return match ? { id: match.id, ...value } : value
          }),
        }
      : payload
    return ctx.client.request<OptionType>('PATCH', `/option_types/${live.id}`, {
      params: { expand: 'option_values' },
      body,
    })
  },
  async toFile(live) {
    const values = liveValues(live).map((value) => ({
      name: value.name,
      ...(value.label && value.label !== value.name ? { label: value.label } : {}),
      ...(value.color_code ? { color_code: value.color_code } : {}),
    }))
    return {
      ...present(live as unknown as OptionTypeEntry, OPTION_TYPE_ATTRIBUTES),
      ...(values.length ? { values } : {}),
    } as OptionTypeEntry
  },
}

// --- Product types ---------------------------------------------------------

interface LiveTypeField {
  id: string
  key: string
  namespace: string
  required?: boolean
  sort_order?: number
}

const liveTypeFields = (live: ProductType) =>
  [...((live.custom_field_definitions as LiveTypeField[] | undefined) ?? [])].sort(
    (left, right) => (left.sort_order ?? 0) - (right.sort_order ?? 0),
  )

export const productTypes = plainSection<ProductTypeEntry, ProductType>({
  name: 'product_types',
  scope: 'write_product_types',
  introspectByDefault: true,
  key: 'name',
  attributes: PRODUCT_TYPE_ATTRIBUTES,
  references: (config) => {
    const types = config.product_types ?? []
    return {
      delivery_profiles: types.flatMap((type) => type.delivery_profile ?? []),
      option_types: types.flatMap((type) => type.option_types ?? []),
      categories: types.flatMap((type) => type.categories ?? []),
      custom_field_definitions: types.flatMap((type) =>
        (type.custom_fields ?? []).map((field) => definitionKey('product', field.key)),
      ),
    }
  },
  async desired(entry, ctx, path) {
    const payload: Payload = pick(entry, PRODUCT_TYPE_ATTRIBUTES)
    if (entry.delivery_profile)
      payload.delivery_profile_id = await ctx.ref('delivery_profiles', entry.delivery_profile, path)
    const optionTypeIds = await refs(ctx, 'option_types', entry.option_types, path)
    if (optionTypeIds) payload.option_type_ids = optionTypeIds
    const categoryIds = await refs(ctx, 'categories', entry.categories, path)
    if (categoryIds) payload.category_ids = categoryIds
    if (entry.custom_fields) {
      // The order of the list is the order the product form shows them in.
      payload.custom_field_definitions = await Promise.all(
        entry.custom_fields.map(async (field, index) => ({
          id: await ctx.ref('custom_field_definitions', definitionKey('product', field.key), path),
          required: field.required ?? false,
          sort_order: index,
        })),
      )
    }
    return payload
  },
  async current(live, _ctx, desired) {
    if (!desired.custom_field_definitions) return live
    return {
      ...live,
      custom_field_definitions: liveTypeFields(live).map((field, index) => ({
        id: field.id,
        required: field.required ?? false,
        sort_order: index,
      })),
    }
  },
  async toFile(live, ctx) {
    const profile = live.delivery_profile_id
      ? await ctx.keyOf('delivery_profiles', String(live.delivery_profile_id))
      : null
    const optionTypeNames = await keysOf(ctx, 'option_types', live.option_type_ids)
    const categoryPermalinks = await keysOf(ctx, 'categories', live.category_ids)
    const fields = liveTypeFields(live).map((field) => ({
      key: field.namespace === 'custom' ? field.key : `${field.namespace}.${field.key}`,
      ...(field.required ? { required: true } : {}),
    }))
    return {
      ...present(live as unknown as ProductTypeEntry, PRODUCT_TYPE_ATTRIBUTES),
      ...(profile ? { delivery_profile: profile } : {}),
      ...(optionTypeNames.length ? { option_types: optionTypeNames } : {}),
      ...(categoryPermalinks.length ? { categories: categoryPermalinks } : {}),
      ...(fields.length ? { custom_fields: fields } : {}),
    } as ProductTypeEntry
  },
})

// --- Categories ------------------------------------------------------------

function parentPermalink(permalink: string): string | null {
  const index = permalink.lastIndexOf('/')
  return index === -1 ? null : permalink.slice(0, index)
}

const ENTITIES: Record<string, string> = {
  nbsp: ' ',
  amp: '&',
  quot: '"',
  apos: "'",
  lsquo: '\u2018',
  rsquo: '\u2019',
  ldquo: '\u201C',
  rdquo: '\u201D',
  ndash: '\u2013',
  mdash: '\u2014',
  hellip: '\u2026',
}

/**
 * Rich text in a form two equal descriptions share: the API stores sanitized
 * markup (entities escaped, the file's line breaks kept), so the file's value
 * and `description_html` are compared with whitespace collapsed and entities
 * decoded. `&lt;` and `&gt;` stay encoded, so literal text never equals a tag.
 */
export function canonicalMarkup(value: unknown): string | null {
  if (typeof value !== 'string') return (value as string | null) ?? null
  return value
    .replace(/>\s+</g, '><')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (entity, name: string) => {
      if (name[0] === '#') {
        const code =
          name[1].toLowerCase() === 'x'
            ? Number.parseInt(name.slice(2), 16)
            : Number.parseInt(name.slice(1), 10)
        return code === 60 || code === 62 ? entity : String.fromCodePoint(code)
      }
      return ENTITIES[name.toLowerCase()] ?? entity
    })
}

/** The live markup in canonical form, when the desired payload sets a description. */
function descriptionPair(desired: Payload, live: LiveRecord) {
  return desired.description === undefined
    ? {}
    : { description: canonicalMarkup(live.description_html ?? null) }
}

export const categories: Section<CategoryEntry, Category> = {
  name: 'categories',
  scope: 'write_categories',
  introspectByDefault: true,
  sequential: true,
  path: '/categories',
  keyAttribute: 'permalink',
  filterable: true,
  expand: ['custom_fields'],
  references: (config) => ({
    custom_field_definitions: customFieldReferences('category', config.categories ?? []),
  }),
  entries: (config) =>
    [...(config.categories ?? [])].sort(
      (left, right) => left.permalink.split('/').length - right.permalink.split('/').length,
    ),
  entryKey: (entry) => entry.permalink,
  async desired(entry, ctx, path) {
    const parent = parentPermalink(entry.permalink)
    return {
      ...pick(entry, CATEGORY_ATTRIBUTES),
      ...(entry.description !== undefined
        ? { description: canonicalMarkup(entry.description) }
        : {}),
      parent_id: parent ? await ctx.ref('categories', parent, path) : null,
      ...(await customFieldsPayload('category', entry.custom_fields, ctx, path)),
    }
  },
  async current(live, _ctx, desired) {
    return { ...live, ...descriptionPair(desired, live), ...liveCustomFields(live, desired) }
  },
  async create(payload, entry, ctx) {
    return ctx.client.request<Category>('POST', '/categories', {
      body: {
        ...(await withCustomFieldsBody('category', payload, ctx)),
        ...(entry.description !== undefined ? { description: entry.description } : {}),
      },
    })
  },
  async update(live, payload, entry, ctx) {
    const { parent_id: parentId, ...body } = await withCustomFieldsBody('category', payload, ctx)
    // The update ignores a blank parent, so moving a category to the top
    // level goes through the reposition action.
    if (parentId === null && live.parent_id) {
      await ctx.client.request('PATCH', `/categories/${live.id}/reposition`, {
        body: { new_position: 0 },
      })
    }
    return ctx.client.request<Category>('PATCH', `/categories/${live.id}`, {
      body: {
        ...body,
        ...(parentId ? { parent_id: parentId } : {}),
        ...(entry.description !== undefined ? { description: entry.description } : {}),
      },
    })
  },
  async toFile(live) {
    return {
      ...present(
        { ...live, description: live.description_html } as unknown as CategoryEntry,
        CATEGORY_ATTRIBUTES,
      ),
      ...customFieldsToFile(live),
    } as CategoryEntry
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
  'custom_fields',
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
  label?: string
  option_type_name: string
  option_type_label?: string
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
  if (!entry.sku) return []
  return [
    {
      sku: entry.sku,
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

type OptionPair = { name: string; value: string }

/**
 * Live option values in the file's own spelling where they name the same
 * value: the API stores a parameterized `name` next to the `label` it was
 * given, and the file may use either, in any case.
 */
function liveOptions(live: LiveVariant, desired: Payload | undefined): OptionPair[] {
  const wanted = (desired?.options as OptionPair[] | undefined) ?? []
  const same = (left: string, right: string | undefined) =>
    right !== undefined && left.toLowerCase() === right.toLowerCase()
  return (live.option_values ?? []).map((value) => {
    const match = wanted.find(
      (option) =>
        (same(option.name, value.option_type_name) || same(option.name, value.option_type_label)) &&
        (same(option.value, value.name) || same(option.value, value.label)),
    )
    return match ?? { name: value.option_type_name, value: value.label ?? value.name }
  })
}

/**
 * A live variant in the payload vocabulary. Prices come back whole, not
 * trimmed to what the file names: the product write replaces the set, so a
 * currency the file omits is about to be removed and has to appear in the
 * diff rather than vanish silently.
 */
function liveVariantPayload(live: LiveVariant, desired: Payload | undefined): Payload {
  const payload: Payload = { ...pick(live as unknown as VariantEntry, VARIANT_ATTRIBUTES) }
  payload.options = liveOptions(live, desired).sort((left, right) =>
    left.name.localeCompare(right.name),
  )
  payload.prices = (live.prices ?? [])
    .filter((price) => price.price_list_id === null && price.min_quantity <= 1)
    .sort((left, right) => left.currency.localeCompare(right.currency))
    .map((price) => ({
      currency: price.currency,
      amount: price.amount,
      compare_at_amount: price.compare_at_amount,
    }))
  payload.stock_levels = (live.stock_levels ?? []).map((level) => ({
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

export const products: Section<ProductEntry, Product> = {
  name: 'products',
  scope: 'write_products',
  introspectByDefault: false,
  path: '/products',
  keyAttribute: 'slug',
  filterable: true,
  listParams: FIRST_PARTY,
  expand: PRODUCT_EXPAND,
  entries: (config) => config.products ?? [],
  entryKey: (entry) => entry.slug,
  references: (config) => {
    const products = config.products ?? []
    return {
      product_types: products.flatMap((product) => product.product_type ?? []),
      tax_categories: products.flatMap((product) => product.tax_category ?? []),
      categories: products.flatMap((product) => product.categories ?? []),
      channels: products.flatMap((product) => product.channels ?? []),
      custom_field_definitions: customFieldReferences('product', products),
      stock_locations: products.flatMap((product) =>
        entryVariants(product).flatMap((variant) => Object.keys(variant.stock ?? {})),
      ),
    }
  },
  async desired(entry, ctx, path) {
    const payload: Payload = pick(entry, PRODUCT_ATTRIBUTES)
    if (entry.description !== undefined) payload.description = canonicalMarkup(entry.description)
    if (entry.product_type)
      payload.product_type_id = await ctx.ref('product_types', entry.product_type, path)
    if (entry.tax_category)
      payload.tax_category_id = await ctx.ref('tax_categories', entry.tax_category, path)
    const categoryIds = await refs(ctx, 'categories', entry.categories, path)
    if (categoryIds) payload.category_ids = categoryIds
    // Channels are compared as codes and written through the bulk endpoints
    // in afterWrite, since the product payload has no channel list.
    if (entry.channels) payload.channels = [...entry.channels].sort()
    Object.assign(payload, await customFieldsPayload('product', entry.custom_fields, ctx, path))
    const variants = entryVariants(entry)
    if (variants.length) {
      payload.variants = sortVariants(
        await Promise.all(variants.map((variant) => variantPayload(variant, ctx, path))),
      ).map(sortStockLevels)
    }
    return payload
  },
  async current(live, ctx, desired, entry) {
    const desiredVariants = (desired.variants as Payload[] | undefined) ?? []
    const liveVariants = (live.variants as LiveVariant[] | undefined) ?? []
    // The product write replaces the whole variant set, so the one variant of
    // the simple-product form would delete every option variant.
    if (entry.sku && !entry.variants) {
      const optioned = liveVariants.filter((variant) => variant.option_values?.length)
      if (liveVariants.length > 1 || optioned.length) {
        throw new SeedsError(
          `the live product has ${liveVariants.length} variant${liveVariants.length === 1 ? '' : 's'} with options; declare them under \`variants\`, since the simple-product \`sku\` would replace them all`,
          entry.slug,
        )
      }
    }
    const channels = await keysOf(ctx, 'channels', publishedChannelIds(live))
    return {
      ...live,
      ...descriptionPair(desired, live),
      ...liveCustomFields(live, desired),
      category_ids: ((live.categories as LiveRecord[] | undefined) ?? []).map(
        (category) => category.id,
      ),
      channels: channels.sort(),
      variants: sortVariants(
        liveVariants.map((variant) => {
          const wanted = desiredVariants.find((candidate) => candidate.sku === variant.sku)
          const payload = liveVariantPayload(variant, wanted)
          // Stock is opening stock: once a variant exists its counts move with
          // sales and receipts, so the file's figure is never compared again.
          if (wanted) payload.stock_levels = wanted.stock_levels
          else delete payload.stock_levels
          return sortStockLevels(payload)
        }),
      ),
    }
  },
  async create(payload, entry, ctx) {
    const { channels: _channels, ...body } = await withCustomFieldsBody('product', payload, ctx)
    // The comparison used the canonical form; the write sends the markup the
    // file holds.
    if (entry.description !== undefined) body.description = entry.description
    return ctx.client.request<Product>('POST', '/products', {
      params: { expand: PRODUCT_EXPAND.join(',') },
      body,
    })
  },
  async update(live, payload, entry, ctx) {
    const { channels: _channels, ...body } = await withCustomFieldsBody('product', payload, ctx)
    if (entry.description !== undefined) body.description = entry.description
    // A variant already on the product is addressed by id, so the full
    // replacement the API performs updates it in place instead of recreating it.
    const liveVariants = (live.variants as LiveVariant[] | undefined) ?? []
    if (Array.isArray(body.variants)) {
      body.variants = (body.variants as Payload[]).map((variant) => {
        const match = liveVariants.find((candidate) => candidate.sku === variant.sku)
        if (!match) return variant
        const { stock_levels: _opening, ...rest } = variant
        return { id: match.id, ...rest }
      })
    }
    return ctx.client.request<Product>('PATCH', `/products/${live.id}`, {
      params: { expand: PRODUCT_EXPAND.join(',') },
      body,
    })
  },
  async wire(payload) {
    if (!Array.isArray(payload.variants)) return payload
    return {
      ...payload,
      variants: (payload.variants as Payload[]).map((variant) => ({
        ...variant,
        ...(variant.cost_price !== undefined
          ? { cost_price: decimalString(variant.cost_price) }
          : {}),
        ...(Array.isArray(variant.prices)
          ? {
              prices: (variant.prices as Payload[]).map((price) => ({
                ...price,
                ...(price.amount !== undefined ? { amount: decimalString(price.amount) } : {}),
                ...(price.compare_at_amount !== undefined
                  ? { compare_at_amount: decimalString(price.compare_at_amount) }
                  : {}),
              })),
            }
          : {}),
      })),
    }
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
    // The markup, not the plain-text `description`: a file captured from the
    // plain rendering would flatten the formatting on its next deploy.
    const entry: ProductEntry = present(
      { ...live, description: live.description_html } as unknown as ProductEntry,
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
    const channels = await keysOf(ctx, 'channels', publishedChannelIds(live))
    if (channels.length) entry.channels = channels
    Object.assign(entry, customFieldsToFile(live))

    const variants = await Promise.all(
      ((live.variants as LiveVariant[] | undefined) ?? []).map((variant) =>
        variantToFile(variant, ctx),
      ),
    )
    const simple = variants.length === 1 && !variants[0].options
    if (simple) {
      const [only] = variants
      if (only.sku) entry.sku = only.sku
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
  // A variant without a SKU is written without one: the file then fails
  // validation until someone gives it a real SKU, rather than adopting an id.
  const options = Object.fromEntries(
    (live.option_values ?? []).map((value) => [value.option_type_name, value.label ?? value.name]),
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

// --- Collections -----------------------------------------------------------

interface CollectionRule {
  type: string
  value?: string | null
  match_policy?: string | null
}

const ruleFields = (rule: CollectionRule) => ({
  type: rule.type,
  ...(rule.value !== undefined && rule.value !== null ? { value: String(rule.value) } : {}),
  ...(rule.match_policy ? { match_policy: rule.match_policy } : {}),
})

export const collections: Section<CollectionEntry, Collection> = {
  name: 'collections',
  scope: 'write_collections',
  introspectByDefault: true,
  path: '/collections',
  keyAttribute: 'permalink',
  filterable: true,
  expand: ['rules', 'custom_fields'],
  entries: (config) => config.collections ?? [],
  entryKey: (entry) => entry.permalink,
  references: (config) => ({
    products: (config.collections ?? []).flatMap((collection) => collection.products ?? []),
    custom_field_definitions: customFieldReferences('collection', config.collections ?? []),
  }),
  async desired(entry, ctx, path) {
    return {
      ...pick(entry, COLLECTION_ATTRIBUTES),
      ...(entry.description !== undefined
        ? { description: canonicalMarkup(entry.description) }
        : {}),
      ...(entry.rules ? { rules: sortedRules(entry.rules) } : {}),
      ...(await desiredMembers(entry.products, ctx, path)),
      ...(await customFieldsPayload('collection', entry.custom_fields, ctx, path)),
    }
  },
  async current(live, ctx, desired) {
    return {
      ...live,
      ...descriptionPair(desired, live),
      ...(desired.rules
        ? { rules: sortedRules(live.rules as CollectionRule[] | undefined).map(ruleFields) }
        : {}),
      ...(await liveMembers(ctx, '/collections', live, desired)),
      ...liveCustomFields(live, desired),
    }
  },
  async create(payload, entry, ctx) {
    const { products: _products, ...body } = await withCustomFieldsBody('collection', payload, ctx)
    if (entry.description !== undefined) body.description = entry.description
    return ctx.client.request<Collection>('POST', '/collections', { body })
  },
  async update(live, payload, entry, ctx) {
    const { products: _products, ...body } = await withCustomFieldsBody('collection', payload, ctx)
    if (entry.description !== undefined) body.description = entry.description
    return ctx.client.request<Collection>('PATCH', `/collections/${live.id}`, { body })
  },
  afterWrite: (entry, live, _changes, ctx) =>
    syncMembers(ctx, '/collections', live, entry.products),
  async toFile(live, ctx) {
    const rules = sortedRules(live.rules as CollectionRule[] | undefined).map(ruleFields)
    const entry = present(
      { ...live, description: live.description_html } as unknown as CollectionEntry,
      COLLECTION_ATTRIBUTES,
    ) as CollectionEntry
    if (entry.automatic === false) delete entry.automatic
    if (entry.rules_match_policy === 'all') delete entry.rules_match_policy
    if (entry.sort_order === 'manual') delete entry.sort_order
    return {
      ...entry,
      ...(rules.length ? { rules } : {}),
      // An automatic collection's products are whatever its rules select.
      ...(live.automatic ? {} : await membersToFile(ctx, '/collections', live)),
      ...customFieldsToFile(live),
    } as CollectionEntry
  },
}
