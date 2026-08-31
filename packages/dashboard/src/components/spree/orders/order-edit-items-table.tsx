import {
  Badge,
  Button,
  cn,
  Input,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  Thumbnail,
} from '@spree/dashboard-ui'
import { PackageIcon, RotateCcwIcon, Undo2Icon, XIcon } from 'lucide-react'
import { Controller, type FieldArrayWithId, type UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  formatAmount,
  type OrderEditFormValues,
  projectedLineTotal,
  projectedPrice,
} from '../../../schemas/order'

/**
 * The staged items table. Every control writes to form state only; nothing is
 * sent until the page's Save. `pricesEditable` is on for drafts only — a
 * negotiated price is a pre-placement gesture.
 *
 * The field array lives on the page because the catalog picker appends to it
 * too, and two `useFieldArray` calls on one name keep separate row lists.
 */
export function OrderEditItemsTable({
  form,
  fields,
  pricesEditable = false,
  currency,
}: {
  form: UseFormReturn<OrderEditFormValues>
  fields: FieldArrayWithId<OrderEditFormValues, 'items', 'id'>[]
  pricesEditable?: boolean
  /** Order currency, for formatting the projected line totals. */
  currency: string
}) {
  const { t } = useTranslation()

  if (fields.length === 0) {
    return <p className="py-8 text-center text-muted-foreground">{t('admin.orders.edit.empty')}</p>
  }

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{t('admin.orders.edit.columns.product')}</TableHead>
          <TableHead className="text-right">{t('admin.orders.edit.columns.unit_price')}</TableHead>
          <TableHead className="w-32 text-right">{t('admin.fields.quantity.label')}</TableHead>
          <TableHead className="text-right">{t('admin.orders.edit.columns.line_total')}</TableHead>
          <TableHead className="w-16" />
        </TableRow>
      </TableHeader>
      <TableBody>
        {fields.map((field, index) => (
          <OrderEditItemRow
            key={field.id}
            form={form}
            index={index}
            pricesEditable={pricesEditable}
            currency={currency}
          />
        ))}
      </TableBody>
    </Table>
  )
}

function OrderEditItemRow({
  form,
  index,
  pricesEditable,
  currency,
}: {
  form: UseFormReturn<OrderEditFormValues>
  index: number
  pricesEditable: boolean
  currency: string
}) {
  const { t } = useTranslation()
  const row = form.watch(`items.${index}`)
  const quantityError = form.formState.errors.items?.[index]?.quantity?.message
  const priceError = form.formState.errors.items?.[index]?.price?.message
  const negotiated = row.price_source === 'manual'

  const projectedTotal = projectedLineTotal(row)
  const savedTotal = Number(row.saved_price) * row.saved_quantity
  const totalChanged =
    !row.added && projectedTotal !== null && Math.abs(projectedTotal - savedTotal) > 0.004
  const revertPreview = row.revert_price ? projectedPrice(row) : null

  function toggleRemoved() {
    form.setValue(`items.${index}.removed`, !row.removed, {
      shouldDirty: true,
      shouldValidate: true,
    })
  }

  function toggleRevertPrice() {
    const reverting = !row.revert_price
    form.setValue(`items.${index}.revert_price`, reverting, {
      shouldDirty: true,
      shouldValidate: true,
    })
    // A staged revert drops any price typed in the same session — the two
    // gestures contradict each other.
    if (reverting) {
      form.setValue(`items.${index}.price`, row.saved_price, { shouldValidate: true })
    }
  }

  return (
    <TableRow className={cn(row.removed && 'opacity-50')}>
      <TableCell>
        <div className="flex items-center gap-3">
          <Thumbnail src={row.thumbnail_url} size="lg" fallback={<PackageIcon />} />
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <span className={cn('truncate text-sm font-medium', row.removed && 'line-through')}>
                {row.name}
              </span>
              {row.added && !row.removed && (
                <Badge variant="secondary">{t('admin.orders.edit.badges.pending')}</Badge>
              )}
              {row.removed && (
                <Badge variant="outline">{t('admin.orders.edit.badges.removed')}</Badge>
              )}
              {row.fulfilled_quantity > 0 && (
                <Badge variant="secondary">
                  {t('admin.orders.edit.badges.fulfilled_count', {
                    count: row.fulfilled_quantity,
                  })}
                </Badge>
              )}
            </div>
            {row.options_text && (
              <div className="truncate text-xs text-muted-foreground">{row.options_text}</div>
            )}
          </div>
        </div>
      </TableCell>

      <TableCell className="text-right">
        {pricesEditable ? (
          <div className="flex flex-col items-end gap-1">
            <div className="flex items-center justify-end gap-1.5">
              {negotiated && !row.revert_price && (
                <Badge variant="secondary">{t('admin.orders.edit.badges.negotiated')}</Badge>
              )}
              {row.revert_price && (
                <Badge variant="outline">{t('admin.orders.edit.badges.price_reverting')}</Badge>
              )}
              {negotiated && (
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  onClick={toggleRevertPrice}
                  aria-label={
                    row.revert_price
                      ? t('admin.orders.edit.actions.keep_negotiated_price', { name: row.name })
                      : t('admin.orders.edit.actions.reset_price', { name: row.name })
                  }
                >
                  {row.revert_price ? (
                    <Undo2Icon className="size-4" />
                  ) : (
                    <RotateCcwIcon className="size-4" />
                  )}
                </Button>
              )}
              {row.revert_price ? (
                <span className="flex items-center gap-2 text-sm whitespace-nowrap">
                  <span className="text-muted-foreground line-through">{row.saved_price}</span>
                  <span className="font-medium">
                    {revertPreview === null
                      ? t('admin.orders.edit.catalog_price_unknown')
                      : revertPreview}
                  </span>
                </span>
              ) : (
                <Controller
                  control={form.control}
                  name={`items.${index}.price`}
                  render={({ field }) => (
                    <Input
                      type="text"
                      inputMode="decimal"
                      className="w-24 text-right"
                      disabled={row.removed}
                      aria-invalid={!!priceError}
                      aria-label={t('admin.orders.edit.actions.price_for', { name: row.name })}
                      value={field.value}
                      onChange={field.onChange}
                      onBlur={field.onBlur}
                    />
                  )}
                />
              )}
            </div>
            {priceError && (
              <p className="text-xs text-destructive" role="alert">
                {priceError}
              </p>
            )}
          </div>
        ) : (
          <span className="whitespace-nowrap">{row.display_price}</span>
        )}
      </TableCell>

      <TableCell className="text-right">
        <Controller
          control={form.control}
          name={`items.${index}.quantity`}
          render={({ field }) => (
            <Input
              type="number"
              min={Math.max(1, row.fulfilled_quantity)}
              inputMode="numeric"
              className="ml-auto w-24 text-right"
              disabled={row.removed}
              aria-invalid={!!quantityError}
              aria-label={t('admin.orders.edit.actions.quantity_for', { name: row.name })}
              value={field.value}
              onChange={(event) => field.onChange(Number(event.target.value))}
              onBlur={field.onBlur}
            />
          )}
        />
        {quantityError && (
          <p className="mt-1 text-xs text-destructive" role="alert">
            {quantityError}
          </p>
        )}
      </TableCell>

      <TableCell className="text-right whitespace-nowrap">
        {row.added ? (
          projectedTotal === null ? (
            '—'
          ) : (
            formatAmount(projectedTotal, currency)
          )
        ) : totalChanged ? (
          <span className="flex items-center justify-end gap-2">
            <span className="text-muted-foreground line-through">{row.display_total}</span>
            <span className="font-medium">{formatAmount(projectedTotal as number, currency)}</span>
          </span>
        ) : (
          row.display_total
        )}
      </TableCell>

      <TableCell className="text-right">
        {/* A row with shipped units cannot be struck out — those units are
            physically gone, so the only edit left is raising the quantity. */}
        {row.fulfilled_quantity === 0 && (
          <Button
            type="button"
            variant="ghost"
            size="icon"
            onClick={toggleRemoved}
            aria-label={
              row.removed
                ? t('admin.orders.edit.actions.restore_item', { name: row.name })
                : t('admin.orders.edit.actions.remove_item', { name: row.name })
            }
          >
            {row.removed ? (
              <RotateCcwIcon className="size-4" />
            ) : (
              <XIcon className="size-4 text-destructive" />
            )}
          </Button>
        )}
      </TableCell>
    </TableRow>
  )
}
