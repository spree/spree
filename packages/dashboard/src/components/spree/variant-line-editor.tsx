import type { Variant } from '@spree/admin-sdk'
import { adminClient, formatPrice, ResourceCombobox } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldDescription,
  FieldLabel,
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
import { TrashIcon } from '@spree/dashboard-ui/icons'
import { useRef } from 'react'
import { useTranslation } from 'react-i18next'
import { VariantLink } from './variant-link'

/** One SKU the merchant is putting on a transfer or a purchase order. */
export interface VariantLine {
  variant: Variant
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
}) {
  const { t } = useTranslation()
  // Nothing sensible to search until the source is known, and offering the
  // whole catalogue invites a line the warehouse cannot send — which is only
  // refused later, per line, when the transfer is marked in transit.
  const locked = !!requireStockLocation && !stockLocationId
  // `onChange` hands back only the option id, so keep the records the search
  // returned to resolve it. A ref, not state: it is a lookup table.
  const variantById = useRef(new Map<string, Variant>())

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
      <Field>
        <FieldLabel>{t('admin.inventory_lines.add_label')}</FieldLabel>
        {/* Combobox rather than a bare input over a list of buttons:
            arrow-key navigation, `aria-activedescendant` and Enter-to-pick
            come from the primitive. Selecting adds the row and clears the
            field, so no value is held. */}
        <ResourceCombobox<Variant>
          // Keyed by warehouse: the same query means different things at two
          // sources, and a cached result would offer the wrong shelf's SKUs.
          queryKey={`inventory-line-variant-picker:${stockLocationId ?? 'any'}`}
          value=""
          disabled={locked}
          onChange={(id) => {
            const variant = id ? variantById.current.get(id) : undefined
            if (variant) addVariant(variant)
          }}
          search={async (query) => {
            const res = await adminClient.variants.list({
              search: query,
              limit: 8,
              ...(stockLocationId ? { available_at_stock_location: stockLocationId } : {}),
            })
            for (const variant of res.data) variantById.current.set(variant.id, variant)
            return res
          }}
          hydrate={async () => ({ data: [] })}
          getOptionLabel={(variant) => variant.product_name ?? variant.sku ?? variant.id}
          renderOption={(variant) => (
            <div className="flex flex-col">
              <span className="font-medium">
                {variant.product_name ?? variant.sku ?? variant.id}
              </span>
              <span className="text-xs text-muted-foreground">
                {t('admin.inventory_lines.columns.sku')} {variant.sku} ·{' '}
                {formatPrice(variant.price)}
              </span>
            </div>
          )}
          placeholder={t('admin.inventory_lines.search_placeholder')}
        />
        {locked && (
          <FieldDescription>{t('admin.inventory_lines.pick_source_first')}</FieldDescription>
        )}
      </Field>

      {lines.length > 0 && (
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
