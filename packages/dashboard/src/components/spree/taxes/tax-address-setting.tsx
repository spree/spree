import { Subject, usePermissions } from '@spree/dashboard-core'
import {
  Item,
  ItemActions,
  ItemContent,
  ItemDescription,
  ItemMedia,
  ItemTitle,
  Switch,
  toastManager,
} from '@spree/dashboard-ui'
import { MapPinIcon } from '@spree/dashboard-ui/icons'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useStoreSettings, useUpdateStoreSettings } from '../../../hooks/use-store-settings'

/** Which of the customer's addresses tax is worked out from. Saves as soon as it is switched. */
export function TaxAddressSetting() {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const { data: store } = useStoreSettings()
  const updateMutation = useUpdateStoreSettings()
  // The value just chosen, shown until the refetched store agrees.
  const [chosen, setChosen] = useState<boolean | null>(null)
  const saved = store?.tax_using_ship_address ?? true

  useEffect(() => {
    if (chosen === saved) setChosen(null)
  }, [chosen, saved])

  if (!store) return null

  const canWrite = permissions.can('update', Subject.Store)

  async function handleChange(next: boolean) {
    setChosen(next)
    try {
      await updateMutation.mutateAsync({ tax_using_ship_address: next })
      toastManager.add({ type: 'success', title: t('admin.messages.store_settings_updated') })
    } catch {
      setChosen(null)
      toastManager.add({ type: 'error', title: t('admin.errors.failed_to_update') })
    }
  }

  return (
    <Item variant="outline">
      <ItemMedia variant="icon">
        <MapPinIcon />
      </ItemMedia>
      <ItemContent>
        <ItemTitle>
          <label htmlFor="store-tax-using-ship-address">
            {t('admin.fields.store.tax_using_ship_address.label')}
          </label>
        </ItemTitle>
        <ItemDescription>{t('admin.fields.store.tax_using_ship_address.help')}</ItemDescription>
      </ItemContent>
      <ItemActions>
        <Switch
          id="store-tax-using-ship-address"
          checked={chosen ?? saved}
          disabled={!canWrite || updateMutation.isPending}
          onCheckedChange={handleChange}
        />
      </ItemActions>
    </Item>
  )
}
