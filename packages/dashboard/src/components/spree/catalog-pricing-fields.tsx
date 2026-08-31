import type { PriceList } from '@spree/admin-sdk'
import {
  Button,
  Field,
  FieldDescription,
  FieldError,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
} from '@spree/dashboard-ui'
import { TableIcon } from 'lucide-react'
import { useState } from 'react'
import { Controller, type UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  CATALOG_PRICING_MODES,
  type CatalogFormValues,
  type CatalogPricingMode,
} from '../../schemas/catalog'
import { ADJUSTMENT_DIRECTIONS } from '../../schemas/price-list'
import { BulkPriceEditorDialog } from './bulk-price-editor/bulk-price-editor-dialog'

/**
 * How the agreement prices, edited on the catalog itself: the catalog and the
 * list it prices through are saved in one request, so standing up "wholesale
 * at −15%" never means visiting the price-lists page
 * (docs/plans/6.0-catalog-agreement-rework.md).
 *
 * Shared by the create sheet and the agreement editor so both offer the same
 * choice; the detach warning only appears where a list already exists.
 */
export function CatalogPricingFields({
  form,
  canEdit,
  priceList,
  savedMode,
  excludeProductIds,
  hasStagedProducts,
}: {
  form: UseFormReturn<CatalogFormValues>
  canEdit: boolean
  /**
   * The list this catalog owns, when it has one. Drives the detach warning
   * and the price spreadsheet; absent on the create sheet, where the list
   * does not exist until Save.
   */
  priceList?: PriceList | null
  /** The mode as last saved, so a switch can be warned about before Save. */
  savedMode?: CatalogPricingMode
  /**
   * Products staged for removal from the assortment. Their prices survive
   * until Save, but they are on their way out, so the spreadsheet leaves
   * them out rather than inviting work that Save discards.
   */
  excludeProductIds?: string[]
  /**
   * True while any membership edit is staged. A staged addition has no
   * price rows until Save, so the grid cannot show it yet — the help text
   * says so rather than leaving the merchant hunting for it.
   */
  hasStagedProducts?: boolean
}) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const mode = form.watch('pricing_mode')
  const [priceEditorOpen, setPriceEditorOpen] = useState(false)
  const hasOwnedList = !!priceList
  // Hand-entered amounts beat the adjustment, so switching to a percentage
  // clears them — said before Save, since the rows are not recoverable.
  const willDiscardPrices = savedMode === 'fixed' && mode === 'automatic'

  const modeItems = CATALOG_PRICING_MODES.map((value) => ({
    value,
    label: t(`admin.fields.catalog.pricing_mode.${value}`),
  }))
  const directionItems = ADJUSTMENT_DIRECTIONS.map((value) => ({
    value,
    label: t(`admin.fields.price_list.adjustment_direction.${value}`),
  }))

  return (
    <>
      <Field>
        <FieldLabel htmlFor="catalog-pricing-mode">
          {t('admin.fields.catalog.pricing_mode.label')}
        </FieldLabel>
        <Controller
          control={form.control}
          name="pricing_mode"
          render={({ field }) => (
            <Select
              items={modeItems as never}
              value={field.value}
              onValueChange={field.onChange}
              disabled={!canEdit}
            >
              <SelectTrigger id="catalog-pricing-mode">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {modeItems.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
        <FieldDescription>{t('admin.fields.catalog.pricing_mode.help')}</FieldDescription>
      </Field>

      {mode === 'automatic' && (
        <>
          <div className="flex items-end gap-2">
            <Field className="w-32">
              <FieldLabel htmlFor="catalog-adjustment-magnitude">
                {t('admin.fields.price_list.adjustment_magnitude.label')}
              </FieldLabel>
              <Input
                id="catalog-adjustment-magnitude"
                inputMode="decimal"
                placeholder="15"
                disabled={!canEdit}
                aria-invalid={!!errors.adjustment_magnitude || undefined}
                {...form.register('adjustment_magnitude')}
              />
            </Field>
            <Field className="flex-1">
              <FieldLabel htmlFor="catalog-adjustment-direction" className="sr-only">
                {t('admin.fields.price_list.adjustment_direction.label')}
              </FieldLabel>
              <Controller
                control={form.control}
                name="adjustment_direction"
                render={({ field }) => (
                  <Select
                    items={directionItems as never}
                    value={field.value}
                    onValueChange={field.onChange}
                    disabled={!canEdit}
                  >
                    <SelectTrigger id="catalog-adjustment-direction">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {directionItems.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
            </Field>
          </div>
          <FieldError errors={[errors.adjustment_magnitude]} />

          <Field orientation="horizontal">
            <Controller
              control={form.control}
              name="adjust_compare_at"
              render={({ field }) => (
                <Switch
                  id="catalog-adjust-compare-at"
                  checked={field.value}
                  onCheckedChange={field.onChange}
                  disabled={!canEdit}
                />
              )}
            />
            <div>
              <FieldLabel htmlFor="catalog-adjust-compare-at">
                {t('admin.fields.price_list.adjust_compare_at.label')}
              </FieldLabel>
              <p className="text-xs text-muted-foreground">
                {t('admin.fields.price_list.adjust_compare_at.help')}
              </p>
            </div>
          </Field>
        </>
      )}

      {/* Detaching releases the list back to matching by its own rules, and a
          rule-less one matches every shopper — so the consequence is stated
          before Save, not after. */}
      {hasOwnedList && mode === 'base' && (
        <p className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive" role="alert">
          {t('admin.catalogs.detach_warning')}
        </p>
      )}

      {willDiscardPrices && (
        <p className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive" role="alert">
          {t('admin.catalogs.discard_prices_warning')}
        </p>
      )}

      {/* Fixed pricing is only half-configured until amounts exist, so the
          spreadsheet is offered right here rather than on a page the
          merchant has no reason to know about. Unsaved first: the list is
          created by Save, and there is nothing to price until it is. */}
      {mode === 'fixed' &&
        (priceList ? (
          <div>
            <Button
              type="button"
              size="sm"
              variant="outline"
              disabled={!canEdit}
              onClick={() => setPriceEditorOpen(true)}
            >
              <TableIcon className="size-4" />
              {t('admin.catalogs.edit_prices_cta')}
            </Button>
            <FieldDescription>
              {t(
                hasStagedProducts
                  ? 'admin.catalogs.edit_prices_pending_save'
                  : 'admin.catalogs.edit_prices_help',
              )}
            </FieldDescription>
            <BulkPriceEditorDialog
              open={priceEditorOpen}
              onOpenChange={setPriceEditorOpen}
              priceList={priceList}
              excludeProductIds={excludeProductIds}
            />
          </div>
        ) : (
          <FieldDescription>{t('admin.catalogs.edit_prices_after_save')}</FieldDescription>
        ))}
    </>
  )
}
