import { RelativeTime } from '@spree/dashboard-ui'
import i18n from 'i18next'
import type { ColumnDef } from './table-registry'

const TIMESTAMP_KEYS = ['created_at', 'updated_at'] as const

type TimestampKey = (typeof TIMESTAMP_KEYS)[number]

const TIMESTAMP_CLASS = 'text-sm text-muted-foreground whitespace-nowrap'

function createTimestampColumn(key: TimestampKey, visibleByDefault = false): ColumnDef {
  return {
    key,
    label: i18n.t(`admin.fields.${key}.label`),
    sortable: true,
    filterable: true,
    default: visibleByDefault,
    filterType: 'date',
    className: TIMESTAMP_CLASS,
    render: (row) => <RelativeTime iso={row[key]} />,
  }
}

function enhanceTimestampColumn(col: ColumnDef, key: TimestampKey): ColumnDef {
  const sortable = col.sortable !== false
  const filterable = col.filterable !== false

  return {
    ...col,
    label: col.label || i18n.t(`admin.fields.${key}.label`),
    sortable,
    filterable,
    ...(filterable ? { filterType: 'date' as const } : {}),
    default: col.default ?? false,
    className: col.className ?? TIMESTAMP_CLASS,
    render: col.render ?? ((row) => <RelativeTime iso={row[key]} />),
  } as ColumnDef
}

/**
 * Ensures every table exposes `created_at` and `updated_at` as sortable,
 * filterable date columns. Missing columns are appended (hidden by default);
 * existing definitions are preserved and augmented with sort/filter when absent.
 */
export function ensureTimestampColumns(columns: ColumnDef[]): ColumnDef[] {
  const result = [...columns]

  for (const key of TIMESTAMP_KEYS) {
    const index = result.findIndex((col) => col.key === key)
    if (index === -1) {
      result.push(createTimestampColumn(key))
    } else {
      result[index] = enhanceTimestampColumn(result[index], key)
    }
  }

  return result
}
