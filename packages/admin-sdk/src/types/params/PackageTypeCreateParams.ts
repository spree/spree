// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type PackageTypeCreateParams = {
  /** Unique within the store. */
  name: string
  /**
   * What this packaging is: the box parcels ship in, or the carton, pallet or container a wholesale
   * order leaves on.
   */
  kind: 'box' | 'envelope' | 'carton' | 'pallet' | 'container'
  length?: number | null
  width?: number | null
  height?: number | null
  /** Unit the three dimensions are in; falls back to the store's unit system. */
  dimensions_unit?: 'mm' | 'cm' | 'in' | 'ft' | null
  /** The empty package's own weight, added to content weight on every quote. */
  weight?: number | null
  /** What the package can hold, not the same as its own weight. */
  max_weight?: number | null
  weight_unit?: 'g' | 'kg' | 'lb' | 'oz' | null
  /** The box every parcel quote is built on. Setting this demotes whichever row held it. */
  default?: boolean
  metadata?: Record<string, unknown>
}
