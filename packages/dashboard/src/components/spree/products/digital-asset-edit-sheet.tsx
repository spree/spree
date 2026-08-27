import type { DigitalAsset, DigitalAssetProviderSettingField, Variant } from '@spree/admin-sdk'
import {
  Button,
  Field,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useUpdateDigitalAsset } from '../../../hooks/use-digital-assets'
import { ProviderSettingsFields } from './provider-settings-fields'

interface Props {
  productId: string
  asset: DigitalAsset | null
  variants?: Variant[]
  /** Fields for a provider-backed asset; empty for an uploaded file. */
  settingsSchema?: DigitalAssetProviderSettingField[]
  open: boolean
  onOpenChange: (open: boolean) => void
}

/** Blank means "use the store's setting", so an empty box is a real value. */
function toInput(value: number | null | undefined): string {
  return value == null ? '' : String(value)
}

function parseLimit(raw: string): number | null | undefined {
  if (raw.trim() === '') return null
  const parsed = Number(raw)
  return Number.isInteger(parsed) && parsed >= 1 ? parsed : undefined
}

export function DigitalAssetEditSheet({
  productId,
  asset,
  variants,
  settingsSchema = [],
  open,
  onOpenChange,
}: Props) {
  const { t } = useTranslation()
  const updateAsset = useUpdateDigitalAsset(productId)

  const [clicks, setClicks] = useState('')
  const [days, setDays] = useState('')
  const [variantId, setVariantId] = useState('')
  const [settings, setSettings] = useState<Record<string, unknown>>({})
  const [error, setError] = useState<string | null>(null)

  // Re-seed whenever a different file is opened, so the sheet never shows the
  // previous row's values.
  useEffect(() => {
    if (!asset) return
    setClicks(toInput(asset.authorized_clicks))
    setDays(toInput(asset.authorized_days))
    setVariantId(asset.variant_id ?? '')
    setSettings(asset.provider_settings ?? {})
    setError(null)
  }, [asset])

  if (!asset) return null

  const hasVariants = (variants?.length ?? 0) > 1

  async function handleSave() {
    const parsedClicks = parseLimit(clicks)
    const parsedDays = parseLimit(days)

    if (parsedClicks === undefined || parsedDays === undefined) {
      setError(t('admin.digital_assets.limit_invalid'))
      return
    }

    setError(null)
    try {
      await updateAsset.mutateAsync({
        id: asset!.id,
        authorized_clicks: parsedClicks,
        authorized_days: parsedDays,
        ...(hasVariants && variantId ? { variant_id: variantId } : {}),
        ...(settingsSchema.length > 0 ? { provider_settings: settings } : {}),
      })
      onOpenChange(false)
    } catch (err) {
      // useResourceMutation suppresses the toast for a 422, so surface the
      // reason inline and keep the sheet open with the entered values.
      setError(err instanceof Error ? err.message : t('admin.errors.unexpected'))
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="flex flex-col">
        <SheetHeader>
          <SheetTitle>
            {asset.filename ?? asset.provider_name ?? t('admin.digital_assets.untitled')}
          </SheetTitle>
        </SheetHeader>

        <div className="flex flex-1 flex-col gap-6 overflow-y-auto p-4">
          <ProviderSettingsFields
            schema={settingsSchema}
            values={settings}
            onChange={setSettings}
          />

          {hasVariants && (
            <Field>
              <FieldLabel htmlFor="digital-asset-variant">
                {t('admin.digital_assets.columns.variant')}
              </FieldLabel>
              <Select value={variantId} onValueChange={setVariantId}>
                <SelectTrigger id="digital-asset-variant">
                  <SelectValue>
                    {(value) =>
                      variants?.find((v) => v.id === value)?.options_text ??
                      t('admin.digital_assets.all_variants')
                    }
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {variants?.map((variant) => (
                    <SelectItem key={variant.id} value={variant.id}>
                      {variant.options_text || variant.sku}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>
          )}

          <Field>
            <FieldLabel htmlFor="digital-asset-clicks">
              {t('admin.fields.store.digital_asset_authorized_clicks.label')}
            </FieldLabel>
            <Input
              id="digital-asset-clicks"
              type="number"
              min={1}
              value={clicks}
              placeholder={String(asset.effective_authorized_clicks)}
              onChange={(e) => setClicks(e.target.value)}
            />
          </Field>

          <Field>
            <FieldLabel htmlFor="digital-asset-days">
              {t('admin.fields.store.digital_asset_authorized_days.label')}
            </FieldLabel>
            <Input
              id="digital-asset-days"
              type="number"
              min={1}
              value={days}
              placeholder={String(asset.effective_authorized_days)}
              onChange={(e) => setDays(e.target.value)}
            />
          </Field>

          <p className="text-muted-foreground text-xs">{t('admin.digital_assets.limits_help')}</p>

          {error && <p className="text-destructive text-sm">{error}</p>}
        </div>

        <SheetFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" onClick={handleSave} disabled={updateAsset.isPending}>
            {updateAsset.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
