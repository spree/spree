import type { SectionSource } from '../context.js'
import type { SectionName } from '../types.js'
import { categories, products } from './catalog.js'
import { deliveryMethods, deliveryZones } from './delivery.js'
import { customers, sellers } from './people.js'
import type { Section } from './section.js'
import {
  channels,
  customerGroups,
  markets,
  stockLocations,
  store,
  suppliers,
  taxCategories,
} from './settings.js'

/**
 * Sections in dependency order: a section comes after every section it can
 * reference, so a run creates targets before the records pointing at them.
 * Prune runs the same list backwards.
 */
export const ORDERED_SECTIONS: Section<never>[] = [
  store,
  stockLocations,
  channels,
  markets,
  customerGroups,
  taxCategories,
  deliveryZones,
  deliveryMethods,
  suppliers,
  categories,
  products,
  customers,
  sellers,
] as Section<never>[]

export const SECTIONS: Record<SectionName, Section<never>> = Object.fromEntries(
  ORDERED_SECTIONS.map((section) => [section.name, section]),
) as Record<SectionName, Section<never>>

/** Resources the file references by key but does not manage. */
const REFERENCE_SOURCES: Record<string, SectionSource> = {
  product_types: {
    path: '/product_types',
    keyAttribute: 'name',
    filterable: true,
    liveKey: (live) => String(live.name),
    fileKeys: () => [],
  },
}

export const SOURCES: Record<string, SectionSource> = {
  ...REFERENCE_SOURCES,
  ...SECTIONS,
}

export type { Section } from './section.js'
