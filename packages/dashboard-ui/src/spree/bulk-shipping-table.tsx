import type { ColumnDef } from '@tanstack/react-table'
import { useMemo } from 'react'
import { DataGrid, DecimalCell, ReadOnlyCell } from './data-grid'

export interface BulkShippingRow {
  id: string
  variantLabel?: string | null
  sku?: string | null
  // Display strings — decimal weight/dimension values, or null for unset.
  weight?: string | null
  height?: string | null
  width?: string | null
  depth?: string | null
}

export type BulkShippingField = 'weight' | 'height' | 'width' | 'depth'

export interface BulkShippingTableLabels {
  /** Column header for the variant label column. */
  variant: string
  /** Column header for the SKU column. */
  sku: string
  /** Column headers for the editable measurement columns. */
  weight: string
  height: string
  width: string
  depth: string
  /** Placeholder for a variant row with no options text (e.g. "Default"). */
  variantDefault: string
  /** Shown when rows.length === 0. */
  emptyMessage?: string
  /** Aria label on the DataGrid for screen readers. */
  gridAriaLabel?: string
}

export interface BulkShippingTableProps {
  rows: BulkShippingRow[]
  /** Localized strings — the caller owns translations. */
  labels: BulkShippingTableLabels
  /** Called when the user commits a value to a cell. The id is the row id. */
  onChange: (rowId: string, field: BulkShippingField, value: string | null) => void
}

// Editable columns in grid order; the +2 offset skips the two read-only
// leading columns when assigning keyboard-navigation coordinates.
const FIELDS: BulkShippingField[] = ['weight', 'height', 'width', 'depth']

/**
 * Presentational primitive for a "spreadsheet of variant shipping fields" UI.
 * Owns the DataGrid columns and decimal-cell wiring; selection, copy/paste,
 * and drag-fill come from the DataGrid. Owns NO data fetching, edit tracking,
 * or save logic — the caller projects its rows into BulkShippingRow shape and
 * writes edits back through `onChange`.
 */
export function BulkShippingTable({ rows, labels, onChange }: BulkShippingTableProps) {
  const columns = useMemo<ColumnDef<BulkShippingRow>[]>(
    () => [
      {
        id: 'variant',
        header: labels.variant,
        cell: ({ row }) => (
          <ReadOnlyCell className="text-muted-foreground">
            {row.original.variantLabel ?? labels.variantDefault}
          </ReadOnlyCell>
        ),
      },
      {
        id: 'sku',
        header: labels.sku,
        cell: ({ row }) => (
          <ReadOnlyCell className="font-mono text-xs text-muted-foreground">
            {row.original.sku ?? '—'}
          </ReadOnlyCell>
        ),
      },
      ...FIELDS.map<ColumnDef<BulkShippingRow>>((field, fieldIndex) => ({
        id: field,
        header: () => <span className="block text-right">{labels[field]}</span>,
        cell: ({ row }) => {
          const r = row.original
          // No section-header rows in this grid, so the table row index IS
          // the keyboard-navigation row coordinate.
          const coords = { row: row.index, col: fieldIndex + 2 }
          const label = r.variantLabel ?? labels.variantDefault
          return (
            <DecimalCell
              coords={coords}
              value={r[field] ?? null}
              onChange={(next) => onChange(r.id, field, next)}
              ariaLabel={`${labels[field]} — ${label}`}
            />
          )
        },
      })),
    ],
    [onChange, labels],
  )

  if (rows.length === 0) {
    return <p className="text-sm text-muted-foreground">{labels.emptyMessage ?? ''}</p>
  }

  return (
    <DataGrid<BulkShippingRow>
      rows={rows}
      columns={columns}
      getRowId={(row) => row.id}
      aria-label={labels.gridAriaLabel}
    />
  )
}
