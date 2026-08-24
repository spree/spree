import { zodResolver } from '@hookform/resolvers/zod'
import type { DeliveryProfile } from '@spree/admin-sdk'
import { Can, mapSpreeErrorsToForm, Subject } from '@spree/dashboard-core'
import { Button, Card, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useUpdateDeliveryProfile } from '../../../hooks/use-delivery-profiles'
import { useStockLocations } from '../../../hooks/use-stock-locations'
import {
  type DeliveryProfileLocationsValues,
  deliveryProfileLocationsSchema,
  deliveryProfileLocationsToParams,
} from '../../../schemas/delivery-profile'
import { StockLocationScopeField } from './stock-location-scope-field'

/** Which stock locations this profile ships from. */
export function DeliveryProfileOriginsCard({ profile }: { profile: DeliveryProfile }) {
  const { t } = useTranslation()
  const updateMutation = useUpdateDeliveryProfile(profile.id)
  const { data: stockLocations } = useStockLocations()

  const initial: DeliveryProfileLocationsValues = {
    scope: profile.stock_location_ids.length === 0 ? 'all' : 'selected',
    stock_location_ids: profile.stock_location_ids,
  }

  const form = useForm<DeliveryProfileLocationsValues>({
    resolver: zodResolver(deliveryProfileLocationsSchema),
    defaultValues: initial,
    values: initial,
    resetOptions: { keepDirtyValues: true },
  })

  const scope = form.watch('scope')

  async function onSubmit(values: DeliveryProfileLocationsValues) {
    try {
      await updateMutation.mutateAsync(deliveryProfileLocationsToParams(values))
      form.reset(values)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.delivery_profiles.detail.origins_title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <Controller
          name="stock_location_ids"
          control={form.control}
          render={({ field }) => (
            <StockLocationScopeField
              idPrefix="origins"
              scope={scope}
              onScopeChange={(next) => {
                form.setValue('scope', next, { shouldDirty: true })
                if (next === 'all') field.onChange([])
              }}
              locations={stockLocations?.data ?? []}
              selectedIds={field.value}
              onSelectedIdsChange={field.onChange}
              allLabel={t('admin.delivery_profiles.all_locations')}
              selectedLabel={t('admin.delivery_profiles.selected_locations')}
              emptyLabel={t('admin.delivery_profiles.detail.no_stock_locations')}
            />
          )}
        />

        <Can I="update" a={Subject.DeliveryProfile}>
          <Button
            type="button"
            size="sm"
            className="self-start"
            onClick={form.handleSubmit(onSubmit)}
            disabled={form.formState.isSubmitting || !form.formState.isDirty}
          >
            {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
          </Button>
        </Can>
      </CardContent>
    </Card>
  )
}
