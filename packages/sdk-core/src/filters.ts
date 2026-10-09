/**
 * Building blocks for the generated list filter types.
 *
 * Each SDK's `types/filters.generated.ts` composes these from the
 * `x-spree-filters` tables in its OpenAPI spec, so a filter key is typed
 * exactly as the API accepts it: `TextFilters<'number'>` yields
 * `number_eq`, `number_cont`, `number_in`, `number_null` and so on. The
 * predicates per value kind are the ones the API publishes.
 */

type Keyed<K extends string, P extends string, V> = { [Key in K as `${Key}_${P}`]?: V }

type Flags<K extends string, P extends string> = Keyed<K, P, boolean>

/** Text attributes. */
export type TextFilters<K extends string> = Keyed<
  K,
  'eq' | 'not_eq' | 'cont' | 'i_cont' | 'not_cont' | 'start' | 'end',
  string
> &
  Keyed<K, 'in' | 'not_in', string[]> &
  Flags<K, 'null' | 'not_null' | 'present' | 'blank'>

/** Ordered values: amounts (decimal strings), counts, dates and timestamps. */
export type RangeFilters<K extends string, V = string> = Keyed<
  K,
  'eq' | 'not_eq' | 'lt' | 'lteq' | 'gt' | 'gteq',
  V
> &
  Keyed<K, 'in' | 'not_in', V[]> &
  Flags<K, 'null' | 'not_null'>

/** One of a known set of values. Extensions may add values, so others are accepted too. */
export type EnumFilters<K extends string, V extends string> = Keyed<
  K,
  'eq' | 'not_eq',
  V | (string & {})
> &
  Keyed<K, 'in' | 'not_in', (V | (string & {}))[]> &
  Flags<K, 'null' | 'not_null'>

/** Prefixed IDs (`prod_86Rf07xd4z`) and type short names (`credit_card`). */
export type IdFilters<K extends string> = Keyed<K, 'eq' | 'not_eq', string> &
  Keyed<K, 'in' | 'not_in', string[]> &
  Flags<K, 'null' | 'not_null'>

export type BooleanFilters<K extends string> = Keyed<K, 'eq' | 'not_eq', boolean> &
  Keyed<K, 'in' | 'not_in', boolean[]> &
  Flags<K, 'true' | 'false' | 'null'>

/** An associated record's filters, reached through the association's name. */
export type Prefixed<P extends string, T> = { [Key in keyof T as `${P}${Key & string}`]: T[Key] }

/**
 * `name_or_code_cont`: several text attributes of the same record sharing
 * one predicate. Typed loosely; prefer a `search` filter where one exists.
 */
export type OrFilters = { [key: `${string}_or_${string}`]: string | string[] | boolean | undefined }

/** The store's searchable custom fields (`cf_<namespace>_<key>_<predicate>`), which vary per store. */
export type CustomFieldFilters = {
  [key: `cf_${string}`]: string | number | boolean | string[] | undefined
}

/** A sort field, ascending, or descending with a `-` prefix; several are comma-separated. */
export type SortKey<K extends string> = K | `-${K}` | `${K | `-${K}`},${string}`
