import { zodResolver } from '@hookform/resolvers/zod'
import type { Store } from '@spree/admin-sdk'
import { STOREFRONT_ACCESSES } from '@spree/core'
import {
  mapSpreeErrorsToForm,
  PageHeader,
  SettingsFieldGroup,
  SettingsRow,
  SettingsSection,
  SettingsSelectField,
  SettingsSwitchField,
} from '@spree/dashboard-core'
import {
  Button,
  CardContent,
  ErrorState,
  ExternalLink,
  FormActions,
  ResourceLayout,
  Skeleton,
  toastManager,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { GlobeIcon, MapPinIcon, ShoppingCartIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute } from '@tanstack/react-router'
import { useMemo, useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { StorefrontConnectSheet } from '../../../../components/spree/storefront-connect-sheet'
import { useStoreSettings, useUpdateStoreSettings } from '../../../../hooks/use-store-settings'
import {
  type StorefrontSettingsFormValues,
  storefrontSettingsFormSchema,
} from '../../../../schemas/store'

export const Route = createFileRoute('/_authenticated/$storeId/settings/storefront')({
  component: StorefrontSettingsPage,
})

function storeToFormValues(store: Store): StorefrontSettingsFormValues {
  return {
    storefront_access:
      (store.storefront_access as (typeof STOREFRONT_ACCESSES)[number]) ?? 'public',
    guest_checkout: store.guest_checkout ?? true,
    always_include_confirm_step: store.always_include_confirm_step ?? false,
    company_field_enabled: store.company_field_enabled ?? false,
    address_requires_phone: store.address_requires_phone ?? false,
  }
}

function StorefrontSettingsPage() {
  const { t } = useTranslation()
  const { data: store, isLoading, error, refetch } = useStoreSettings()

  if (error) {
    return (
      <ErrorState
        title={t('admin.store.load_failed_title')}
        description={error instanceof Error ? error.message : undefined}
        onRetry={() => refetch()}
      />
    )
  }

  if (isLoading || !store) {
    return (
      <div className="flex flex-col gap-6">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-48 w-full" />
        <Skeleton className="h-48 w-full" />
      </div>
    )
  }

  // Mounted once the store has loaded, so the form starts from real values.
  return <StorefrontSettingsForm store={store} />
}

function StorefrontSettingsForm({ store }: { store: Store }) {
  const { t } = useTranslation()
  const updateMutation = useUpdateStoreSettings()
  const [connecting, setConnecting] = useState(false)

  const form = useForm<StorefrontSettingsFormValues>({
    resolver: zodResolver(storefrontSettingsFormSchema),
    defaultValues: storeToFormValues(store),
  })

  const accessOptions = useMemo(
    () =>
      STOREFRONT_ACCESSES.map((value) => ({
        value,
        label: t(`admin.fields.store.storefront_access.options.${value}`),
      })),
    [t],
  )

  async function onSubmit(values: StorefrontSettingsFormValues) {
    try {
      await updateMutation.mutateAsync(values)
      form.reset(values)
      toastManager.add({ type: 'success', title: t('admin.messages.store_settings_updated') })
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      toastManager.add({ type: 'error', title: t('admin.errors.failed_to_update_store') })
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const storefrontUrl = store.storefront_url

  return (
    <>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <ResourceLayout
          header={
            <PageHeader
              docsPath="settings/storefront"
              resource={store}
              endpoint="/api/v3/admin/store"
              title={t('admin.pages.settings.storefront.title')}
              description={t('admin.pages.settings.storefront.description')}
              actions={<FormActions form={form} onDiscard={() => form.reset()} />}
            />
          }
          main={
            <>
              {form.formState.errors.root?.message && (
                <p className="text-base text-destructive" role="alert">
                  {form.formState.errors.root.message}
                </p>
              )}
              <SettingsSection
                title={t('admin.pages.settings.storefront.storefront_title')}
                icon={<GlobeIcon />}
              >
                <CardContent>
                  <SettingsFieldGroup>
                    <SettingsRow
                      label={t('admin.pages.settings.storefront.url.label')}
                      help={t('admin.pages.settings.storefront.url.help')}
                    >
                      {storefrontUrl ? (
                        <ExternalLink href={storefrontUrl} className="min-w-0 truncate">
                          {storefrontUrl}
                        </ExternalLink>
                      ) : (
                        <span className="text-muted-foreground">
                          {t('admin.pages.settings.storefront.url.not_connected')}
                        </span>
                      )}
                      <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        onClick={() => setConnecting(true)}
                      >
                        {storefrontUrl
                          ? t('admin.pages.settings.storefront.url.change')
                          : t('admin.pages.settings.storefront.url.connect')}
                      </Button>
                    </SettingsRow>
                    <SettingsSelectField
                      id="store-storefront-access"
                      label={t('admin.fields.store.storefront_access.label')}
                      name="storefront_access"
                      control={form.control}
                      options={accessOptions}
                      help={t('admin.fields.store.storefront_access.help')}
                    />
                  </SettingsFieldGroup>
                </CardContent>
              </SettingsSection>

              <SettingsSection
                title={t('admin.pages.settings.storefront.checkout_title')}
                icon={<ShoppingCartIcon />}
              >
                <CardContent>
                  <SettingsFieldGroup>
                    <SettingsSwitchField
                      id="store-guest-checkout"
                      label={t('admin.fields.store.guest_checkout.label')}
                      help={t('admin.fields.store.guest_checkout.help')}
                      name="guest_checkout"
                      control={form.control}
                    />
                    <SettingsSwitchField
                      id="store-always-include-confirm-step"
                      label={t('admin.fields.store.always_include_confirm_step.label')}
                      help={t('admin.fields.store.always_include_confirm_step.help')}
                      name="always_include_confirm_step"
                      control={form.control}
                    />
                  </SettingsFieldGroup>
                </CardContent>
              </SettingsSection>

              <SettingsSection
                title={t('admin.pages.settings.storefront.addresses_title')}
                icon={<MapPinIcon />}
              >
                <CardContent>
                  <SettingsFieldGroup>
                    <SettingsSwitchField
                      id="store-company-field-enabled"
                      label={t('admin.fields.store.company_field_enabled.label')}
                      help={t('admin.fields.store.company_field_enabled.help')}
                      name="company_field_enabled"
                      control={form.control}
                    />
                    <SettingsSwitchField
                      id="store-address-requires-phone"
                      label={t('admin.fields.store.address_requires_phone.label')}
                      help={t('admin.fields.store.address_requires_phone.help')}
                      name="address_requires_phone"
                      control={form.control}
                    />
                  </SettingsFieldGroup>
                </CardContent>
              </SettingsSection>
            </>
          }
        />
      </form>
      {/* Outside the page's form: the sheet submits a form of its own. */}
      {connecting && <StorefrontConnectSheet store={store} open onOpenChange={setConnecting} />}
    </>
  )
}
