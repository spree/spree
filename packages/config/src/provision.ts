import { applyPlan, reportHasFailures } from './apply.js'
import { listAll } from './client.js'
import { COUNTRY_TEMPLATE, STORE_DEFAULTS } from './generated/templates.js'
import { parseConfig, type Variables } from './load.js'
import { type PlannedRun, planConfig } from './plan.js'
import type { SpreeConfig } from './schema.js'
import { ORDERED_SECTIONS, SECTIONS } from './sections/index.js'
import type { ApplyReport, ConfigClient, SectionName } from './types.js'

interface LiveStore {
  default_country_code: string | null
  default_currency: string
  unit_system?: string
  weight_unit?: string
}

const POUND_IN: Record<string, number> = { lb: 1, oz: 16, kg: 0.45359237, g: 453.59237 }

/**
 * The parcel box every store starts with, in the units the store already
 * uses so the figures read the way a merchant would write them. Its tare is
 * half a pound, converted rather than restated under another unit's label,
 * to the two decimals the API stores.
 */
function boxVariables(store: LiveStore): Variables {
  const metric = store.unit_system === 'metric'
  const weightUnit = store.weight_unit ?? (metric ? 'kg' : 'lb')
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
 * declare where their registered types are listed.
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

type Entry = Record<string, unknown>

/**
 * Defaults a store holds one of, and whether a live record already is it.
 * Everything else is matched by name, so a merchant who renamed the default
 * tax category, warehouse, box or delivery profile, the digital profile or
 * the store credit method would otherwise get a second one.
 */
const ONE_PER_STORE: { section: SectionName; holds: (entry: Entry, record: Entry) => boolean }[] = [
  { section: 'tax_categories', holds: (entry, record) => !!entry.default && !!record.is_default },
  { section: 'stock_locations', holds: (entry, record) => !!entry.default && !!record.default },
  { section: 'package_types', holds: (entry, record) => !!entry.default && !!record.default },
  {
    section: 'delivery_profiles',
    holds: (entry, record) =>
      (!!entry.default && !!record.default) ||
      (entry.kind === 'digital' && record.kind === 'digital'),
  },
  { section: 'payment_methods', holds: (entry, record) => entry.type === record.type },
]

/**
 * Leaves out each default the store already holds under whatever name, and
 * points the template's references to a left-out delivery profile at the
 * store's own.
 */
async function withoutHeldDefaults(
  config: SpreeConfig,
  client: ConfigClient,
): Promise<SpreeConfig> {
  const rules = ONE_PER_STORE.filter(
    ({ section }) => (config[section] as Entry[] | undefined)?.length,
  )
  const live = await Promise.all(
    rules.map(({ section }) => {
      const { path, listParams } = SECTIONS[section]
      return listAll(client, path, listParams ?? {})
    }),
  )
  const filtered: Record<string, unknown> = { ...config }
  const profileNames = new Map<string, string>()
  rules.forEach(({ section, holds }, index) => {
    filtered[section] = (config[section] as Entry[]).filter((entry) => {
      const held = live[index].find((record) => holds(entry, record))
      if (held && section === 'delivery_profiles')
        profileNames.set(String(entry.name), String(held.name))
      return !held
    })
  })
  for (const [section, entries] of Object.entries(filtered)) {
    if (!Array.isArray(entries)) continue
    filtered[section] = entries.map((entry: Entry) =>
      typeof entry.delivery_profile === 'string' && profileNames.has(entry.delivery_profile)
        ? { ...entry, delivery_profile: profileNames.get(entry.delivery_profile) }
        : entry,
    )
  }
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
  return withoutHeldDefaults(await withoutUnregistered(defaults, client), client)
}

/**
 * Applies a provisioning plan with the default warehouse last, and only once
 * every other default was written. The store reads that warehouse as
 * "provisioned" and queued sample data waits for it, so it must not exist
 * while anything else is missing; a retry creates it once the rest is in
 * place. Nothing in the defaults refers to a stock location.
 */
export async function applyProvisioning(plan: PlannedRun): Promise<ApplyReport> {
  const isWarehouse = (section: PlannedRun['sections'][number]) =>
    section.section === 'stock_locations'
  const rest = await applyPlan({ ...plan, sections: plan.sections.filter((s) => !isWarehouse(s)) })
  if (reportHasFailures(rest)) return rest
  const warehouse = await applyPlan({ ...plan, sections: plan.sections.filter(isWarehouse) })
  return { results: [...rest.results, ...warehouse.results] }
}

/**
 * Deploys the defaults every new store starts with. Only what is missing is
 * created: a default the merchant has since changed (a rate, a zone, which
 * tax category is the default) is left as it is, so running this again,
 * after an interrupted setup or by hand, never undoes their work.
 */
export async function provisionStore(
  client: ConfigClient,
  options: DefaultsOptions = {},
): Promise<ApplyReport> {
  const plan = await planConfig(await storeDefaults(client, options), client, { createOnly: true })
  return applyProvisioning(plan)
}
