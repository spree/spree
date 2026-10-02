import { applyPlan } from './apply.js'
import { listAll } from './client.js'
import { COUNTRY_TEMPLATE, STORE_DEFAULTS } from './generated/templates.js'
import { parseConfig, type Variables } from './load.js'
import { type PlannedRun, planConfig } from './plan.js'
import type { SpreeConfig } from './schema.js'
import { ORDERED_SECTIONS, SECTIONS } from './sections/index.js'
import type { ApplyReport, ConfigClient } from './types.js'

interface LiveStore {
  default_country_code: string | null
  default_currency: string
  preferred_unit_system?: string
  preferred_weight_unit?: string
}

const POUND_IN: Record<string, number> = { lb: 1, oz: 16, kg: 0.45359237, g: 453.59237 }

/**
 * The parcel box every store starts with, in the units the store already
 * uses so the figures read the way a merchant would write them. Its tare is
 * half a pound, converted rather than restated under another unit's label,
 * to the two decimals the API stores.
 */
function boxVariables(store: LiveStore): Variables {
  const metric = store.preferred_unit_system === 'metric'
  const weightUnit = store.preferred_weight_unit ?? (metric ? 'kg' : 'lb')
  const weight = Math.round(0.5 * (POUND_IN[weightUnit] ?? 1) * 100) / 100
  return {
    BOX_LENGTH: metric ? '30' : '12',
    BOX_WIDTH: metric ? '23' : '9',
    BOX_HEIGHT: metric ? '10' : '4',
    DIMENSIONS_UNIT: metric ? 'cm' : 'in',
    BOX_WEIGHT: String(weight),
    WEIGHT_UNIT: weightUnit,
  }
}

/** Both templates' sections in one file: lists end to end, so one deploy orders them. */
function merge(...configs: SpreeConfig[]): SpreeConfig {
  const merged: Record<string, unknown> = { version: 1 }
  for (const config of configs) {
    for (const [section, value] of Object.entries(config)) {
      if (section === 'version') continue
      const existing = merged[section]
      merged[section] = Array.isArray(existing) ? [...existing, ...(value as unknown[])] : value
    }
  }
  return merged as SpreeConfig
}

/**
 * Drops the defaults an installation cannot hold: a host app may unregister a
 * seller requirement kind or a payment method type, and the store's other
 * defaults must not fail on its account. Sections whose entries are typed
 * declare where their registered types are listed. A payment method list
 * omits types the store already has, which is harmless: those are left
 * alone anyway.
 */
async function withoutUnregistered(
  config: SpreeConfig,
  client: ConfigClient,
): Promise<SpreeConfig> {
  const typed = ORDERED_SECTIONS.filter((section) => section.typesPath && config[section.name])
  const registered = await Promise.all(
    typed.map((section) =>
      client.request<{ data: { type: string }[] }>('GET', section.typesPath as string),
    ),
  )
  const filtered: Record<string, unknown> = { ...config }
  typed.forEach((section, index) => {
    const types = new Set(registered[index].data.map((entry) => entry.type))
    filtered[section.name] = (config[section.name] as { type: string }[]).filter((entry) =>
      types.has(entry.type),
    )
  })
  return filtered as SpreeConfig
}

/** Sections with one default record, and the attribute the API reads it back as. */
const SINGLE_DEFAULTS = [
  { section: 'tax_categories', live: 'is_default' },
  { section: 'stock_locations', live: 'default' },
  { section: 'package_types', live: 'default' },
] as const

/**
 * Leaves out a default the store already has another of. Matching is by
 * name, so a merchant who renamed the default tax category, warehouse or box
 * would otherwise get a second one that takes the default flag from theirs.
 */
async function withoutCompetingDefaults(
  config: SpreeConfig,
  client: ConfigClient,
): Promise<SpreeConfig> {
  const declared = SINGLE_DEFAULTS.filter(({ section }) =>
    (config[section] as { default?: boolean }[] | undefined)?.some((entry) => entry.default),
  )
  const taken = await Promise.all(
    declared.map(async ({ section, live }) => {
      const { path, listParams } = SECTIONS[section]
      const records = await listAll(client, path, listParams ?? {})
      return records.some((record) => record[live] === true)
    }),
  )
  const filtered: Record<string, unknown> = { ...config }
  declared.forEach(({ section }, index) => {
    if (!taken[index]) return
    filtered[section] = (config[section] as { default?: boolean }[]).filter(
      (entry) => !entry.default,
    )
  })
  return filtered as SpreeConfig
}

export interface DefaultsOptions {
  /**
   * Include the country-shaped defaults (warehouse, delivery zones and
   * rates, pickup, parcel box). On by default; off leaves only what every
   * store gets wherever it sells from.
   */
  country?: boolean
}

/**
 * The defaults a store starts with, filled in for the store's country,
 * currency and units, less any type the installation has not registered.
 * The store must already know where it sells from: first-run setup (or the
 * seed on a scripted install) sets that first.
 */
export async function storeDefaults(
  client: ConfigClient,
  { country: withCountry = true }: DefaultsOptions = {},
): Promise<SpreeConfig> {
  const store = await client.request<LiveStore>('GET', '/store')
  const country = store.default_country_code
  if (!country) throw new Error('the store has no country yet; finish first-run setup first')
  const { name } = await client.request<{ name: string }>('GET', `/countries/${country}`)
  const variables: Variables = {
    STORE_COUNTRY: country,
    STORE_COUNTRY_NAME: name,
    STORE_CURRENCY: store.default_currency,
    ...boxVariables(store),
  }
  const defaults = merge(
    parseConfig(STORE_DEFAULTS, variables).config,
    ...(withCountry ? [parseConfig(COUNTRY_TEMPLATE, variables).config] : []),
  )
  return withoutCompetingDefaults(await withoutUnregistered(defaults, client), client)
}

/**
 * A provisioning plan with the default warehouse applied last. The store
 * reads that warehouse as "provisioned" and sample data waits for it, so it
 * must not exist until every other default has been written. Nothing in the
 * defaults refers to a stock location, so moving the section is safe.
 */
export function warehouseLast(plan: PlannedRun): PlannedRun {
  const isWarehouse = (section: PlannedRun['sections'][number]) =>
    section.section === 'stock_locations'
  return {
    ...plan,
    sections: [
      ...plan.sections.filter((section) => !isWarehouse(section)),
      ...plan.sections.filter(isWarehouse),
    ],
  }
}

/**
 * Deploys the defaults every new store starts with. Only what is missing is
 * created: a default the merchant has since changed (a rate, a zone, which
 * tax category is the default) is left as it is, so running this again,
 * after an interrupted setup or by hand, never undoes their work. A failed
 * default is reported and the rest are still written.
 */
export async function provisionStore(
  client: ConfigClient,
  options: DefaultsOptions = {},
): Promise<ApplyReport> {
  const plan = await planConfig(await storeDefaults(client, options), client, { createOnly: true })
  return applyPlan(warehouseLast(plan))
}
