import type { SectionSource } from '../context.js'
import { ConfigError } from '../errors.js'
import { RESERVED_KEYS, SECTION_NAMES, type SectionName } from '../types.js'
import { catalogs, companies, priceLists } from './b2b.js'
import { categories, collections, optionTypes, products, productTypes } from './catalog.js'
import { customFieldDefinitions } from './custom-fields.js'
import { deliveryMethods, deliveryProfiles, deliveryZones, packageTypes } from './delivery.js'
import { customers, sellers } from './people.js'
import { promotions } from './promotions.js'
import type { AnySection } from './section.js'
import {
  channels,
  customerGroups,
  markets,
  stockLocations,
  store,
  suppliers,
  taxCategories,
  taxRates,
} from './settings.js'
import {
  allowedOrigins,
  apiKeys,
  claimReasons,
  commissionRates,
  orderCancellationReasons,
  paymentMethods,
  refundReasons,
  returnReasons,
  sellerRequirements,
  taxExemptionReasons,
} from './setup.js'

/**
 * Sections in dependency order: a section comes after every section it can
 * reference, so a run creates targets before the records pointing at them.
 * Prune runs the same list backwards.
 */
// Each section is written against its own file entry and its own Admin API
// type; the engine drives them uniformly through `AnySection`, so the list
// erases those two parameters once, here.
export const ORDERED_SECTIONS: AnySection[] = [
  store,
  stockLocations,
  channels,
  markets,
  customerGroups,
  taxCategories,
  taxRates,
  deliveryProfiles,
  deliveryZones,
  deliveryMethods,
  packageTypes,
  paymentMethods,
  suppliers,
  optionTypes,
  customFieldDefinitions,
  categories,
  productTypes,
  products,
  collections,
  customers,
  companies,
  priceLists,
  catalogs,
  sellers,
  promotions,
  returnReasons,
  claimReasons,
  refundReasons,
  orderCancellationReasons,
  taxExemptionReasons,
  commissionRates,
  sellerRequirements,
  apiKeys,
  allowedOrigins,
] as unknown as AnySection[]

export const SECTIONS = Object.fromEntries(
  ORDERED_SECTIONS.map((section) => [section.name, section]),
) as Record<SectionName, AnySection>

/** Resources the file references by key but does not manage. */
const REFERENCE_SOURCES: Record<string, SectionSource> = {
  // Reference data every key may read; listed whole (it is not paginated).
  countries: {
    path: '/countries',
    readScope: 'read_settings',
    keyAttribute: 'iso',
    filterable: false,
  },
}

function sourceOf(section: AnySection): SectionSource {
  return {
    ...section,
    readScope: section.readScope ?? section.scope.replace(/^write_/, 'read_'),
    fileKeys: (config) => section.entries(config).map(section.entryKey),
  }
}

export const SOURCES: Record<string, SectionSource> = {
  ...REFERENCE_SOURCES,
  ...Object.fromEntries(ORDERED_SECTIONS.map((section) => [section.name, sourceOf(section)])),
}

/**
 * What checks one entry of an extension's section. Structural, so an
 * extension validates with its own copy of Zod, or with anything else that
 * answers the same way.
 */
export interface EntrySchema {
  safeParse(
    value: unknown,
  ):
    | { success: true; data: unknown }
    | { success: false; error: { issues: { path: PropertyKey[]; message: string }[] } }
}

/** A section an extension adds to the file: the section, and the schema of one entry. */
export type SectionDefinition = AnySection & { schema: EntrySchema }

const EXTENSIONS = new Map<string, SectionDefinition>()

/** Schemas of the sections extensions registered, by section name. */
export function extensionSchemas(): ReadonlyMap<string, EntrySchema> {
  return new Map([...EXTENSIONS].map(([name, definition]) => [name, definition.schema]))
}

/**
 * Adds an extension's section to the file format. It runs after every
 * built-in section and every section registered before it, so it may refer
 * to any of them; prune removes its records first.
 */
export function registerSection(definition: SectionDefinition): void {
  const name: string = definition?.name
  if (
    typeof name !== 'string' ||
    typeof definition.schema?.safeParse !== 'function' ||
    typeof definition.desired !== 'function'
  ) {
    throw new ConfigError('a section is registered with what `defineSection` returns', 'extensions')
  }
  if (EXTENSIONS.get(name) === definition) return
  if (!/^[a-z][a-z0-9_]*$/.test(name)) {
    throw new ConfigError(
      `"${name}" is not a section name: use lower-case words joined by "_"`,
      name,
    )
  }
  if ((RESERVED_KEYS as readonly string[]).includes(name) || name in SOURCES) {
    throw new ConfigError(`the file already has a "${name}" section`, name)
  }
  EXTENSIONS.set(name, definition)
  ORDERED_SECTIONS.push(definition)
  ;(SECTIONS as Record<string, AnySection>)[name] = definition
  SOURCES[name] = sourceOf(definition)
  ;(SECTION_NAMES as string[]).push(name)
}

/** Takes a registered section back out; for tests. */
export function unregisterSection(name: string): void {
  const definition = EXTENSIONS.get(name)
  if (!definition) return
  EXTENSIONS.delete(name)
  ORDERED_SECTIONS.splice(ORDERED_SECTIONS.indexOf(definition), 1)
  delete (SECTIONS as Record<string, AnySection>)[name]
  delete SOURCES[name]
  ;(SECTION_NAMES as string[]).splice((SECTION_NAMES as string[]).indexOf(name), 1)
}

export type { AnySection, Section } from './section.js'
