import { describe, expect, it } from 'vitest'
import { filtersToRansack } from './filters-to-ransack'
import type { ColumnDef, FilterRule } from './table-registry'

const columns: ColumnDef[] = [
  { key: 'completed_at', label: 'Date', filterType: 'date' },
  { key: 'status', label: 'Status', filterType: 'enum', filterOptions: [] },
  { key: 'tags', label: 'Tags', filterType: 'tags', taggableType: 'Spree::Product' },
  { key: 'sku', label: 'SKU', ransackAttribute: 'master_sku' },
  {
    key: 'companies',
    label: 'Companies',
    filterType: 'resource',
    ransackAttribute: 'with_standing_for_company',
    ransackScope: true,
    filterResource: {
      queryKey: 'companies',
      search: async () => ({ data: [], meta: { count: 0, page: 1, pages: 0 } }),
      hydrate: async () => ({ data: [], meta: { count: 0, page: 1, pages: 0 } }),
      getOptionLabel: () => '',
    },
  },
]

const rule = (partial: Partial<FilterRule>): FilterRule => ({
  id: 'r1',
  field: 'completed_at',
  operator: 'lteq',
  value: '2026-08-29',
  ...partial,
})

describe('filtersToRansack', () => {
  it('carries a date upper bound to the end of its day', () => {
    // The columns these target are datetimes, so a bare date casts to
    // midnight — "up to the 29th" would drop everything that happened on the
    // 29th, which is usually the very rows the operator is looking for.
    expect(filtersToRansack([rule({})], columns)).toEqual({
      completed_at_lteq: '2026-08-29 23:59:59.999999',
    })
  })

  it('leaves a date lower bound alone, since midnight already starts the day', () => {
    expect(filtersToRansack([rule({ operator: 'gteq', value: '2026-08-01' })], columns)).toEqual({
      completed_at_gteq: '2026-08-01',
    })
  })

  it('emits both ends of a range', () => {
    const filters = [
      rule({ id: 'a', operator: 'gteq', value: '2026-08-01' }),
      rule({ id: 'b', operator: 'lteq', value: '2026-08-29' }),
    ]
    expect(filtersToRansack(filters, columns)).toEqual({
      completed_at_gteq: '2026-08-01',
      completed_at_lteq: '2026-08-29 23:59:59.999999',
    })
  })

  it('does not widen a non-date column that happens to use lteq', () => {
    const columnsWithNumber: ColumnDef[] = [
      ...columns,
      { key: 'total', label: 'Total', filterType: 'number' },
    ]
    const filters = [rule({ field: 'total', operator: 'lteq', value: '100' })]
    expect(filtersToRansack(filters, columnsWithNumber)).toEqual({ total_lteq: '100' })
  })

  it('splits array operators into a list', () => {
    const filters = [rule({ field: 'status', operator: 'in', value: 'active,draft' })]
    expect(filtersToRansack(filters, columns)).toEqual({ status_in: ['active', 'draft'] })
  })

  it('drops an array operator with no values rather than filtering by nothing', () => {
    const filters = [rule({ field: 'status', operator: 'in', value: '' })]
    expect(filtersToRansack(filters, columns)).toEqual({})
  })

  it('targets the join column for tags', () => {
    const filters = [rule({ field: 'tags', operator: 'in', value: 'sale' })]
    expect(filtersToRansack(filters, columns)).toEqual({ tags_name_in: ['sale'] })
  })

  it('honours an explicit ransack alias', () => {
    const filters = [rule({ field: 'sku', operator: 'i_cont', value: 'ABC' })]
    expect(filtersToRansack(filters, columns)).toEqual({ master_sku_i_cont: 'ABC' })
  })

  // A scope is invoked by its bare name and takes the value as its argument,
  // so an operator suffix would name a predicate that does not exist and
  // silently filter nothing.
  it('sends a scope key without an operator suffix', () => {
    const filters = [rule({ field: 'companies', operator: 'in', value: 'comp_1,comp_2' })]

    expect(filtersToRansack(filters, columns)).toEqual({
      with_standing_for_company: ['comp_1', 'comp_2'],
    })
  })

  // A scope takes its value as an argument and cannot express negation, so
  // emitting the same bare key would run it as an inclusion — the exact
  // opposite of what the merchant picked.
  it('drops a negating operator on a scope column rather than inverting it', () => {
    const filters = [rule({ field: 'companies', operator: 'not_in', value: 'comp_1' })]

    expect(filtersToRansack(filters, columns)).toEqual({})
  })

  it('still drops an empty scope filter', () => {
    const filters = [rule({ field: 'companies', operator: 'in', value: '' })]
    expect(filtersToRansack(filters, columns)).toEqual({})
  })
})
