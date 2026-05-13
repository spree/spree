import { Link } from '@tanstack/react-router'
import type { ColumnDef } from '@tanstack/react-table'
import { ExternalLinkIcon } from 'lucide-react'
import { useMemo } from 'react'
import { Controller, type UseFormReturn, useWatch } from 'react-hook-form'
import { DataGrid, NumberCell, ReadOnlyCell, SwitchCell } from '@/components/spree/data-grid'
import type { ProductFormValues } from '@/schemas/product'

interface InventoryRow {
  /** Composite ID `${variantIndex}.${itemIndex}` (or `${variantIndex}.header` for headers). */
  id: string
  kind: 'header' | 'item'
  variantIndex: number
  itemIndex: number
  /** Header rows: variant label. Item rows: location name. */
  headerLabel?: string
  headerSku?: string | null
  stockLocationId?: string
  stockLocationName?: string
}

const LOW_STOCK_THRESHOLD = 5

interface InventorySectionProps {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
  storeId: string
  hasVariants: boolean
}

export function InventorySection({ form, storeId, hasVariants }: InventorySectionProps) {
  // Subscribe to the array so the rows recompute when the user adds/removes
  // a variant. We don't need finer reactivity here — individual cell values
  // are wired via Controllers below, which re-render only their own cell.
  const variantsInventory = useWatch({ control: form.control, name: 'variants_inventory' }) ?? []

  const rows = useMemo<InventoryRow[]>(() => {
    const out: InventoryRow[] = []
    variantsInventory.forEach((variant, variantIndex) => {
      const variantLabel = variant.options_text || variant.sku || 'Default'
      if (hasVariants) {
        out.push({
          id: `${variantIndex}.header`,
          kind: 'header',
          variantIndex,
          itemIndex: -1,
          headerLabel: variantLabel,
          headerSku: variant.sku ?? null,
        })
      }
      variant.stock_items.forEach((si, itemIndex) => {
        out.push({
          id: `${variantIndex}.${itemIndex}`,
          kind: 'item',
          variantIndex,
          itemIndex,
          stockLocationId: si.stock_location_id,
          stockLocationName: si.stock_location_name,
        })
      })
    })
    return out
  }, [variantsInventory, hasVariants])

  const columns = useMemo<ColumnDef<InventoryRow>[]>(
    () => [
      {
        id: 'location',
        header: 'Location',
        cell: ({ row }) => {
          const r = row.original
          if (r.kind !== 'item') return null
          return (
            <ReadOnlyCell>
              {r.stockLocationId ? (
                <Link
                  to="/$storeId/settings/stock-locations"
                  params={{ storeId }}
                  search={{ edit: r.stockLocationId }}
                  className="inline-flex items-center gap-1 hover:underline"
                >
                  {r.stockLocationName}
                  <ExternalLinkIcon className="size-3 text-muted-foreground" />
                </Link>
              ) : (
                <span>{r.stockLocationName}</span>
              )}
            </ReadOnlyCell>
          )
        },
      },
      {
        id: 'count_on_hand',
        header: () => <span className="block text-right">On hand</span>,
        cell: ({ row, table }) => {
          const r = row.original
          if (r.kind !== 'item') return null
          const coords = { row: editableRowIndex(table.getRowModel().rows, row.id), col: 1 }
          return (
            <Controller
              name={`variants_inventory.${r.variantIndex}.stock_items.${r.itemIndex}.count_on_hand`}
              control={form.control}
              render={({ field }) => {
                const value = field.value ?? 0
                const intent =
                  value < LOW_STOCK_THRESHOLD ? ('warning' as const) : ('default' as const)
                return (
                  <NumberCell
                    coords={coords}
                    value={value}
                    onChange={field.onChange}
                    ariaLabel={`On hand at ${r.stockLocationName}`}
                    intent={intent}
                  />
                )
              }}
            />
          )
        },
      },
      {
        id: 'backorderable',
        header: 'Backorder',
        cell: ({ row, table }) => {
          const r = row.original
          if (r.kind !== 'item') return null
          const coords = { row: editableRowIndex(table.getRowModel().rows, row.id), col: 2 }
          return (
            <Controller
              name={`variants_inventory.${r.variantIndex}.stock_items.${r.itemIndex}.backorderable`}
              control={form.control}
              render={({ field }) => (
                <SwitchCell
                  coords={coords}
                  value={field.value ?? false}
                  onChange={field.onChange}
                  ariaLabel={`Allow backorder at ${r.stockLocationName}`}
                />
              )}
            />
          )
        },
      },
    ],
    [form, storeId],
  )

  if (rows.length === 0) {
    return (
      <p className="text-sm text-muted-foreground">
        Stock levels are managed per stock location. Add a variant to start tracking inventory.
      </p>
    )
  }

  return (
    <DataGrid<InventoryRow>
      rows={rows}
      columns={columns}
      getRowId={(row) => row.id}
      renderSectionHeader={(row) =>
        row.kind === 'header' ? (
          <div className="min-w-0">
            <div className="truncate font-medium">{row.headerLabel}</div>
            {row.headerSku && (
              <div className="truncate text-xs text-muted-foreground">SKU {row.headerSku}</div>
            )}
          </div>
        ) : null
      }
      aria-label="Stock at locations"
    />
  )
}

// Counts editable (non-header) rows up to and including the given row id so the
// cell at that position has stable grid coords that exclude header rows.
function editableRowIndex<T extends { kind: 'header' | 'item'; id: string }>(
  rows: ReadonlyArray<{ id: string; original: T }>,
  rowId: string,
): number {
  let i = 0
  for (const row of rows) {
    if (row.original.kind !== 'item') continue
    if (row.id === rowId) return i
    i++
  }
  return i
}
