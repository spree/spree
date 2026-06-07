import {
  DataGrid,
  editableRowIndex,
  NumberCell,
  ReadOnlyCell,
  SwitchCell,
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import type { ColumnDef } from '@tanstack/react-table'
import { ExternalLinkIcon } from 'lucide-react'
import { useCallback, useMemo } from 'react'
import { type UseFormReturn, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useStockLocations } from '@/hooks/use-stock-locations'
import type { ProductFormValues, StockItemFormValues } from '@/schemas/product'

interface InventoryRow {
  /** Composite ID `${variantIndex}.${stockLocationId}` (or `${variantIndex}.header` for headers). */
  id: string
  kind: 'header' | 'item'
  variantIndex: number
  /** Header rows: variant label. */
  headerLabel?: string
  headerSku?: string | null
  /** Item rows: stock location identity. */
  stockLocationId?: string
  stockLocationName?: string
  /** Current values (snapshotted from form state for display). Cells are
   *  bound through the find-or-create handlers below, not through Controller,
   *  so we read values directly instead. */
  countOnHand?: number
  backorderable?: boolean
}

const LOW_STOCK_THRESHOLD = 5

interface InventorySectionProps {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
  storeId: string
}

export function InventorySection({ form, storeId }: InventorySectionProps) {
  const { t } = useTranslation()
  // Subscribe to the array so the rows recompute when the user adds/removes
  // a variant or edits a stock item. Cell edits route through findOrCreate
  // below, which calls form.setValue and re-triggers this watch.
  const variants = useWatch({ control: form.control, name: 'variants' }) ?? []
  const { data: stockLocationsData, isLoading: stockLocationsLoading } = useStockLocations()
  const stockLocations = stockLocationsData?.data ?? []

  // Derive "this product has real variants" from live form state, not the
  // API hydration — so adding options to a fresh product immediately groups
  // the inventory rows by variant header, instead of waiting until after save.
  const hasMultipleVariants = variants.length > 1

  const rows = useMemo<InventoryRow[]>(() => {
    if (stockLocations.length === 0) return []
    const out: InventoryRow[] = []
    variants.forEach((variant, variantIndex) => {
      const variantLabel =
        variant.options.map((o) => o.value).join(' / ') ||
        variant.sku ||
        t('admin.products.variants.default_variant')
      if (hasMultipleVariants) {
        out.push({
          id: `${variantIndex}.header`,
          kind: 'header',
          variantIndex,
          headerLabel: variantLabel,
          headerSku: variant.sku ?? null,
        })
      }
      // Render one row per (variant × location), regardless of whether a
      // stock_item exists in form state. Mirrors the pricing editor's
      // (variant × currency) projection. Missing entries display 0/false and
      // are created on first edit via findOrCreateStockItem below.
      stockLocations.forEach((loc) => {
        const existing = (variant.stock_items ?? []).find((si) => si.stock_location_id === loc.id)
        out.push({
          id: `${variantIndex}.${loc.id}`,
          kind: 'item',
          variantIndex,
          stockLocationId: loc.id,
          stockLocationName: loc.name,
          countOnHand: existing?.count_on_hand ?? 0,
          backorderable: existing?.backorderable ?? false,
        })
      })
    })
    return out
  }, [variants, stockLocations, hasMultipleVariants, t])

  // Find-or-create the stock_item entry for (variantIndex, stockLocationId)
  // and patch the given field. Uses form.setValue with the full updated
  // stock_items array so RHF treats this as one atomic edit per cell.
  const patchStockItem = useCallback(
    (
      variantIndex: number,
      stockLocationId: string,
      stockLocationName: string,
      field: 'count_on_hand' | 'backorderable',
      next: number | boolean,
    ) => {
      const current = form.getValues(`variants.${variantIndex}.stock_items`) ?? []
      const existingIdx = current.findIndex((si) => si.stock_location_id === stockLocationId)
      const nextItems: StockItemFormValues[] = [...current]
      if (existingIdx === -1) {
        nextItems.push({
          stock_location_id: stockLocationId,
          stock_location_name: stockLocationName,
          count_on_hand: field === 'count_on_hand' ? (next as number) : 0,
          backorderable: field === 'backorderable' ? (next as boolean) : false,
        })
      } else {
        const existing = nextItems[existingIdx]
        nextItems[existingIdx] = {
          ...existing,
          ...(field === 'count_on_hand'
            ? { count_on_hand: next as number }
            : { backorderable: next as boolean }),
        }
      }
      form.setValue(`variants.${variantIndex}.stock_items`, nextItems, { shouldDirty: true })
    },
    [form],
  )

  const columns = useMemo<ColumnDef<InventoryRow>[]>(
    () => [
      {
        id: 'location',
        header: t('admin.products.inventory.columns.location'),
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
        header: () => (
          <span className="block text-right">{t('admin.products.inventory.columns.on_hand')}</span>
        ),
        cell: ({ row, table }) => {
          const r = row.original
          if (r.kind !== 'item' || !r.stockLocationId || !r.stockLocationName) return null
          const coords = { row: editableRowIndex(table.getRowModel().rows, row.id), col: 1 }
          const value = r.countOnHand ?? 0
          const intent = value < LOW_STOCK_THRESHOLD ? ('warning' as const) : ('default' as const)
          return (
            <NumberCell
              coords={coords}
              value={value}
              onChange={(next) =>
                patchStockItem(
                  r.variantIndex,
                  r.stockLocationId as string,
                  r.stockLocationName as string,
                  'count_on_hand',
                  next,
                )
              }
              ariaLabel={t('admin.products.inventory.on_hand_aria', {
                location: r.stockLocationName,
              })}
              intent={intent}
            />
          )
        },
      },
      {
        id: 'backorderable',
        header: t('admin.products.inventory.columns.backorder'),
        cell: ({ row, table }) => {
          const r = row.original
          if (r.kind !== 'item' || !r.stockLocationId || !r.stockLocationName) return null
          const coords = { row: editableRowIndex(table.getRowModel().rows, row.id), col: 2 }
          return (
            <SwitchCell
              coords={coords}
              value={r.backorderable ?? false}
              onChange={(next) =>
                patchStockItem(
                  r.variantIndex,
                  r.stockLocationId as string,
                  r.stockLocationName as string,
                  'backorderable',
                  next,
                )
              }
              ariaLabel={t('admin.products.inventory.backorder_aria', {
                location: r.stockLocationName,
              })}
            />
          )
        },
      },
    ],
    [patchStockItem, storeId, t],
  )

  if (rows.length === 0) {
    // Showing "no stock locations" while the query is still in flight is
    // misleading — the locations may exist but haven't loaded yet.
    if (stockLocationsLoading) {
      return (
        <p className="text-sm text-muted-foreground">{t('admin.common.loading') ?? 'Loading…'}</p>
      )
    }
    return (
      <p className="text-sm text-muted-foreground">
        {stockLocations.length === 0
          ? t('admin.products.inventory.empty_no_locations')
          : t('admin.products.inventory.empty_no_variants')}
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
      aria-label={t('admin.a11y.stock_at_locations')}
    />
  )
}
