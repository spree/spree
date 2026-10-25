// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { DimensionUnit } from '../generated'
import type { WeightUnit } from '../generated'

export type PackageTypeCreateParams = {
  name: string
  kind?: 'box' | 'envelope' | 'carton' | 'pallet' | 'container'
  length?: number | null
  width?: number | null
  height?: number | null
  dimensions_unit?: DimensionUnit | null
  /** The empty package's own weight, added to every quote. */
  weight?: number | null
  max_weight?: number | null
  weight_unit?: WeightUnit | null
  /**
   * Makes this the box this seller's parcels are quoted with. One default per seller, so it never
   * displaces the marketplace's.
   */
  default?: boolean
  metadata?: Record<string, unknown> | null
}
