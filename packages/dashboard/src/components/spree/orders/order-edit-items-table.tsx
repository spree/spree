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
import { PackageIcon, RotateCcwIcon, XIcon } from 'lucide-react'
import { Controller, type FieldArrayWithId, type UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import type { OrderEditFormValues } from '../../../schemas/order'

/**
 * The staged items table. Every control writes to form state only — quantities,
 * removals and picker additions all wait for the page's Save. A removed row
 * stays on screen struck through so the merchant can put it back before saving.
 *
 * The field array lives on the page rather than here because the catalog picker
 * appends to it too, and two `useFieldArray` calls on one name keep separate
 * row lists.
 */
export function OrderEditItemsTable({
  form,
  fields,
}: {
  form: UseFormReturn<OrderEditFormValues>
  fields: FieldArrayWithId<OrderEditFormValues, 'items', 'id'>[]
}) {
  const { t } = useTranslation()

  if (fields.length === 0) {
    return <p className="py-8 text-center text-muted-foreground">{t('admin.orders.edit.empty')}</p>
  }

  return (
    <Table>
      <TableHeader className="border-b">
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
          <OrderEditItemRow key={field.id} form={form} index={index} />
        ))}
      </TableBody>
    </Table>
  )
}

function OrderEditItemRow({
  form,
  index,
}: {
  form: UseFormReturn<OrderEditFormValues>
  index: number
}) {
  const { t } = useTranslation()
  const row = form.watch(`items.${index}`)
  const quantityError = form.formState.errors.items?.[index]?.quantity?.message

  function toggleRemoved() {
    form.setValue(`items.${index}.removed`, !row.removed, {
      shouldDirty: true,
      shouldValidate: true,
    })
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

      <TableCell className="text-right whitespace-nowrap">{row.display_price}</TableCell>

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
        {row.added ? '—' : row.display_total}
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
