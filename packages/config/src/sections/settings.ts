import type {
  Channel as SdkChannel,
  CustomerGroup as SdkCustomerGroup,
  Market as SdkMarket,
  StockLocation as SdkStockLocation,
  Store as SdkStore,
  Supplier as SdkSupplier,
  TaxCategory as SdkTaxCategory,
} from '@spree/admin-sdk'
import {
  CHANNEL_ATTRIBUTES,
  type ChannelEntry,
  CUSTOMER_GROUP_ATTRIBUTES,
  type CustomerGroupEntry,
  MARKET_ATTRIBUTES,
  type MarketEntry,
  STOCK_LOCATION_ATTRIBUTES,
  STORE_ATTRIBUTES,
  type StockLocationEntry,
  type StoreEntry,
  SUPPLIER_ATTRIBUTES,
  type SupplierEntry,
  TAX_CATEGORY_ATTRIBUTES,
  type TaxCategoryEntry,
} from '../schema.js'
import type { LiveRecord } from '../types.js'
import {
  FIRST_PARTY,
  keysOf,
  type Payload,
  partialIdList,
  pick,
  plainSection,
  preferencesFromLive,
  preferencesPayload,
  present,
  refs,
  type Section,
} from './section.js'

// The SDK's generated types plus the index signature, so a section can read
// both declared attributes and the associations an `expand` adds.
type Channel = SdkChannel & LiveRecord
type CustomerGroup = SdkCustomerGroup & LiveRecord
type Market = SdkMarket & LiveRecord
type StockLocation = SdkStockLocation & LiveRecord
type Store = SdkStore & LiveRecord
type Supplier = SdkSupplier & LiveRecord
type TaxCategory = SdkTaxCategory & LiveRecord

export const store: Section<StoreEntry, Store> = {
  name: 'store',
  scope: 'write_settings',
  singleton: true,
  pruneRefusal: 'the store row is never deleted',
  introspectByDefault: true,
  path: '/store',
  keyAttribute: 'id',
  filterable: false,
  liveKey: () => 'store',
  entries: (config) => (config.store ? [config.store] : []),
  entryKey: () => 'store',
  async desired(entry) {
    return { ...pick(entry, STORE_ATTRIBUTES), ...preferencesPayload(entry.preferences) }
  },
  async update(_live, payload, _entry, ctx) {
    return ctx.client.request<Store>('PATCH', '/store', { body: payload })
  },
  async toFile(live) {
    const entry = present(live as unknown as StoreEntry, STORE_ATTRIBUTES)
    const preferences = preferencesFromLive(live, [
      'timezone',
      'weight_unit',
      'unit_system',
      'storefront_access',
      'guest_checkout',
      'capture_method',
      'track_inventory_levels',
      'stock_reservations_enabled',
      'low_stock_threshold',
      'tax_using_ship_address',
      'order_number_prefix',
      'order_number_suffix',
    ])
    return { ...entry, ...(Object.keys(preferences).length ? { preferences } : {}) } as StoreEntry
  },
}

// A channel may also sell from sellers' warehouses, which the file cannot name.
const channelStockLocations = partialIdList('stock_locations', 'stock_location_ids')

export const channels: Section<ChannelEntry, Channel> = {
  name: 'channels',
  scope: 'write_settings',
  introspectByDefault: true,
  path: '/channels',
  keyAttribute: 'code',
  filterable: true,
  entries: (config) => config.channels ?? [],
  entryKey: (entry) => entry.code,
  references: (config) => ({
    stock_locations: (config.channels ?? []).flatMap((channel) => channel.stock_locations ?? []),
  }),
  async desired(entry, ctx, path) {
    return {
      ...pick(entry, CHANNEL_ATTRIBUTES),
      stock_location_ids: await refs(ctx, 'stock_locations', entry.stock_locations, path),
      ...preferencesPayload(entry.preferences),
    }
  },
  current: (live, ctx, desired) => channelStockLocations.current(live, ctx, desired),
  async update(live, payload, _entry, ctx) {
    return ctx.client.request<Channel>('PATCH', `/channels/${live.id}`, {
      body: await channelStockLocations.write(live, payload, ctx),
    })
  },
  async toFile(live, ctx) {
    const entry = present(live as unknown as ChannelEntry, CHANNEL_ATTRIBUTES)
    const stockLocations = await keysOf(ctx, 'stock_locations', live.stock_location_ids)
    const preferences = preferencesFromLive(live, [
      'order_routing_strategy',
      'storefront_access',
      'guest_checkout',
    ])
    return {
      ...entry,
      ...(stockLocations.length ? { stock_locations: stockLocations } : {}),
      ...(Object.keys(preferences).length ? { preferences } : {}),
    } as ChannelEntry
  },
}

export const markets = plainSection<MarketEntry, Market>({
  name: 'markets',
  scope: 'write_settings',
  introspectByDefault: true,
  key: 'name',
  attributes: MARKET_ATTRIBUTES,
  async desired(entry) {
    return { ...pick(entry, MARKET_ATTRIBUTES), country_codes: entry.countries }
  },
  // The API counts the default locale as supported whether or not it was
  // listed, so the file need not repeat it.
  async current(live, _ctx, desired) {
    const wanted = desired.supported_locales as string[] | undefined
    if (!wanted) return live
    const implied = desired.default_locale ?? live.default_locale
    return {
      ...live,
      supported_locales: (live.supported_locales ?? []).filter(
        (locale) => locale !== implied || wanted.includes(locale),
      ),
    }
  },
  async toFile(live) {
    const entry = present(live as unknown as MarketEntry, MARKET_ATTRIBUTES)
    const supported = (live.supported_locales ?? []).filter(
      (locale) => locale !== live.default_locale,
    )
    return {
      ...entry,
      supported_locales: supported.length ? supported : undefined,
      countries: (live.country_codes as string[]) ?? [],
    } as MarketEntry
  },
})

export const customerGroups = plainSection<CustomerGroupEntry, CustomerGroup>({
  name: 'customer_groups',
  scope: 'write_customers',
  introspectByDefault: true,
  key: 'name',
  attributes: CUSTOMER_GROUP_ATTRIBUTES,
})

export const taxCategories = plainSection<TaxCategoryEntry, TaxCategory>({
  name: 'tax_categories',
  scope: 'write_settings',
  introspectByDefault: true,
  key: 'name',
  attributes: TAX_CATEGORY_ATTRIBUTES,
  async desired(entry) {
    const payload: Payload = pick(entry, TAX_CATEGORY_ATTRIBUTES)
    if (entry.default !== undefined) payload.is_default = entry.default
    return payload
  },
  async toFile(live) {
    const entry = present(live as unknown as TaxCategoryEntry, TAX_CATEGORY_ATTRIBUTES)
    return { ...entry, ...(live.is_default ? { default: true } : {}) } as TaxCategoryEntry
  },
})

export const stockLocations = plainSection<StockLocationEntry, StockLocation>({
  name: 'stock_locations',
  // Stock locations are store-wide administration: writes need the settings scope.
  scope: 'write_settings',
  readScope: 'read_stock',
  introspectByDefault: true,
  listParams: FIRST_PARTY,
  key: 'name',
  attributes: STOCK_LOCATION_ATTRIBUTES,
  defaults: {
    active: true,
    default: false,
    pickup_enabled: false,
    returns_enabled: false,
    propagate_all_variants: false,
    backorderable_default: false,
  },
})

export const suppliers = plainSection<SupplierEntry, Supplier>({
  name: 'suppliers',
  scope: 'write_purchasing',
  introspectByDefault: true,
  key: 'name',
  attributes: SUPPLIER_ATTRIBUTES,
})
