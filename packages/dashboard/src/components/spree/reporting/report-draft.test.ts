import type { ReportingSchema } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import { draftFromQuery, draftWithMetric, familyOfMetrics } from './report-draft'

// A cut-down stand-in for the real schema: two families, each with its own
// time dimension, plus one value dimension per family.
const schema = {
  meta: { currency: 'USD', timezone: 'UTC', supported_currencies: ['USD'] },
  families: [
    {
      name: 'sales',
      label: 'Sales',
      metrics: ['total_sales', 'orders'],
      dimensions: ['completed_at', 'payment_status'],
    },
    {
      name: 'payments',
      label: 'Payments',
      metrics: ['payments_received'],
      dimensions: ['paid_at', 'payment_method'],
    },
  ],
  metrics: [
    { name: 'total_sales', family: 'sales', label: 'Total sales', format: 'money', derived: false },
    { name: 'orders', family: 'sales', label: 'Orders', format: 'integer', derived: false },
    {
      name: 'payments_received',
      family: 'payments',
      label: 'Payments received',
      format: 'money',
      derived: false,
    },
  ],
  dimensions: [
    {
      name: 'completed_at',
      label: 'Order date',
      type: 'time',
      grains: ['hour', 'day', 'week'],
      filter_ops: ['eq', 'in'] as Array<'eq' | 'in'>,
      compatible_metrics: ['total_sales', 'orders'],
    },
    {
      name: 'payment_status',
      label: 'Payment status',
      type: 'value',
      filter_ops: ['eq', 'in'] as Array<'eq' | 'in'>,
      compatible_metrics: ['total_sales', 'orders'],
    },
    {
      name: 'paid_at',
      label: 'Payment date',
      type: 'time',
      grains: ['hour', 'day', 'week'],
      filter_ops: ['eq', 'in'] as Array<'eq' | 'in'>,
      compatible_metrics: ['payments_received'],
    },
    {
      name: 'payment_method',
      label: 'Payment method',
      type: 'value',
      filter_ops: ['eq', 'in'] as Array<'eq' | 'in'>,
      compatible_metrics: ['payments_received'],
    },
  ],
  time_range: {
    presets: [{ name: 'last_4_weeks', label: 'Last 4 weeks' }],
    relative: [],
    absolute: '',
  },
  limits: { default: 50, max: 500, max_buckets: 2000 },
} as unknown as ReportingSchema

const salesDraft = () =>
  draftFromQuery(
    {
      metrics: ['total_sales', 'orders'],
      dimensions: [{ name: 'completed_at', grain: 'day' }],
      time_range: { preset: 'last_4_weeks' },
    },
    schema,
  )

describe('familyOfMetrics', () => {
  it('names the family the selection belongs to', () => {
    expect(familyOfMetrics(schema, ['orders'])?.name).toBe('sales')
    expect(familyOfMetrics(schema, ['payments_received'])?.name).toBe('payments')
  })

  it('answers null for an empty selection', () => {
    expect(familyOfMetrics(schema, [])).toBeNull()
  })
})

describe('draftWithMetric', () => {
  it('adds and removes a metric within one family', () => {
    const draft = salesDraft()

    const without = draftWithMetric(draft, schema, 'orders', false)
    expect(without.metrics).toEqual(['total_sales'])
    expect(without.dimension).toBe('completed_at')

    const back = draftWithMetric(without, schema, 'orders', true)
    expect(back.metrics).toEqual(['total_sales', 'orders'])
  })

  it('switches family and moves the breakdown to that family’s time dimension', () => {
    const next = draftWithMetric(salesDraft(), schema, 'payments_received', true)

    expect(next.metrics).toEqual(['payments_received'])
    expect(next.dimension).toBe('paid_at')
    expect(next.grain).toBe('day')
  })

  it('keeps the grain when switching family', () => {
    const hourly = { ...salesDraft(), grain: 'hour' as const, timeRange: { preset: 'today' } }

    expect(draftWithMetric(hourly, schema, 'payments_received', true).grain).toBe('hour')
  })

  it('drops filters the new family cannot express', () => {
    const filtered = {
      ...salesDraft(),
      filters: [{ dimension: 'payment_status', values: ['paid'] }],
    }

    const next = draftWithMetric(filtered, schema, 'payments_received', true)

    expect(next.filters).toEqual([])
  })

  it('carries no breakdown across families when the current one is not a time dimension', () => {
    const ranked = { ...salesDraft(), dimension: 'payment_status', sortMetric: 'orders' }

    const next = draftWithMetric(ranked, schema, 'payments_received', true)

    expect(next.dimension).toBeNull()
    expect(next.sortMetric).toBeNull()
  })

  it('clears a breakdown the remaining metrics can no longer be grouped by', () => {
    const mixed = { ...salesDraft(), metrics: ['payments_received'], dimension: 'paid_at' }

    // Ticking a sales metric switches back, so paid_at cannot survive.
    const next = draftWithMetric(mixed, schema, 'orders', true)

    expect(next.metrics).toEqual(['orders'])
    expect(next.dimension).toBe('completed_at')
  })

  it('clears the breakdown once the last metric is unticked', () => {
    let draft = draftWithMetric(salesDraft(), schema, 'total_sales', false)
    draft = draftWithMetric(draft, schema, 'orders', false)

    expect(draft.metrics).toEqual([])
    // A leftover sales breakdown would rule out every other family's metrics.
    expect(draft.dimension).toBeNull()
  })

  it('reaches another family after the defaults are cleared', () => {
    let draft = draftWithMetric(salesDraft(), schema, 'total_sales', false)
    draft = draftWithMetric(draft, schema, 'orders', false)

    const next = draftWithMetric(draft, schema, 'payments_received', true)

    expect(next.metrics).toEqual(['payments_received'])
    expect(next.dimension).toBeNull()
  })

  it('drops a filter left behind by clearing every metric', () => {
    const filtered = {
      ...salesDraft(),
      filters: [{ dimension: 'payment_status', values: ['paid'] }],
    }

    let draft = draftWithMetric(filtered, schema, 'total_sales', false)
    draft = draftWithMetric(draft, schema, 'orders', false)

    expect(draft.filters).toEqual([])
  })

  it('leaves the draft alone when the schema has not loaded', () => {
    const next = draftWithMetric(salesDraft(), undefined, 'payments_received', true)

    expect(next.metrics).toEqual(['total_sales', 'orders', 'payments_received'])
  })
})
