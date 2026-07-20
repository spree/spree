import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError, type Store, type StoreUpdateParams } from '@spree/admin-sdk'
import { ImageUploadField, mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  ErrorState,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  FormActions,
  Input,
  ResourceLayout,
  Skeleton,
  Switch,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useStoreSettings, useUpdateStoreSettings } from '../../../../hooks/use-store-settings'
import { type StoreEmailsFormValues, storeEmailsFormSchema } from '../../../../schemas/store-emails'

export const Route = createFileRoute('/_authenticated/$storeId/settings/emails')({
  component: EmailSettingsPage,
})

function storeToFormValues(store: Store): StoreEmailsFormValues {
  return {
    mail_from_address: store.mail_from_address ?? '',
    customer_support_email: store.customer_support_email ?? '',
    new_order_notifications_email: store.new_order_notifications_email ?? '',
    preferred_send_consumer_transactional_emails:
      store.preferred_send_consumer_transactional_emails,
    mailer_logo_signed_id: null,
    mailer_logo_preview_url: null,
    mailer_logo_cleared: false,
  }
}

function formValuesToApiParams(values: StoreEmailsFormValues): StoreUpdateParams {
  const params: StoreUpdateParams = {
    mail_from_address: values.mail_from_address,
    customer_support_email: values.customer_support_email?.trim() || null,
    new_order_notifications_email: values.new_order_notifications_email?.trim() || null,
    preferred_send_consumer_transactional_emails:
      values.preferred_send_consumer_transactional_emails,
  }
  // Three states for the logo: untouched (omit), uploaded (send signed_id),
  // explicitly cleared (send null). Sending an empty value would be ambiguous.
  if (values.mailer_logo_signed_id) {
    params.mailer_logo = values.mailer_logo_signed_id
  } else if (values.mailer_logo_cleared) {
    params.mailer_logo = null
  }
  return params
}

function EmailSettingsPage() {
  const { t } = useTranslation()
  const { data: store, isLoading, error, refetch } = useStoreSettings()

  // Error first — otherwise a failed load gets stuck on the skeleton because
  // `!store` is also true and the error branch is unreachable.
  if (error) {
    return (
      <ErrorState
        title={t('admin.pages.settings.emails.load_failed_title')}
        description={error instanceof Error ? error.message : undefined}
        onRetry={() => refetch()}
      />
    )
  }

  if (isLoading || !store) {
    return (
      <div className="flex flex-col gap-6">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-64 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    )
  }

  return <EmailSettingsForm store={store} />
}

function EmailSettingsForm({ store }: { store: Store }) {
  const { t } = useTranslation()
  const updateMutation = useUpdateStoreSettings()

  const form = useForm<StoreEmailsFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(storeEmailsFormSchema) as any,
    defaultValues: storeToFormValues(store),
  })

  const onSubmit = async (values: StoreEmailsFormValues) => {
    try {
      await updateMutation.mutateAsync(formValuesToApiParams(values))
      toast.success(t('admin.messages.store_settings_updated'))
      // Re-seed the form from `values` so dirty state collapses; the next render
      // will reflect the server's mailer_logo_url through `store`.
      form.reset({
        ...values,
        mailer_logo_signed_id: null,
        mailer_logo_preview_url: null,
        mailer_logo_cleared: false,
      })
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(err instanceof Error ? err.message : t('admin.errors.failed_to_update_store'))
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const { errors } = form.formState
  // Mirror legacy behaviour: when consumer emails are off, hide the address +
  // logo cards. Their values stay in form state so toggling back doesn't
  // require re-entering anything.
  const sendConsumerEmails = form.watch('preferred_send_consumer_transactional_emails')

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <ResourceLayout
        header={
          <PageHeader
            title={t('admin.pages.settings.emails.title')}
            subtitle={t('admin.pages.settings.emails.subtitle')}
            actions={<FormActions form={form} />}
          />
        }
        main={
          <>
            {errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {errors.root.message}
              </p>
            )}

            <Card>
              <CardHeader>
                <CardTitle>{t('admin.pages.settings.emails.section_delivery')}</CardTitle>
              </CardHeader>
              <CardContent>
                <Field>
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex flex-col">
                      <FieldLabel htmlFor="store-send-consumer-emails" className="cursor-pointer">
                        {t('admin.fields.store.preferred_send_consumer_transactional_emails.label')}
                      </FieldLabel>
                      <FieldDescription>
                        {t('admin.fields.store.preferred_send_consumer_transactional_emails.help')}
                      </FieldDescription>
                    </div>
                    <Controller
                      name="preferred_send_consumer_transactional_emails"
                      control={form.control}
                      render={({ field }) => (
                        <Switch
                          id="store-send-consumer-emails"
                          checked={field.value}
                          onCheckedChange={field.onChange}
                        />
                      )}
                    />
                  </div>
                </Field>
              </CardContent>
            </Card>

            {sendConsumerEmails && (
              <>
                <Card>
                  <CardHeader>
                    <CardTitle>{t('admin.pages.settings.emails.section_addresses')}</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <FieldGroup>
                      <Field>
                        <FieldLabel htmlFor="store-mail-from-address">
                          {t('admin.fields.store.mail_from_address.label')}
                        </FieldLabel>
                        <Input
                          id="store-mail-from-address"
                          type="email"
                          placeholder={t('admin.fields.store.mail_from_address.placeholder')}
                          aria-invalid={!!errors.mail_from_address || undefined}
                          {...form.register('mail_from_address')}
                        />
                        <FieldDescription>
                          {t('admin.fields.store.mail_from_address.help')}
                        </FieldDescription>
                        <FieldError errors={[errors.mail_from_address]} />
                      </Field>

                      <Field>
                        <FieldLabel htmlFor="store-customer-support-email">
                          {t('admin.fields.store.customer_support_email.label')}
                        </FieldLabel>
                        <Input
                          id="store-customer-support-email"
                          type="email"
                          placeholder={t('admin.fields.store.customer_support_email.placeholder')}
                          aria-invalid={!!errors.customer_support_email || undefined}
                          {...form.register('customer_support_email')}
                        />
                        <FieldDescription>
                          {t('admin.fields.store.customer_support_email.help')}
                        </FieldDescription>
                        <FieldError errors={[errors.customer_support_email]} />
                      </Field>

                      <Field>
                        <FieldLabel htmlFor="store-new-order-notifications-email">
                          {t('admin.fields.store.new_order_notifications_email.label')}
                        </FieldLabel>
                        <Input
                          id="store-new-order-notifications-email"
                          type="email"
                          placeholder={t(
                            'admin.fields.store.new_order_notifications_email.placeholder',
                          )}
                          aria-invalid={!!errors.new_order_notifications_email || undefined}
                          {...form.register('new_order_notifications_email')}
                        />
                        <FieldDescription>
                          {t('admin.fields.store.new_order_notifications_email.help')}
                        </FieldDescription>
                        <FieldError errors={[errors.new_order_notifications_email]} />
                      </Field>
                    </FieldGroup>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle>{t('admin.pages.settings.emails.section_logo')}</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <LogoField form={form} initialLogoUrl={store.mailer_logo_url} />
                  </CardContent>
                </Card>
              </>
            )}
          </>
        }
      />
    </form>
  )
}

// Thin adapter over the reusable ImageUploadField — maps the store-emails
// form's mailer_logo_{signed_id,preview_url,cleared} triple onto the generic
// controlled ImageUploadValue.
function LogoField({
  form,
  initialLogoUrl,
}: {
  form: ReturnType<typeof useForm<StoreEmailsFormValues>>
  initialLogoUrl: string | null
}) {
  const { t } = useTranslation()

  return (
    <ImageUploadField
      serverUrl={initialLogoUrl}
      accept="image/png,image/jpeg"
      label={t('admin.fields.store.mailer_logo.label')}
      help={`${t('admin.pages.settings.emails.logo_dimensions_help')} ${t('admin.fields.store.mailer_logo.help')}`}
      value={{
        signedId: form.watch('mailer_logo_signed_id') ?? null,
        previewUrl: form.watch('mailer_logo_preview_url') ?? null,
        cleared: form.watch('mailer_logo_cleared') ?? false,
      }}
      onChange={(next) => {
        form.setValue('mailer_logo_signed_id', next.signedId, { shouldDirty: true })
        form.setValue('mailer_logo_preview_url', next.previewUrl, { shouldDirty: true })
        form.setValue('mailer_logo_cleared', next.cleared, { shouldDirty: true })
      }}
    />
  )
}
