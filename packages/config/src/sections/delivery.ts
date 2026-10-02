import type {
  DeliveryMethod as SdkDeliveryMethod,
  DeliveryProfile as SdkDeliveryProfile,
  DeliveryZone as SdkDeliveryZone,
  PackageType as SdkPackageType,
} from '@spree/admin-sdk'
import type { RunContext } from '../context.js'
import { numericString } from '../diff.js'
import {
  DELIVERY_METHOD_ATTRIBUTES,
  DELIVERY_PROFILE_ATTRIBUTES,
  DELIVERY_ZONE_ATTRIBUTES,
  type DeliveryMethodEntry,
  type DeliveryProfileEntry,
  type DeliveryZoneEntry,
  PACKAGE_TYPE_ATTRIBUTES,
  type PackageTypeEntry,
} from '../schema.js'
import type { LiveRecord } from '../types.js'
import {
  FIRST_PARTY,
  keysOf,
  type Payload,
  partialIdList,
  pick,
  plainSection,
  present,
  refs,
  type Section,
} from './section.js'

// The SDK's generated types plus the index signature, so a section can read
// both declared attributes and the associations an `expand` adds.
type DeliveryMethod = SdkDeliveryMethod & LiveRecord
type DeliveryProfile = SdkDeliveryProfile & LiveRecord
type DeliveryZone = SdkDeliveryZone & LiveRecord
type PackageType = SdkPackageType & LiveRecord

export const deliveryProfiles = plainSection<DeliveryProfileEntry, DeliveryProfile>({
  name: 'delivery_profiles',
  scope: 'write_settings',
  introspectByDefault: true,
  key: 'name',
  attributes: DELIVERY_PROFILE_ATTRIBUTES,
  defaults: { default: false, kind: 'shipping' },
  fixedOnCreate: ['kind'],
  async current(live, _ctx, desired) {
    return desired.kind === undefined ? live : { ...live, kind: desired.kind }
  },
})

export const packageTypes = plainSection<PackageTypeEntry, PackageType>({
  name: 'package_types',
  scope: 'write_package_types',
  introspectByDefault: true,
  key: 'name',
  attributes: PACKAGE_TYPE_ATTRIBUTES,
  defaults: { default: false },
})

interface ZoneMember {
  member_type: string
  country_code: string | null
  state_code: string | null
  postal_code_prefix?: string | null
  postal_code_from?: string | null
  postal_code_to?: string | null
}

/** Country and state members are the file's; postal-code ranges are kept as they are. */
const isFileMember = (member: ZoneMember) =>
  member.member_type === 'country' || member.member_type === 'state'

/** The country codes a zone names: its list, or every known country but the excluded ones. */
async function zoneCountries(
  entry: DeliveryZoneEntry,
  ctx: RunContext,
): Promise<string[] | undefined> {
  if (!entry.all_countries_except) return entry.countries
  const excluded = new Set(entry.all_countries_except)
  const known = await ctx.load('countries')
  return [...known.byKey.keys()].filter((code) => !excluded.has(code))
}

async function membersPayload(
  entry: DeliveryZoneEntry,
  ctx: RunContext,
): Promise<ZoneMember[] | undefined> {
  const countries = await zoneCountries(entry, ctx)
  if (!countries && !entry.states) return undefined
  return [
    ...(countries ?? []).map((code) => ({
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

export const deliveryZones: Section<DeliveryZoneEntry, DeliveryZone> = {
  name: 'delivery_zones',
  scope: 'write_settings',
  introspectByDefault: true,
  path: '/delivery_zones',
  keyAttribute: 'name',
  filterable: true,
  expand: ['members'],
  entries: (config) => config.delivery_zones ?? [],
  entryKey: (entry) => entry.name,
  references: (config) => ({
    delivery_profiles: (config.delivery_zones ?? []).flatMap((zone) => zone.delivery_profile ?? []),
  }),
  async desired(entry, ctx, path) {
    const members = await membersPayload(entry, ctx)
    return {
      ...pick(entry, DELIVERY_ZONE_ATTRIBUTES),
      ...(entry.delivery_profile
        ? { delivery_profile_id: await ctx.ref('delivery_profiles', entry.delivery_profile, path) }
        : {}),
      ...(members ? { members: sortedMembers(members) } : {}),
    }
  },
  async current(live) {
    const members = (live.members as ZoneMember[] | undefined) ?? []
    return { ...live, members: sortedMembers(members.filter(isFileMember)) }
  },
  async update(live, payload, _entry, ctx) {
    // The members write replaces the set, so the ones the file cannot
    // express go back in unchanged.
    const kept = ((live.members as ZoneMember[] | undefined) ?? [])
      .filter((member) => !isFileMember(member))
      .map(
        ({
          member_type,
          country_code,
          state_code,
          postal_code_prefix,
          postal_code_from,
          postal_code_to,
        }) => ({
          member_type,
          country_code,
          state_code,
          postal_code_prefix,
          postal_code_from,
          postal_code_to,
        }),
      )
    const body = Array.isArray(payload.members)
      ? { ...payload, members: [...(payload.members as ZoneMember[]), ...kept] }
      : payload
    return ctx.client.request<DeliveryZone>('PATCH', `/delivery_zones/${live.id}`, { body })
  },
  async toFile(live, ctx) {
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
    const profile = live.delivery_profile_id
      ? await ctx.keyOf('delivery_profiles', String(live.delivery_profile_id))
      : null
    return {
      ...present(live as unknown as DeliveryZoneEntry, DELIVERY_ZONE_ATTRIBUTES),
      ...(profile ? { delivery_profile: profile } : {}),
      ...(countries.length ? { countries } : {}),
      ...(states.length ? { states } : {}),
    } as DeliveryZoneEntry
  },
}

// Pickup may also run from sellers' warehouses, which the file cannot name.
const methodPickupLocations = partialIdList('stock_locations', 'stock_location_ids')

function isEmptyPreference(value: unknown): boolean {
  if (value === null || value === undefined) return true
  if (Array.isArray(value)) return value.length === 0
  return typeof value === 'object' && Object.keys(value as object).length === 0
}

function numeric(value: unknown): unknown {
  if (typeof value !== 'string') return value
  return numericString(value) ?? value
}

export const deliveryMethods: Section<DeliveryMethodEntry, DeliveryMethod> = {
  name: 'delivery_methods',
  scope: 'write_delivery_methods',
  introspectByDefault: true,
  path: '/delivery_methods',
  keyAttribute: 'name',
  filterable: true,
  listParams: FIRST_PARTY,
  entries: (config) => config.delivery_methods ?? [],
  entryKey: (entry) => entry.name,
  references: (config) => {
    const methods = config.delivery_methods ?? []
    return {
      delivery_profiles: methods.flatMap((method) => method.delivery_profile ?? []),
      delivery_zones: methods.flatMap((method) => method.delivery_zone ?? []),
      tax_categories: methods.flatMap((method) => method.tax_category ?? []),
      stock_locations: methods.flatMap((method) => method.pickup_locations ?? []),
    }
  },
  async desired(entry, ctx, path) {
    const payload: Payload = pick(entry, DELIVERY_METHOD_ATTRIBUTES)
    if (entry.delivery_profile)
      payload.delivery_profile_id = await ctx.ref('delivery_profiles', entry.delivery_profile, path)
    if (entry.delivery_zone)
      payload.delivery_zone_id = await ctx.ref('delivery_zones', entry.delivery_zone, path)
    if (entry.tax_category)
      payload.tax_category_id = await ctx.ref('tax_categories', entry.tax_category, path)
    const pickupLocations = await refs(ctx, 'stock_locations', entry.pickup_locations, path)
    if (pickupLocations) payload.stock_location_ids = pickupLocations
    if (entry.calculator) {
      payload.calculator_type = entry.calculator.type
      if (entry.calculator.preferences)
        payload.calculator_preferences = entry.calculator.preferences
    }
    return payload
  },
  current: (live, ctx, desired) => methodPickupLocations.current(live, ctx, desired),
  async update(live, payload, _entry, ctx) {
    return ctx.client.request<DeliveryMethod>('PATCH', `/delivery_methods/${live.id}`, {
      body: await methodPickupLocations.write(live, payload, ctx),
    })
  },
  async toFile(live, ctx) {
    const entry: DeliveryMethodEntry = present(
      live as unknown as DeliveryMethodEntry,
      DELIVERY_METHOD_ATTRIBUTES,
    ) as DeliveryMethodEntry
    if (entry.storefront_visible === true) delete entry.storefront_visible
    if (entry.available_to_sellers === false) delete entry.available_to_sellers
    if (entry.fulfillment_provider === 'Spree::FulfillmentProvider::Manual')
      delete entry.fulfillment_provider
    if (live.delivery_profile_id) {
      const profile = await ctx.keyOf('delivery_profiles', String(live.delivery_profile_id))
      if (profile) entry.delivery_profile = profile
    }
    if (live.delivery_zone_id) {
      const zone = await ctx.keyOf('delivery_zones', String(live.delivery_zone_id))
      if (zone) entry.delivery_zone = zone
    }
    if (live.tax_category_id) {
      const category = await ctx.keyOf('tax_categories', String(live.tax_category_id))
      if (category) entry.tax_category = category
    }
    const pickupLocations = await keysOf(ctx, 'stock_locations', live.stock_location_ids)
    if (pickupLocations.length) entry.pickup_locations = pickupLocations
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
