import type {
  ChannelEntry,
  CustomerGroupEntry,
  MarketEntry,
  StockLocationEntry,
  StoreEntry,
  SupplierEntry,
  TaxCategoryEntry,
} from '../schema.js'
import type { LiveRecord } from '../types.js'
import {
  byName,
  FIRST_PARTY,
  keysOf,
  type Payload,
  pick,
  preferencesFromLive,
  preferencesPayload,
  present,
  refs,
  type Section,
} from './section.js'

const STORE_ATTRIBUTES: (keyof StoreEntry)[] = [
  'name',
  'mail_from_address',
  'customer_support_email',
  'new_order_notifications_email',
]

export const store: Section<StoreEntry> = {
  name: 'store',
  scope: 'write_settings',
  singleton: true,
  introspectByDefault: true,
  path: '/store',
  keyAttribute: 'id',
  filterable: false,
  liveKey: () => 'store',
  fileKeys: (config) => (config.store ? ['store'] : []),
  entries: (config) => (config.store ? [config.store] : []),
  entryKey: () => 'store',
  async desired(entry) {
    return { ...pick(entry, STORE_ATTRIBUTES), ...preferencesPayload(entry.preferences) }
  },
  async current(live) {
    return live
  },
  async update(_live, payload, _entry, ctx) {
    return ctx.client.request<LiveRecord>('PATCH', '/store', { body: payload })
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

export const channels: Section<ChannelEntry> = {
  name: 'channels',
  scope: 'write_settings',
  introspectByDefault: true,
  path: '/channels',
  keyAttribute: 'code',
  filterable: true,
  liveKey: (live) => String(live.code),
  fileKeys: (config) => (config.channels ?? []).map((channel) => channel.code),
  entries: (config) => config.channels ?? [],
  entryKey: (entry) => entry.code,
  references: (config) => ({
    stock_locations: (config.channels ?? []).flatMap((channel) => channel.stock_locations ?? []),
  }),
  async desired(entry, ctx, path) {
    return {
      ...pick(entry, ['code', 'name', 'active', 'default']),
      stock_location_ids: await refs(ctx, 'stock_locations', entry.stock_locations, path),
      ...preferencesPayload(entry.preferences),
    }
  },
  async current(live) {
    return live
  },
  async toFile(live, ctx) {
    const entry = present(live as unknown as ChannelEntry, ['code', 'name', 'active', 'default'])
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

export const markets: Section<MarketEntry> = {
  name: 'markets',
  scope: 'write_settings',
  introspectByDefault: true,
  path: '/markets',
  keyAttribute: 'name',
  filterable: true,
  liveKey: byName,
  fileKeys: (config) => (config.markets ?? []).map((market) => market.name),
  entries: (config) => config.markets ?? [],
  entryKey: (entry) => entry.name,
  async desired(entry) {
    return {
      ...pick(entry, [
        'name',
        'currency',
        'default_locale',
        'supported_locales',
        'default',
        'tax_inclusive',
      ]),
      country_codes: entry.countries,
    }
  },
  async current(live) {
    return live
  },
  async toFile(live) {
    return {
      ...present(live as unknown as MarketEntry, [
        'name',
        'currency',
        'default_locale',
        'supported_locales',
        'default',
        'tax_inclusive',
      ]),
      countries: (live.country_codes as string[]) ?? [],
    } as MarketEntry
  },
}

export const customerGroups: Section<CustomerGroupEntry> = {
  name: 'customer_groups',
  scope: 'write_customers',
  introspectByDefault: true,
  path: '/customer_groups',
  keyAttribute: 'name',
  filterable: true,
  liveKey: byName,
  fileKeys: (config) => (config.customer_groups ?? []).map((group) => group.name),
  entries: (config) => config.customer_groups ?? [],
  entryKey: (entry) => entry.name,
  async desired(entry) {
    return pick(entry, ['name', 'description'])
  },
  async current(live) {
    return live
  },
  async toFile(live) {
    return present(live as unknown as CustomerGroupEntry, [
      'name',
      'description',
    ]) as CustomerGroupEntry
  },
}

export const taxCategories: Section<TaxCategoryEntry> = {
  name: 'tax_categories',
  scope: 'write_settings',
  introspectByDefault: true,
  path: '/tax_categories',
  keyAttribute: 'name',
  filterable: true,
  liveKey: byName,
  fileKeys: (config) => (config.tax_categories ?? []).map((category) => category.name),
  entries: (config) => config.tax_categories ?? [],
  entryKey: (entry) => entry.name,
  async desired(entry) {
    const payload: Payload = pick(entry, ['name', 'tax_code', 'description'])
    if (entry.default !== undefined) payload.is_default = entry.default
    return payload
  },
  async current(live) {
    return live
  },
  async toFile(live) {
    const entry = present(live as unknown as TaxCategoryEntry, ['name', 'tax_code', 'description'])
    return { ...entry, ...(live.is_default ? { default: true } : {}) } as TaxCategoryEntry
  },
}

const STOCK_LOCATION_ATTRIBUTES: (keyof StockLocationEntry)[] = [
  'name',
  'admin_name',
  'active',
  'default',
  'kind',
  'backorderable_default',
  'propagate_all_variants',
  'pickup_enabled',
  'returns_enabled',
  'address1',
  'address2',
  'city',
  'zipcode',
  'country_code',
  'state_code',
  'state_name',
  'phone',
  'company',
]

export const stockLocations: Section<StockLocationEntry> = {
  name: 'stock_locations',
  scope: 'write_stock',
  introspectByDefault: true,
  path: '/stock_locations',
  keyAttribute: 'name',
  filterable: true,
  listParams: FIRST_PARTY,
  liveKey: byName,
  fileKeys: (config) => (config.stock_locations ?? []).map((location) => location.name),
  entries: (config) => config.stock_locations ?? [],
  entryKey: (entry) => entry.name,
  async desired(entry) {
    return pick(entry, STOCK_LOCATION_ATTRIBUTES)
  },
  async current(live) {
    return live
  },
  async toFile(live) {
    const entry = present(live as unknown as StockLocationEntry, STOCK_LOCATION_ATTRIBUTES)
    // Defaults that only add noise to a file.
    if (entry.active === true) delete entry.active
    if (entry.default === false) delete entry.default
    if (entry.pickup_enabled === false) delete entry.pickup_enabled
    if (entry.returns_enabled === false) delete entry.returns_enabled
    if (entry.propagate_all_variants === false) delete entry.propagate_all_variants
    if (entry.backorderable_default === false) delete entry.backorderable_default
    return entry as StockLocationEntry
  },
}

const SUPPLIER_ATTRIBUTES: (keyof SupplierEntry)[] = [
  'name',
  'contact_name',
  'email',
  'phone',
  'notes',
  'address1',
  'address2',
  'city',
  'state_name',
  'state_code',
  'country_code',
  'postal_code',
]

export const suppliers: Section<SupplierEntry> = {
  name: 'suppliers',
  scope: 'write_purchasing',
  introspectByDefault: true,
  path: '/suppliers',
  keyAttribute: 'name',
  filterable: true,
  liveKey: byName,
  fileKeys: (config) => (config.suppliers ?? []).map((supplier) => supplier.name),
  entries: (config) => config.suppliers ?? [],
  entryKey: (entry) => entry.name,
  async desired(entry) {
    return pick(entry, SUPPLIER_ATTRIBUTES)
  },
  async current(live) {
    return live
  },
  async toFile(live) {
    return present(live as unknown as SupplierEntry, SUPPLIER_ATTRIBUTES) as SupplierEntry
  },
}
