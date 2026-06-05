import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError, type Store, type StoreUpdateParams } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, PageHeader, useDirectUpload } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  cn,
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
import { ImageIcon, UploadCloudIcon } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useStoreSettings, useUpdateStoreSettings } from '@/hooks/use-store-settings'
import { type StoreEmailsFormValues, storeEmailsFormSchema } from '@/schemas/store-emails'

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

function LogoField({
  form,
  initialLogoUrl,
}: {
  form: ReturnType<typeof useForm<StoreEmailsFormValues>>
  initialLogoUrl: string | null
}) {
  const { t } = useTranslation()
  const directUpload = useDirectUpload()
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const [uploading, setUploading] = useState(false)

  const previewUrl = form.watch('mailer_logo_preview_url')
  const cleared = form.watch('mailer_logo_cleared')
  const currentPreview = previewUrl ?? (cleared ? null : initialLogoUrl)

  // Track the latest blob URL via ref so the unmount cleanup sees the current
  // value without forcing the effect to re-subscribe on every replace. Two
  // effects: one revokes whenever previewUrl *changes* (covers form.reset
  // setting it to null after save); the unmount one revokes whatever's left.
  const previewUrlRef = useRef<string | null>(null)
  useEffect(() => {
    const previous = previewUrlRef.current
    if (previous && previous !== previewUrl) URL.revokeObjectURL(previous)
    previewUrlRef.current = previewUrl ?? null
  }, [previewUrl])
  useEffect(() => {
    return () => {
      if (previewUrlRef.current) URL.revokeObjectURL(previewUrlRef.current)
    }
  }, [])

  async function onFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setUploading(true)
    try {
      const result = await directUpload.mutateAsync(file)
      if (previewUrl) URL.revokeObjectURL(previewUrl)
      form.setValue('mailer_logo_preview_url', result.previewUrl, { shouldDirty: true })
      form.setValue('mailer_logo_signed_id', result.signedId, { shouldDirty: true })
      form.setValue('mailer_logo_cleared', false, { shouldDirty: true })
    } catch (err) {
      toast.error(
        err instanceof Error ? err.message : t('admin.pages.settings.emails.logo_upload_failed'),
      )
    } finally {
      setUploading(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  function clear() {
    if (previewUrl) {
      URL.revokeObjectURL(previewUrl)
      form.setValue('mailer_logo_preview_url', null, { shouldDirty: true })
    }
    form.setValue('mailer_logo_signed_id', null, { shouldDirty: true })
    form.setValue('mailer_logo_cleared', true, { shouldDirty: true })
  }

  return (
    <Field>
      <FieldLabel>{t('admin.fields.store.mailer_logo.label')}</FieldLabel>
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:gap-6">
        <div
          className={cn(
            'flex h-26 w-52 shrink-0 items-center justify-center overflow-hidden rounded-md border border-dashed border-border bg-muted',
            'transition-colors',
          )}
        >
          {currentPreview ? (
            <img src={currentPreview} alt="" className="size-full object-contain" />
          ) : (
            <div className="flex flex-col items-center gap-2 text-muted-foreground">
              {uploading ? (
                <UploadCloudIcon className="size-6 animate-pulse" />
              ) : (
                <ImageIcon className="size-6" />
              )}
            </div>
          )}
        </div>
        <div className="flex flex-col gap-2">
          <div className="flex flex-wrap items-center gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => fileInputRef.current?.click()}
              disabled={uploading}
            >
              {uploading
                ? t('admin.pages.settings.emails.logo_uploading')
                : currentPreview
                  ? t('admin.pages.settings.emails.logo_replace_cta')
                  : t('admin.pages.settings.emails.logo_upload_cta')}
            </Button>
            {currentPreview && (
              <Button type="button" variant="ghost" size="sm" onClick={clear} disabled={uploading}>
                {t('admin.pages.settings.emails.logo_remove_cta')}
              </Button>
            )}
          </div>
          <FieldDescription>
            {t('admin.pages.settings.emails.logo_dimensions_help')}{' '}
            {t('admin.fields.store.mailer_logo.help')}
          </FieldDescription>
        </div>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/png,image/jpeg"
          className="hidden"
          onChange={onFileChange}
        />
      </div>
    </Field>
  )
}
