import type { ColumnDef } from '@tanstack/react-table'
import { useMemo } from 'react'
import { DataGrid, DecimalCell, ReadOnlyCell, SelectCell, SwitchCell, TextCell } from './data-grid'

export interface BulkVariantsRow {
  id: string
  variantLabel?: string | null
  sku?: string | null
  barcode?: string | null
  // Display strings — decimal weight/dimension values, or null for unset.
  weight?: string | null
  weightUnit?: string | null
  height?: string | null
  width?: string | null
  depth?: string | null
  dimensionsUnit?: string | null
  preorderable?: boolean
  backorderLimit?: string | null
  taxCategoryId?: string | null
  hsCode?: string | null
  /** ISO 3166-1 alpha-2 code, never a country record id. */
  countryOfOrigin?: string | null
  customsDescription?: string | null
  unitsPerCarton?: string | null
  cartonPackageTypeId?: string | null
  cartonWeight?: string | null
  cartonsPerPallet?: string | null
}

export type BulkVariantsField =
  | 'sku'
  | 'barcode'
  | 'weight'
  | 'weightUnit'
  | 'height'
  | 'width'
  | 'depth'
  | 'dimensionsUnit'
  | 'preorderable'
  | 'backorderLimit'
  | 'taxCategoryId'
  | 'hsCode'
  | 'countryOfOrigin'
  | 'customsDescription'
  | 'unitsPerCarton'
  | 'cartonPackageTypeId'
  | 'cartonWeight'
  | 'cartonsPerPallet'

export type BulkVariantsChange =
  | { field: Exclude<BulkVariantsField, 'preorderable'>; value: string | null }
  | { field: 'preorderable'; value: boolean }

export interface BulkVariantsTableLabels {
  /** Column headers. */
  variant: string
  sku: string
  barcode: string
  weight: string
  weightUnit: string
  height: string
  width: string
  depth: string
  dimensionsUnit: string
  preorderable: string
  backorderLimit: string
  taxCategory: string
  hsCode: string
  countryOfOrigin: string
  customsDescription: string
  unitsPerCarton: string
  cartonPackageType: string
  cartonWeight: string
  cartonsPerPallet: string
  /** Placeholder for a variant row with no options text (e.g. "Default"). */
  variantDefault: string
  /** Shown in unit cells with no explicit value ("inherit the default"). */
  unitDefault: string
  /** Shown in the tax-category cell when none is set. */
  taxCategoryNone: string
  /** Shown in the country-of-origin cell when none is set. */
  countryOfOriginNone: string
  /** Shown in the carton cell when the variant is packed into none. */
  cartonPackageTypeNone: string
  /** Aria label on the DataGrid for screen readers. */
  gridAriaLabel?: string
}

export interface BulkVariantsTableProps {
  rows: BulkVariantsRow[]
  /** Localized strings — the caller owns translations. */
  labels: BulkVariantsTableLabels
  weightUnitOptions: ReadonlyArray<{ value: string; label: string }>
  dimensionUnitOptions: ReadonlyArray<{ value: string; label: string }>
  /** Omit to hide the tax-category column (no tax categories configured). */
  taxCategoryOptions?: ReadonlyArray<{ value: string; label: string }>
  /** The store's cartons. Omit to hide the packing columns entirely. */
  cartonOptions?: ReadonlyArray<{ value: string; label: string }>
  /**
   * Countries as `{ value: ISO, label: name }`. Omit to hide the customs
   * columns entirely (e.g. the country list has not loaded yet). Values are
   * ISO codes so the stored data survives the countries table going away.
   */
  countryOptions?: ReadonlyArray<{ value: string; label: string }>
  /** Called when the user commits a value to a cell. The id is the row id. */
  onChange: (rowId: string, change: BulkVariantsChange) => void
}

// Decimal columns in grid order, paired with their fixed keyboard column
// coordinate (see the coordinate map in the component body).
const DECIMAL_COLUMNS: ReadonlyArray<{
  field: 'weight' | 'height' | 'width' | 'depth'
  col: number
}> = [
  { field: 'weight', col: 3 },
  { field: 'height', col: 5 },
  { field: 'width', col: 6 },
  { field: 'depth', col: 7 },
]

/**
 * Presentational primitive for a "spreadsheet of variant fields" UI: SKU,
 * barcode, shipping measurements + units, availability, tax category.
 * Selection, copy/paste, and drag-fill come from the DataGrid. Owns NO data
 * fetching, edit tracking, or save logic — the caller projects its rows into
 * BulkVariantsRow shape and writes edits back through `onChange`.
 */
export function BulkVariantsTable({
  rows,
  labels,
  weightUnitOptions,
  dimensionUnitOptions,
  taxCategoryOptions,
  countryOptions,
  cartonOptions,
  onChange,
}: BulkVariantsTableProps) {
  const columns = useMemo<ColumnDef<BulkVariantsRow>[]>(() => {
    // Keyboard column coordinates, fixed per column: variant label is
    // read-only (unregistered), then sku=1, barcode=2, weight=3, unit=4,
    // height=5, width=6, depth=7, unit=8, preorderable=9, backorder=10,
    // tax=11, hs code=12, origin=13, customs description=14, carton=15,
    // carton weight=16, cartons per pallet=17, units per carton=18.
    const numericHeader = (label: string) => () => <span className="block text-right">{label}</span>
    const rowLabel = (r: BulkVariantsRow) => r.variantLabel ?? labels.variantDefault

    const defs: ColumnDef<BulkVariantsRow>[] = [
      {
        id: 'variant',
        header: labels.variant,
        cell: ({ row }) => (
          <ReadOnlyCell className="whitespace-nowrap text-muted-foreground">
            {rowLabel(row.original)}
          </ReadOnlyCell>
        ),
      },
      {
        id: 'sku',
        header: labels.sku,
        cell: ({ row }) => (
          <TextCell
            coords={{ row: row.index, col: 1 }}
            value={row.original.sku ?? null}
            onChange={(next) => onChange(row.original.id, { field: 'sku', value: next })}
            ariaLabel={`${labels.sku} — ${rowLabel(row.original)}`}
          />
        ),
      },
      {
        id: 'barcode',
        header: labels.barcode,
        cell: ({ row }) => (
          <TextCell
            coords={{ row: row.index, col: 2 }}
            value={row.original.barcode ?? null}
            onChange={(next) => onChange(row.original.id, { field: 'barcode', value: next })}
            ariaLabel={`${labels.barcode} — ${rowLabel(row.original)}`}
          />
        ),
      },
      ...DECIMAL_COLUMNS.map<ColumnDef<BulkVariantsRow>>(({ field, col }) => ({
        id: field,
        header: numericHeader(labels[field]),
        cell: ({ row }) => (
          <DecimalCell
            coords={{ row: row.index, col }}
            value={row.original[field] ?? null}
            onChange={(next) => onChange(row.original.id, { field, value: next })}
            ariaLabel={`${labels[field]} — ${rowLabel(row.original)}`}
          />
        ),
      })),
      {
        id: 'weight_unit',
        header: labels.weightUnit,
        cell: ({ row }) => (
          <SelectCell
            coords={{ row: row.index, col: 4 }}
            value={row.original.weightUnit ?? null}
            options={weightUnitOptions}
            nullLabel={labels.unitDefault}
            onChange={(next) => onChange(row.original.id, { field: 'weightUnit', value: next })}
            ariaLabel={`${labels.weightUnit} — ${rowLabel(row.original)}`}
          />
        ),
      },
      {
        id: 'dimensions_unit',
        header: labels.dimensionsUnit,
        cell: ({ row }) => (
          <SelectCell
            coords={{ row: row.index, col: 8 }}
            value={row.original.dimensionsUnit ?? null}
            options={dimensionUnitOptions}
            nullLabel={labels.unitDefault}
            onChange={(next) => onChange(row.original.id, { field: 'dimensionsUnit', value: next })}
            ariaLabel={`${labels.dimensionsUnit} — ${rowLabel(row.original)}`}
          />
        ),
      },
      {
        id: 'preorderable',
        header: labels.preorderable,
        cell: ({ row }) => (
          <SwitchCell
            coords={{ row: row.index, col: 9 }}
            value={row.original.preorderable ?? false}
            onChange={(next) => onChange(row.original.id, { field: 'preorderable', value: next })}
            ariaLabel={`${labels.preorderable} — ${rowLabel(row.original)}`}
          />
        ),
      },
      {
        id: 'backorder_limit',
        header: numericHeader(labels.backorderLimit),
        cell: ({ row }) => (
          <DecimalCell
            coords={{ row: row.index, col: 10 }}
            value={row.original.backorderLimit ?? null}
            onChange={(next) => onChange(row.original.id, { field: 'backorderLimit', value: next })}
            ariaLabel={`${labels.backorderLimit} — ${rowLabel(row.original)}`}
          />
        ),
      },
    ]

    if (taxCategoryOptions) {
      defs.push({
        id: 'tax_category',
        header: labels.taxCategory,
        cell: ({ row }) => (
          <SelectCell
            coords={{ row: row.index, col: 11 }}
            value={row.original.taxCategoryId ?? null}
            options={taxCategoryOptions}
            nullLabel={labels.taxCategoryNone}
            onChange={(next) => onChange(row.original.id, { field: 'taxCategoryId', value: next })}
            ariaLabel={`${labels.taxCategory} — ${rowLabel(row.original)}`}
          />
        ),
      })
    }

    // Customs columns travel together — classification is only meaningful
    // alongside the origin it is declared with.
    if (countryOptions) {
      defs.push(
        {
          id: 'hs_code',
          header: labels.hsCode,
          cell: ({ row }) => (
            <TextCell
              coords={{ row: row.index, col: 12 }}
              value={row.original.hsCode ?? null}
              onChange={(next) => onChange(row.original.id, { field: 'hsCode', value: next })}
              ariaLabel={`${labels.hsCode} — ${rowLabel(row.original)}`}
            />
          ),
        },
        {
          id: 'country_of_origin',
          header: labels.countryOfOrigin,
          cell: ({ row }) => (
            <SelectCell
              coords={{ row: row.index, col: 13 }}
              value={row.original.countryOfOrigin ?? null}
              options={countryOptions}
              nullLabel={labels.countryOfOriginNone}
              onChange={(next) =>
                onChange(row.original.id, { field: 'countryOfOrigin', value: next })
              }
              ariaLabel={`${labels.countryOfOrigin} — ${rowLabel(row.original)}`}
            />
          ),
        },
        {
          id: 'customs_description',
          header: labels.customsDescription,
          cell: ({ row }) => (
            <TextCell
              coords={{ row: row.index, col: 14 }}
              value={row.original.customsDescription ?? null}
              onChange={(next) =>
                onChange(row.original.id, { field: 'customsDescription', value: next })
              }
              ariaLabel={`${labels.customsDescription} — ${rowLabel(row.original)}`}
            />
          ),
        },
      )
    }

    // The packing chain travels together: a carton weight or a pallet count
    // means nothing without the carton they describe.
    if (cartonOptions) {
      defs.push(
        {
          id: 'units_per_carton',
          header: numericHeader(labels.unitsPerCarton),
          cell: ({ row }) => (
            <DecimalCell
              coords={{ row: row.index, col: 18 }}
              value={row.original.unitsPerCarton ?? null}
              onChange={(next) =>
                onChange(row.original.id, { field: 'unitsPerCarton', value: next })
              }
              ariaLabel={`${labels.unitsPerCarton} — ${rowLabel(row.original)}`}
            />
          ),
        },
        {
          id: 'carton_package_type',
          header: labels.cartonPackageType,
          cell: ({ row }) => (
            <SelectCell
              coords={{ row: row.index, col: 15 }}
              value={row.original.cartonPackageTypeId ?? null}
              options={cartonOptions}
              nullLabel={labels.cartonPackageTypeNone}
              onChange={(next) =>
                onChange(row.original.id, { field: 'cartonPackageTypeId', value: next })
              }
              ariaLabel={`${labels.cartonPackageType} — ${rowLabel(row.original)}`}
            />
          ),
        },
        {
          id: 'carton_weight',
          header: numericHeader(labels.cartonWeight),
          cell: ({ row }) => (
            <DecimalCell
              coords={{ row: row.index, col: 16 }}
              value={row.original.cartonWeight ?? null}
              onChange={(next) => onChange(row.original.id, { field: 'cartonWeight', value: next })}
              ariaLabel={`${labels.cartonWeight} — ${rowLabel(row.original)}`}
            />
          ),
        },
        {
          id: 'cartons_per_pallet',
          header: numericHeader(labels.cartonsPerPallet),
          cell: ({ row }) => (
            <DecimalCell
              coords={{ row: row.index, col: 17 }}
              value={row.original.cartonsPerPallet ?? null}
              onChange={(next) =>
                onChange(row.original.id, { field: 'cartonsPerPallet', value: next })
              }
              ariaLabel={`${labels.cartonsPerPallet} — ${rowLabel(row.original)}`}
            />
          ),
        },
      )
    }

    // Reorder to visual sequence: the coordinate map above is stable, but
    // the defs array built column groups out of order for concision.
    const order = [
      'variant',
      'sku',
      'barcode',
      'weight',
      'weight_unit',
      'height',
      'width',
      'depth',
      'dimensions_unit',
      'preorderable',
      'backorder_limit',
      'tax_category',
      'hs_code',
      'country_of_origin',
      'customs_description',
      'units_per_carton',
      'carton_package_type',
      'carton_weight',
      'cartons_per_pallet',
    ]
    return defs.sort((a, b) => order.indexOf(a.id as string) - order.indexOf(b.id as string))
  }, [
    onChange,
    labels,
    weightUnitOptions,
    dimensionUnitOptions,
    taxCategoryOptions,
    countryOptions,
    cartonOptions,
  ])

  return (
    <div className="overflow-x-auto">
      <DataGrid<BulkVariantsRow>
        rows={rows}
        columns={columns}
        getRowId={(row) => row.id}
        className={
          cartonOptions ? 'min-w-[1900px]' : countryOptions ? 'min-w-[1500px]' : 'min-w-[1100px]'
        }
        aria-label={labels.gridAriaLabel}
      />
    </div>
  )
}
