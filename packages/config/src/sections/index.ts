import type { SectionSource } from '../context.js'
import type { SectionName } from '../types.js'
import { categories, products, productTypes } from './catalog.js'
import { deliveryMethods, deliveryProfiles, deliveryZones, packageTypes } from './delivery.js'
import { customers, sellers } from './people.js'
import type { AnySection } from './section.js'
import {
  channels,
  customerGroups,
  markets,
  stockLocations,
  store,
  suppliers,
  taxCategories,
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
  deliveryProfiles,
  deliveryZones,
  deliveryMethods,
  packageTypes,
  paymentMethods,
  suppliers,
  productTypes,
  categories,
  products,
  customers,
  sellers,
  returnReasons,
  claimReasons,
  refundReasons,
  orderCancellationReasons,
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

export const SOURCES: Record<string, SectionSource> = {
  ...REFERENCE_SOURCES,
  ...Object.fromEntries(
    ORDERED_SECTIONS.map((section) => [
      section.name,
      {
        ...section,
        readScope: section.readScope ?? section.scope.replace(/^write_/, 'read_'),
        fileKeys: (config) => section.entries(config).map(section.entryKey),
      },
    ]),
  ),
}

export type { AnySection, Section } from './section.js'
