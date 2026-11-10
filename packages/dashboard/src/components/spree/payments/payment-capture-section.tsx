import type { Store } from '@spree/admin-sdk'
import { CAPTURE_METHODS } from '@spree/core'
import {
  Button,
  Card,
  CardContent,
  CardFooter,
  Section,
  SectionHeader,
  SectionTitle,
  toastManager,
} from '@spree/dashboard-ui'
import { HandCoinsIcon } from '@spree/dashboard-ui/icons'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useUpdateStoreSettings } from '../../../hooks/use-store-settings'
import { ChoiceCardPicker } from '../choice-card-picker'

type CaptureMethod = (typeof CAPTURE_METHODS)[number]

/** The store-wide default for when payments are taken; each method can override it. */
export function PaymentCaptureSection({ store }: { store: Store }) {
  const { t } = useTranslation()
  const updateMutation = useUpdateStoreSettings()
  const saved = (store.capture_method as CaptureMethod) ?? 'checkout'
  const [value, setValue] = useState<CaptureMethod>(saved)

  const options = useMemo(
    () =>
      CAPTURE_METHODS.map((option) => ({
        value: option,
        label: t(`admin.fields.store.capture_method.options.${option}.label`),
        description: t(`admin.fields.store.capture_method.options.${option}.description`),
      })),
    [t],
  )

  async function save() {
    try {
      await updateMutation.mutateAsync({ capture_method: value })
      toastManager.add({ type: 'success', title: t('admin.messages.store_settings_updated') })
    } catch {
      toastManager.add({ type: 'error', title: t('admin.errors.failed_to_update') })
    }
  }

  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <HandCoinsIcon />
          {t('admin.pages.settings.payments.capture_title')}
        </SectionTitle>
      </SectionHeader>
      <Card>
        <CardContent>
          <ChoiceCardPicker
            label={t('admin.fields.store.capture_method.label')}
            help={t('admin.fields.store.capture_method.help')}
            options={options}
            value={value}
            onChange={setValue}
          />
        </CardContent>
        {value !== saved && (
          <CardFooter className="justify-end gap-2">
            <Button type="button" variant="outline" size="sm" onClick={() => setValue(saved)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="button" size="sm" disabled={updateMutation.isPending} onClick={save}>
              {updateMutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </CardFooter>
        )}
      </Card>
    </Section>
  )
}
