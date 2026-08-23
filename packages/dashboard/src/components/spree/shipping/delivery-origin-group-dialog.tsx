import { zodResolver } from '@hookform/resolvers/zod'
import type { DeliveryOriginGroup } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
} from '@spree/dashboard-ui'
import { useEffect, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  useCreateDeliveryOriginGroup,
  useUpdateDeliveryOriginGroup,
} from '../../../hooks/use-delivery-origin-groups'
import { useStockLocations } from '../../../hooks/use-stock-locations'
import {
  DELIVERY_ORIGIN_GROUP_DEFAULTS,
  type DeliveryOriginGroupFormValues,
  deliveryOriginGroupFormSchema,
  deliveryOriginGroupValuesToParams,
} from '../../../schemas/delivery-origin-group'
import { StockLocationScopeField } from './stock-location-scope-field'

/**
 * Creates or renames one origin group. Splitting origins is what creating a
 * second group means, so the create copy talks about the split rather than
 * about the record.
 */
export function DeliveryOriginGroupDialog({
  deliveryProfileId,
  group,
  open,
  onOpenChange,
}: {
  deliveryProfileId: string
  /** Absent when splitting off a new group. */
  group?: DeliveryOriginGroup
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: stockLocations } = useStockLocations()
  const createMutation = useCreateDeliveryOriginGroup(deliveryProfileId)
  const updateMutation = useUpdateDeliveryOriginGroup(deliveryProfileId, group?.id ?? '')

  const editing = !!group

  const form = useForm<DeliveryOriginGroupFormValues>({
    resolver: zodResolver(deliveryOriginGroupFormSchema),
    defaultValues: DELIVERY_ORIGIN_GROUP_DEFAULTS,
  })

  useEffect(() => {
    form.reset(
      group
        ? { name: group.name ?? '', stock_location_ids: group.stock_location_ids }
        : DELIVERY_ORIGIN_GROUP_DEFAULTS,
    )
  }, [group, form])

  // "Every location" is the absence of a narrowing, exactly as the API reads
  // an empty array — so the radio reads the field rather than holding a second
  // source of truth.
  const selectedIds = form.watch('stock_location_ids')
  const [scope, setScope] = useState<'all' | 'selected'>('all')
  useEffect(() => {
    setScope((group?.stock_location_ids.length ?? 0) > 0 ? 'selected' : 'all')
  }, [group])

  async function onSubmit(values: DeliveryOriginGroupFormValues) {
    try {
      const params = deliveryOriginGroupValuesToParams(values)
      if (group) {
        await updateMutation.mutateAsync(params)
      } else {
        await createMutation.mutateAsync(params)
      }
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState
  const locations = stockLocations?.data ?? []

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <form
          onSubmit={(event) => {
            // The profile page renders its cards inside their own forms —
            // without stopping the bubble the browser submits the outer one.
            form.handleSubmit(onSubmit)(event)
            event.stopPropagation()
          }}
        >
          <DialogHeader>
            <DialogTitle>
              {editing
                ? t('admin.delivery_origin_groups.edit_title')
                : t('admin.delivery_origin_groups.split_title')}
            </DialogTitle>
            <DialogDescription>
              {editing
                ? t('admin.delivery_origin_groups.edit_description')
                : t('admin.delivery_origin_groups.split_description')}
            </DialogDescription>
          </DialogHeader>

          <DialogBody className="flex flex-col gap-4">
            {errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {errors.root.message}
              </p>
            )}

            <Field>
              <FieldLabel htmlFor="origin-group-name">
                {t('admin.fields.delivery_origin_group.name.label')}
              </FieldLabel>
              <Input
                id="origin-group-name"
                autoFocus
                placeholder={t('admin.delivery_profiles.all_locations')}
                aria-invalid={!!errors.name || undefined}
                {...form.register('name')}
              />
              <FieldError errors={[errors.name]} />
              <span className="text-muted-foreground text-xs">
                {t('admin.fields.delivery_origin_group.name.help')}
              </span>
            </Field>

            <Field>
              <FieldLabel>{t('admin.delivery_origin_groups.ships_from_label')}</FieldLabel>
              <Controller
                name="stock_location_ids"
                control={form.control}
                render={({ field }) => (
                  <StockLocationScopeField
                    idPrefix="origin-group"
                    scope={scope}
                    onScopeChange={(next) => {
                      setScope(next)
                      if (next === 'all') field.onChange([])
                    }}
                    locations={locations}
                    selectedIds={field.value}
                    onSelectedIdsChange={field.onChange}
                    allLabel={t('admin.delivery_profiles.all_locations')}
                    selectedLabel={t('admin.delivery_profiles.selected_locations')}
                    emptyLabel={t('admin.delivery_profiles.detail.no_stock_locations')}
                  />
                )}
              />
            </Field>

            {scope === 'selected' && selectedIds.length === 0 && (
              <p className="text-muted-foreground text-xs">
                {t('admin.delivery_origin_groups.no_locations_hint')}
              </p>
            )}
          </DialogBody>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? editing
                  ? t('admin.actions.saving')
                  : t('admin.actions.creating')
                : editing
                  ? t('admin.actions.save')
                  : t('admin.delivery_origin_groups.split_cta')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
