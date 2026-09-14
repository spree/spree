import { numericString } from '../diff.js'
import type { DeliveryMethodEntry, DeliveryZoneEntry } from '../schema.js'
import type { LiveRecord } from '../types.js'
import {
  byName,
  FIRST_PARTY,
  keysOf,
  type Payload,
  pick,
  present,
  refs,
  type Section,
} from './section.js'

interface ZoneMember {
  member_type: string
  country_code: string | null
  state_code: string | null
}

function membersPayload(entry: DeliveryZoneEntry): ZoneMember[] | undefined {
  if (!entry.countries && !entry.states) return undefined
  return [
    ...(entry.countries ?? []).map((code) => ({
      member_type: 'country',
      country_code: code,
      state_code: null,
    })),
    ...(entry.states ?? []).map((state) => ({
      member_type: 'state',
      country_code: state.country,
      state_code: state.state,
    })),
  ]
}

/** Members in a stable order so two equal sets compare equal whatever the API returned them in. */
function sortedMembers(members: ZoneMember[]): ZoneMember[] {
  return [...members]
    .map(({ member_type, country_code, state_code }) => ({ member_type, country_code, state_code }))
    .sort((left, right) =>
      `${left.member_type}:${left.country_code}:${left.state_code}`.localeCompare(
        `${right.member_type}:${right.country_code}:${right.state_code}`,
      ),
    )
}

export const deliveryZones: Section<DeliveryZoneEntry> = {
  name: 'delivery_zones',
  introspectByDefault: true,
  path: '/delivery_zones',
  keyAttribute: 'name',
  filterable: true,
  expand: ['members'],
  liveKey: byName,
  fileKeys: (config) => (config.delivery_zones ?? []).map((zone) => zone.name),
  entries: (config) => config.delivery_zones ?? [],
  entryKey: (entry) => entry.name,
  async desired(entry) {
    const members = membersPayload(entry)
    return {
      ...pick(entry, ['name', 'description']),
      ...(members ? { members: sortedMembers(members) } : {}),
    }
  },
  async current(live) {
    const members = (live.members as ZoneMember[] | undefined) ?? []
    return { ...live, members: sortedMembers(members) }
  },
  async toFile(live) {
    const members = (live.members as ZoneMember[] | undefined) ?? []
    const countries = members
      .filter((member) => member.member_type === 'country' && member.country_code)
      .map((member) => member.country_code as string)
      .sort()
    const states = members
      .filter(
        (member) => member.member_type === 'state' && member.country_code && member.state_code,
      )
      .map((member) => ({
        country: member.country_code as string,
        state: member.state_code as string,
      }))
    return {
      ...present(live as unknown as DeliveryZoneEntry, ['name', 'description']),
      ...(countries.length ? { countries } : {}),
      ...(states.length ? { states } : {}),
    } as DeliveryZoneEntry
  },
}

const METHOD_ATTRIBUTES: (keyof DeliveryMethodEntry)[] = [
  'name',
  'code',
  'admin_name',
  'storefront_visible',
  'available_to_sellers',
  'tracking_url',
  'estimated_transit_business_days_min',
  'estimated_transit_business_days_max',
]

function isEmptyPreference(value: unknown): boolean {
  if (value === null || value === undefined) return true
  if (Array.isArray(value)) return value.length === 0
  return typeof value === 'object' && Object.keys(value as object).length === 0
}

function numeric(value: unknown): unknown {
  if (typeof value !== 'string') return value
  return numericString(value) ?? value
}

export const deliveryMethods: Section<DeliveryMethodEntry> = {
  name: 'delivery_methods',
  introspectByDefault: true,
  path: '/delivery_methods',
  keyAttribute: 'name',
  filterable: true,
  listParams: FIRST_PARTY,
  liveKey: byName,
  fileKeys: (config) => (config.delivery_methods ?? []).map((method) => method.name),
  entries: (config) => config.delivery_methods ?? [],
  entryKey: (entry) => entry.name,
  async desired(entry, ctx, path) {
    const payload: Payload = pick(entry, METHOD_ATTRIBUTES)
    if (entry.delivery_zone)
      payload.delivery_zone_id = await ctx.ref('delivery_zones', entry.delivery_zone, path)
    if (entry.tax_category)
      payload.tax_category_id = await ctx.ref('tax_categories', entry.tax_category, path)
    const stockLocations = await refs(ctx, 'stock_locations', entry.stock_locations, path)
    if (stockLocations) payload.stock_location_ids = stockLocations
    if (entry.calculator) {
      payload.calculator_type = entry.calculator.type
      if (entry.calculator.preferences)
        payload.calculator_preferences = entry.calculator.preferences
    }
    return payload
  },
  async current(live) {
    return live
  },
  async toFile(live, ctx) {
    const entry: DeliveryMethodEntry = present(
      live as unknown as DeliveryMethodEntry,
      METHOD_ATTRIBUTES,
    ) as DeliveryMethodEntry
    if (entry.storefront_visible === true) delete entry.storefront_visible
    if (entry.available_to_sellers === false) delete entry.available_to_sellers
    if (live.delivery_zone_id) {
      const zone = await ctx.keyOf('delivery_zones', String(live.delivery_zone_id))
      if (zone) entry.delivery_zone = zone
    }
    if (live.tax_category_id) {
      const category = await ctx.keyOf('tax_categories', String(live.tax_category_id))
      if (category) entry.tax_category = category
    }
    const stockLocations = await keysOf(ctx, 'stock_locations', live.stock_location_ids)
    if (stockLocations.length) entry.stock_locations = stockLocations
    if (live.calculator_type) {
      // Unset preferences and numeric strings are how the API reports them;
      // a file reads better without the former and with plain numbers.
      const preferences = Object.fromEntries(
        Object.entries((live.calculator_preferences as Record<string, unknown>) ?? {})
          .filter(([, value]) => !isEmptyPreference(value))
          .map(([key, value]) => [key, numeric(value)]),
      )
      entry.calculator = {
        type: String(live.calculator_type),
        ...(Object.keys(preferences).length
          ? { preferences: preferences as Record<string, string | number | boolean | null> }
          : {}),
      }
    }
    return entry
  },
}

export type { LiveRecord }
