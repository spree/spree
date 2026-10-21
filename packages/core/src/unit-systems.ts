import type { WeightUnit } from './code-lists.generated'

/** The measurement systems a store can use. */
export type UnitSystem = 'metric' | 'imperial'

export const UNIT_SYSTEMS: readonly UnitSystem[] = ['metric', 'imperial']

/** The weight units each system offers, the usual one first. */
export const UNIT_SYSTEM_WEIGHT_UNITS: Readonly<Record<UnitSystem, readonly WeightUnit[]>> = {
  metric: ['kg', 'g'],
  imperial: ['lb', 'oz'],
}
