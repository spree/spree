import type { WeightUnit } from './code-lists.generated'
import type { UnitSystem } from './enums.generated'

/** The weight units each system offers, the usual one first. */
export const UNIT_SYSTEM_WEIGHT_UNITS: Readonly<Record<UnitSystem, readonly WeightUnit[]>> = {
  metric: ['kg', 'g'],
  imperial: ['lb', 'oz'],
}
