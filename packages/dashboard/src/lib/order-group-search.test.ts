import { describe, expect, it } from 'vitest'
import { orderGroupSearch } from './order-group-search'

describe('orderGroupSearch', () => {
  it('encodes the filter the way the resource table reads it back', () => {
    const search = orderGroupSearch('ogrp_abc123')

    expect(JSON.parse(search.filters)).toEqual([
      { id: 'order-group-ogrp_abc123', field: 'order_group', operator: 'eq', value: 'ogrp_abc123' },
    ])
  })

  // The table maps the `order_group` column onto the order_group_id Ransack
  // attribute, so the rule names the column rather than the attribute.
  it('names the column, which is what the table resolves filters by', () => {
    const [rule] = JSON.parse(orderGroupSearch('ogrp_abc123').filters)

    expect(rule.field).toBe('order_group')
  })

  it('leaves the visible columns alone', () => {
    expect(orderGroupSearch('ogrp_abc123')).not.toHaveProperty('columns')
  })
})
