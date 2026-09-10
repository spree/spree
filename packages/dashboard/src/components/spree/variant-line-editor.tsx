import type { Variant } from '@spree/admin-sdk'
import { adminClient, formatPrice, ResourcePickerSheet } from '@spree/dashboard-core'
import {
  Button,
  Empty,
  EmptyContent,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Input,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { PackageIcon, PlusIcon, TrashIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { VariantLink } from './variant-link'

/**
 * What a line needs to render: enough of a variant to name and picture it.
 *
 * Structural rather than the SDK's `Variant`, so a line can be seeded from a
 * saved document's items — those carry the same four facts under their own
 * names and are not variants. A search result satisfies it as it stands.
 */
export interface VariantLineVariant {
  id: string
  sku?: string | null
  product_name?: string | null
  thumbnail_url?: string | null
}

/** One SKU the merchant is putting on a transfer or a purchase order. */
export interface VariantLine {
  variant: VariantLineVariant
  quantity: number
  /** Only purchase orders have a cost; transfers move stock already owned. */
  unitCost?: string
}

/**
 * Picks SKUs and their quantities for a draft inventory document.
 *
 * Shared by the new-transfer and new-purchase-order screens: both pick a
 * variant, both count units, and only the purchase order asks what they cost.
 */
export function VariantLineEditor({
  lines,
  onChange,
  currency,
  quantityLabel,
  withCost = false,
  stockLocationId,
  requireStockLocation = false,
  pickerOpen,
  onPickerOpenChange,
}: {
  lines: VariantLine[]
  onChange: (lines: VariantLine[]) => void
  /** Currency symbol context for the cost column; purchase orders only. */
  currency?: string
  quantityLabel: string
  withCost?: boolean
  /**
   * Offer only SKUs this warehouse could actually send. Transfers pass their
   * source; a purchase order passes nothing, because buying stock in is how a
   * merchant gets what they do not have.
   */
  stockLocationId?: string | null
  /** Refuse to open the picker until a warehouse is chosen. */
  requireStockLocation?: boolean
  /**
   * The picker's open state, owned by the card so its header can carry the
   * "Add a product" button beside the title — where every other card on these
   * screens puts its actions.
   */
  pickerOpen: boolean
  onPickerOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  // Nothing sensible to search until the source is known, and offering the
  // whole catalogue invites a line the warehouse cannot send — which is only
  // refused later, per line, when the transfer is marked in transit.
  const locked = !!requireStockLocation && !stockLocationId

  function addVariant(variant: Variant) {
    const existing = lines.find((line) => line.variant.id === variant.id)
    if (existing) {
      onChange(
        lines.map((line) =>
          line.variant.id === variant.id ? { ...line, quantity: line.quantity + 1 } : line,
        ),
      )
      return
    }
    onChange([...lines, { variant, quantity: 1, unitCost: withCost ? '0.00' : undefined }])
  }

  function update(variantId: string, patch: Partial<VariantLine>) {
    onChange(lines.map((line) => (line.variant.id === variantId ? { ...line, ...patch } : line)))
  }

  function remove(variantId: string) {
    onChange(lines.filter((line) => line.variant.id !== variantId))
  }

  return (
    <div className="flex flex-col gap-4">
      {/* A sheet rather than a one-at-a-time combobox: a delivery is picked in
          one pass, and the same picker the catalogue screens use already does
          searching, paging and select-all. */}
      <ResourcePickerSheet<Variant>
        open={pickerOpen}
        onOpenChange={onPickerOpenChange}
        // Keyed by warehouse: the same query means different things at two
        // sources, and a cached result would offer the wrong shelf's SKUs.
        queryKey={`inventory-line-variant-picker:${stockLocationId ?? 'any'}`}
        selectedIds={lines.map((line) => line.variant.id)}
        onConfirm={(_ids, variants) => {
          for (const variant of variants) addVariant(variant)
        }}
        search={async (query, page) =>
          adminClient.variants.list({
            ...(query ? { search: query } : {}),
            limit: 25,
            page,
            ...(stockLocationId ? { available_at_stock_location: stockLocationId } : {}),
          })
        }
        getOptionLabel={(variant) => variant.product_name ?? variant.sku ?? variant.id}
        getOptionImageUrl={(variant) => variant.thumbnail_url}
        getOptionSubtitle={(variant) =>
          `${t('admin.inventory_lines.columns.sku')} ${variant.sku ?? '—'} · ${formatPrice(variant.price)}`
        }
        title={t('admin.inventory_lines.picker_title')}
        searchPlaceholder={t('admin.inventory_lines.search_placeholder')}
      />

      {lines.length === 0 ? (
        <Empty className="border-0">
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <PackageIcon />
            </EmptyMedia>
            <EmptyTitle>{t('admin.inventory_lines.empty_title')}</EmptyTitle>
            <EmptyDescription>
              {locked
                ? t('admin.inventory_lines.pick_source_first')
                : t('admin.inventory_lines.empty_description')}
            </EmptyDescription>
          </EmptyHeader>
          <EmptyContent>
            <Button
              type="button"
              variant="outline"
              size="sm"
              disabled={locked}
              onClick={() => onPickerOpenChange(true)}
            >
              <PlusIcon className="size-4" />
              {t('admin.inventory_lines.add_label')}
            </Button>
          </EmptyContent>
        </Empty>
      ) : (
        <div className="overflow-x-auto rounded-md border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.inventory_lines.columns.variant')}</TableHead>
                <TableHead className="text-right">{quantityLabel}</TableHead>
                {withCost && (
                  <TableHead className="text-right">
                    {t('admin.inventory_lines.columns.unit_cost')}
                  </TableHead>
                )}
                <TableHead className="w-10" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {lines.map(({ variant, quantity, unitCost }) => (
                <TableRow key={variant.id}>
                  <TableCell>
                    {/* No product link: this form has unsaved work in it, and
                        the row reads the same as the ones on the saved
                        document. */}
                    <VariantLink
                      name={variant.product_name ?? variant.sku ?? variant.id}
                      sku={variant.sku}
                      thumbnailUrl={variant.thumbnail_url}
                    />
                  </TableCell>
                  <TableCell className="text-right">
                    <Input
                      type="number"
                      min={1}
                      value={quantity}
                      onChange={(event) =>
                        update(variant.id, { quantity: Number(event.target.value) })
                      }
                      className="ml-auto w-20 text-right tabular-nums"
                      aria-label={quantityLabel}
                    />
                  </TableCell>
                  {withCost && (
                    <TableCell className="text-right">
                      <InputGroup className="ml-auto w-36">
                        <InputGroupAddon>
                          <InputGroupText>{currency ?? ''}</InputGroupText>
                        </InputGroupAddon>
                        <InputGroupInput
                          type="number"
                          min={0}
                          step="0.01"
                          value={unitCost ?? ''}
                          onChange={(event) => update(variant.id, { unitCost: event.target.value })}
                          className="text-right tabular-nums"
                          aria-label={t('admin.inventory_lines.columns.unit_cost')}
                        />
                      </InputGroup>
                    </TableCell>
                  )}
                  <TableCell className="text-right">
                    <Button
                      type="button"
                      size="icon-xs"
                      variant="ghost"
                      onClick={() => remove(variant.id)}
                    >
                      <TrashIcon className="size-4" />
                      <span className="sr-only">{t('admin.actions.remove')}</span>
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  )
}
