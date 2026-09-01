import type { DeliveryMethod } from '@spree/admin-sdk'
import { Can, Subject, useStockLocations, useUpdateStockLocationById } from '@spree/dashboard-core'
import { Button, Card, CardContent, CardHeader, CardTitle, Checkbox } from '@spree/dashboard-ui'
import { PlusIcon, StoreIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { DeliveryMethodList } from './delivery-method-list'
import { useMethodSheetNavigation } from './use-method-sheet-navigation'

/**
 * The methods customers collect in person, and which counters they can
 * collect from.
 */
export function DeliveryPickupCard({ methods }: { methods: DeliveryMethod[] }) {
  const { t } = useTranslation()
  const { openNewMethod } = useMethodSheetNavigation()

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <StoreIcon className="size-4 text-muted-foreground" />
          {t('admin.delivery_profiles.detail.pickup_title')}
        </CardTitle>
        <span className="text-muted-foreground text-xs">
          {t('admin.delivery_profiles.detail.pickup_hint')}
        </span>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {methods.length > 0 ? (
          <DeliveryMethodList methods={methods} icon={StoreIcon} />
        ) : (
          <div className="flex flex-col items-start gap-2">
            <p className="text-muted-foreground text-sm">
              {t('admin.delivery_profiles.detail.pickup_empty')}
            </p>
            <Can I="create" a={Subject.DeliveryMethod}>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => openNewMethod({ provider: 'pickup' })}
              >
                <PlusIcon className="size-4" />
                {t('admin.delivery_profiles.detail.offer_pickup')}
              </Button>
            </Can>
          </div>
        )}

        <PickupLocationsBlock />
      </CardContent>
    </Card>
  )
}

/**
 * Every stock location of the store, each a counter customers can collect
 * from. Toggling writes straight through — the surrounding page is a set of
 * saved forms, so the helper line says these changes are immediate.
 */
function PickupLocationsBlock() {
  const { t } = useTranslation()
  const { data: stockLocations, isLoading } = useStockLocations()
  const updateMutation = useUpdateStockLocationById()

  const locations = stockLocations?.data ?? []

  return (
    <div className="flex flex-col gap-2 border-t pt-4">
      <span className="font-medium text-sm">
        {t('admin.delivery_profiles.detail.collect_from')}
      </span>
      <span className="text-muted-foreground text-xs">
        {t('admin.delivery_profiles.detail.collect_from_hint')}
      </span>

      {isLoading ? (
        <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
      ) : locations.length === 0 ? (
        <p className="text-muted-foreground text-sm">
          {t('admin.delivery_profiles.detail.no_stock_locations')}
        </p>
      ) : (
        <div className="flex flex-col gap-2">
          {locations.map((location) => (
            <label
              key={location.id}
              htmlFor={`pickup-location-${location.id}`}
              className="flex items-center gap-2 text-sm"
            >
              <Checkbox
                id={`pickup-location-${location.id}`}
                checked={location.pickup_enabled}
                disabled={updateMutation.isPending}
                onCheckedChange={(next) =>
                  updateMutation
                    .mutateAsync({
                      id: location.id,
                      params: { pickup_enabled: !!next },
                    })
                    .catch(() => undefined)
                }
              />
              {location.name}
            </label>
          ))}
        </div>
      )}
    </div>
  )
}
