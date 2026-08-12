import type { DigitalAssetProvider } from '@spree/admin-sdk'
import {
  Button,
  Sheet,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useCreateDigitalAsset } from '../../../hooks/use-digital-assets'
import { defaultProviderSettings, ProviderSettingsFields } from './provider-settings-fields'

interface Props {
  productId: string
  /** The picked source, or null when the sheet is closed. */
  provider: DigitalAssetProvider | null
  onOpenChange: (open: boolean) => void
  onCreated: () => void
}

/**
 * Captures a provider-backed asset's settings before creating it. Only opened
 * for a provider that declares fields; a settings-free provider creates in one
 * click from the source menu without this sheet.
 */
export function DigitalAssetProviderSheet({ productId, provider, onOpenChange, onCreated }: Props) {
  const { t } = useTranslation()
  const createAsset = useCreateDigitalAsset(productId)
  const [values, setValues] = useState<Record<string, unknown>>({})

  // Re-seed with the provider's defaults each time a source is picked.
  useEffect(() => {
    if (provider) setValues(defaultProviderSettings(provider.settings_schema))
  }, [provider])

  if (!provider) return null

  async function handleCreate() {
    await createAsset.mutateAsync({
      provider_type: provider!.type,
      provider_settings: values,
    })
    onCreated()
    onOpenChange(false)
  }

  return (
    <Sheet open={Boolean(provider)} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="flex flex-col">
        <SheetHeader>
          <SheetTitle>{provider.name}</SheetTitle>
        </SheetHeader>

        <div className="flex flex-1 flex-col gap-6 overflow-y-auto p-4">
          <ProviderSettingsFields
            schema={provider.settings_schema}
            values={values}
            onChange={setValues}
          />
        </div>

        <SheetFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" onClick={handleCreate} disabled={createAsset.isPending}>
            {createAsset.isPending ? t('admin.actions.saving') : t('admin.actions.add')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
