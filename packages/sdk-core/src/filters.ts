/**
 * Building blocks for the generated list filter types.
 *
 * Each SDK's `types/filters.generated.ts` composes these from the
 * `x-spree-filters` tables in its OpenAPI spec, so a filter key is typed
 * exactly as the API accepts it: `TextFilters<'number'>` yields
 * `number_eq`, `number_cont`, `number_in`, `number_null` and so on. The
 * predicates per value kind are the ones the API publishes.
 */

/**
 * The predicates per kind of value, split by what each takes: one value, a
 * list, or a flag. `generate:filters` refuses to run when these differ from
 * the predicates the API reference publishes.
 */
export const FILTER_PREDICATES = {
  text: {
    value: ['eq', 'not_eq', 'cont', 'i_cont', 'not_cont', 'start', 'end'],
    list: ['in', 'not_in'],
    flag: ['null', 'not_null', 'present', 'blank'],
  },
  range: {
    value: ['eq', 'not_eq', 'lt', 'lteq', 'gt', 'gteq'],
    list: ['in', 'not_in'],
    flag: ['null', 'not_null'],
  },
  equality: { value: ['eq', 'not_eq'], list: ['in', 'not_in'], flag: ['null', 'not_null'] },
  boolean: { value: ['eq', 'not_eq'], list: ['in', 'not_in'], flag: ['true', 'false', 'null'] },
} as const

type Predicates = typeof FILTER_PREDICATES
type Kind = keyof Predicates

type Keyed<K extends string, P extends string, V> = { [Key in K as `${Key}_${P}`]?: V }

type KindFilters<K extends string, Of extends Kind, V> = Keyed<
  K,
  Predicates[Of]['value'][number],
  V
> &
  Keyed<K, Predicates[Of]['list'][number], V[]> &
  Keyed<K, Predicates[Of]['flag'][number], boolean>

/** Text attributes. */
export type TextFilters<K extends string> = KindFilters<K, 'text', string>

/** Ordered values: amounts (decimal strings, never floats), counts, dates and timestamps. */
export type RangeFilters<K extends string, V = string> = KindFilters<K, 'range', V>

/** One of a known set of values. Extensions may add values, so others are accepted too. */
export type EnumFilters<K extends string, V extends string> = KindFilters<
  K,
  'equality',
  V | (string & {})
>

/** Prefixed IDs (`prod_86Rf07xd4z`) and type short names (`credit_card`). */
export type IdFilters<K extends string> = KindFilters<K, 'equality', string>

export type BooleanFilters<K extends string> = KindFilters<K, 'boolean', boolean>

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

type SortField<K extends string> = K | `-${K}`

/** A sort field, ascending or descending with a `-` prefix, or two of them comma-separated. */
export type SortKey<K extends string> = SortField<K> | `${SortField<K>},${SortField<K>}`
