import type { ColumnDef } from '@tanstack/react-table'
import { useMemo } from 'react'
import { Button } from '../ui/button'
import { Input } from '../ui/input'
import { DataGrid, editableRowIndex, MoneyCell, ReadOnlyCell } from './data-grid'

export interface BulkPriceRow {
  // Unique row id. For header rows use a synthetic key (e.g. `header:<groupId>`);
  // the table renders headers via `renderSectionHeader` without an editable cell.
  id: string
  kind: 'header' | 'item'
  // Header rows: the section title (typically the product name).
  groupLabel?: string
  // Item rows.
  variantLabel?: string | null
  sku?: string | null
  // Display strings — the caller decides whether to ship the locale-formatted
  // user input or the API's canonical decimal. The table passes them through.
  amount?: string | null
  compareAt?: string | null
}

export interface BulkPriceTableLabels {
  /** Column header for the variant label column. */
  variant: string
  /** Column header for the SKU column. */
  sku: string
  /** Column header for the amount column. */
  price: string
  /** Column header for the compare-at-amount column. */
  compareAt: string
  /** Placeholder for a variant row with no options text (e.g. "Default"). */
  variantDefault: string
  /** Placeholder text for the search input. Omit to hide the search input. */
  searchPlaceholder?: string
  /** A short message shown above the grid summarising the matching row count. */
  countSummary?: string
  /** Shown when the loading flag is set. */
  loading: string
  /** Page-of indicator template, e.g. "Page {page} of {total}". `{page}` and `{total}` are substituted. */
  pageOf: string
  /** Previous-page button label. */
  prev: string
  /** Next-page button label. */
  next: string
  /** Shown when not loading and rows.length === 0 and no search query. */
  emptyMessage?: string
  /** Shown when not loading and rows.length === 0 and a search query is set. */
  emptySearchMessage?: string
  /** Aria label on the DataGrid for screen readers. */
  gridAriaLabel?: string
  /** Aria-label template for the amount input. `{label}` is replaced with the variant label. */
  priceAriaTemplate?: string
  /** Aria-label template for the compare-at input. `{label}` is replaced with the variant label. */
  compareAtAriaTemplate?: string
}

export interface BulkPriceTableProps {
  rows: BulkPriceRow[]
  /** Currency symbol shown inside the money cells (e.g. "$", "€"). */
  symbol: string
  /** Decimal separator used by the cell formatter (e.g. "." or ","). */
  decimal: string
  /** Localized strings — the caller owns translations. */
  labels: BulkPriceTableLabels
  /** Called when the user commits a value to a cell. The id is the row id. */
  onChange: (rowId: string, field: 'amount' | 'compareAt', value: string | null) => void

  // Optional state for the toolbar + pagination footer. Omitting all of these
  // hides the toolbar/pagination entirely (use for in-memory single-page lists).
  search?: string
  onSearchChange?: (next: string) => void
  page?: number
  totalPages?: number
  onPageChange?: (next: number) => void
  isLoading?: boolean
}

/**
 * Presentational primitive for any "spreadsheet of variant prices" UI. Owns
 * the DataGrid columns, money-cell wiring, currency-aware formatting, search
 * input, and pagination footer. Owns NO data fetching, edit tracking, or save
 * logic — the caller projects its rows into BulkPriceRow shape and writes
 * edits back through `onChange`.
 */
export function BulkPriceTable({
  rows,
  symbol,
  decimal,
  labels,
  onChange,
  search,
  onSearchChange,
  page,
  totalPages,
  onPageChange,
  isLoading,
}: BulkPriceTableProps) {
  const columns = useMemo<ColumnDef<BulkPriceRow>[]>(
    () => [
      {
        id: 'variant',
        header: labels.variant,
        cell: ({ row }) => {
          const r = row.original
          if (r.kind !== 'item') return null
          return (
            <ReadOnlyCell className="text-muted-foreground">
              {r.variantLabel ?? labels.variantDefault}
            </ReadOnlyCell>
          )
        },
      },
      {
        id: 'sku',
        header: labels.sku,
        cell: ({ row }) => {
          const r = row.original
          if (r.kind !== 'item') return null
          return (
            <ReadOnlyCell className="font-mono text-xs text-muted-foreground">
              {r.sku ?? '—'}
            </ReadOnlyCell>
          )
        },
      },
      {
        id: 'amount',
        header: () => <span className="block text-right">{labels.price}</span>,
        cell: ({ row, table }) => {
          const r = row.original
          if (r.kind !== 'item') return null
          const coords = { row: editableRowIndex(table.getRowModel().rows, row.id), col: 2 }
          const label = r.variantLabel ?? labels.variantDefault
          return (
            <MoneyCell
              coords={coords}
              value={r.amount ?? null}
              onChange={(next) => onChange(r.id, 'amount', next)}
              symbol={symbol}
              decimal={decimal}
              ariaLabel={labels.priceAriaTemplate?.replace('{label}', label) ?? label}
            />
          )
        },
      },
      {
        id: 'compare_at',
        header: () => <span className="block text-right">{labels.compareAt}</span>,
        cell: ({ row, table }) => {
          const r = row.original
          if (r.kind !== 'item') return null
          const coords = { row: editableRowIndex(table.getRowModel().rows, row.id), col: 3 }
          const label = r.variantLabel ?? labels.variantDefault
          return (
            <MoneyCell
              coords={coords}
              value={r.compareAt ?? null}
              onChange={(next) => onChange(r.id, 'compareAt', next)}
              symbol={symbol}
              decimal={decimal}
              ariaLabel={labels.compareAtAriaTemplate?.replace('{label}', label) ?? label}
            />
          )
        },
      },
    ],
    [symbol, decimal, onChange, labels],
  )

  const showToolbar =
    labels.countSummary !== undefined ||
    (onSearchChange !== undefined && labels.searchPlaceholder !== undefined)
  const showPagination =
    page !== undefined && totalPages !== undefined && totalPages > 1 && onPageChange !== undefined
  const isEmpty = !isLoading && rows.length === 0
  const hasSearch = !!search && search.length > 0

  return (
    <div className="flex h-full flex-col gap-3">
      {showToolbar && (
        // Always-mounted toolbar. Conditionally rendering the search input
        // would unmount it whenever a deferred query refetches into the
        // loading state, blurring the field mid-keystroke.
        <div className="flex shrink-0 items-center justify-between gap-3">
          {labels.countSummary !== undefined && (
            <p className="text-xs text-muted-foreground">{labels.countSummary}</p>
          )}
          {onSearchChange !== undefined && labels.searchPlaceholder !== undefined && (
            <Input
              type="search"
              placeholder={labels.searchPlaceholder}
              value={search ?? ''}
              onChange={(e) => onSearchChange(e.target.value)}
              className="h-9 max-w-sm"
            />
          )}
        </div>
      )}

      <div className="min-h-0 flex-1 overflow-auto">
        {isLoading ? (
          <p className="text-sm text-muted-foreground">{labels.loading}</p>
        ) : isEmpty ? (
          <p className="text-sm text-muted-foreground">
            {hasSearch
              ? (labels.emptySearchMessage ?? labels.emptyMessage ?? '')
              : (labels.emptyMessage ?? '')}
          </p>
        ) : (
          <DataGrid<BulkPriceRow>
            rows={rows}
            columns={columns}
            getRowId={(row) => row.id}
            renderSectionHeader={(row) =>
              row.kind === 'header' ? (
                <div className="truncate font-medium">{row.groupLabel}</div>
              ) : null
            }
            aria-label={labels.gridAriaLabel}
          />
        )}
      </div>

      {showPagination && (
        <div className="flex shrink-0 items-center justify-between gap-2 text-xs text-muted-foreground">
          <span>
            {labels.pageOf.replace('{page}', String(page)).replace('{total}', String(totalPages))}
          </span>
          <div className="flex gap-1">
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={() => onPageChange(Math.max(1, page - 1))}
              disabled={page === 1 || isLoading}
            >
              {labels.prev}
            </Button>
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={() => onPageChange(Math.min(totalPages, page + 1))}
              disabled={page === totalPages || isLoading}
            >
              {labels.next}
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}
