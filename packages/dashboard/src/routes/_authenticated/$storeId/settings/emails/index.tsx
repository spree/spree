import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError, type Store, type StoreUpdateParams } from '@spree/admin-sdk'
import {
  ImageUploadField,
  mapSpreeErrorsToForm,
  PageHeader,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  ColorPicker,
  ErrorState,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  FormActions,
  Input,
  ResourceLayout,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  Switch,
  toastManager,
  useDebouncedValue,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useEffect } from 'react'
import { Controller, useForm, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { EmailPreviewFrame } from '../../../../../components/spree/email-templates/email-preview-frame'
import { EmailsTabs } from '../../../../../components/spree/email-templates/emails-tabs'
import { PREVIEW_DELAY_MS } from '../../../../../components/spree/email-templates/preview-card'
import { useEmailTemplatePreview } from '../../../../../hooks/use-email-templates'
import { useStoreSettings, useUpdateStoreSettings } from '../../../../../hooks/use-store-settings'
import {
  EMAIL_BRANDING_COLORS,
  EMAIL_FONTS,
  type StoreEmailsFormValues,
  storeEmailsFormSchema,
} from '../../../../../schemas/store-emails'

const BRANDING_PREVIEW_TEMPLATE = 'spree.order_mailer.confirm_email'

export const Route = createFileRoute('/_authenticated/$storeId/settings/emails/')({
  component: EmailSettingsPage,
})

function storeToFormValues(store: Store): StoreEmailsFormValues {
  return {
    mail_from_address: store.mail_from_address ?? '',
    customer_support_email: store.customer_support_email ?? '',
    new_order_notifications_email: store.new_order_notifications_email ?? '',
    send_consumer_transactional_emails: store.send_consumer_transactional_emails,
    email_accent_color: store.email_accent_color ?? '',
    email_background_color: store.email_background_color ?? '',
    email_card_color: store.email_card_color ?? '',
    email_text_color: store.email_text_color ?? '',
    email_heading_color: store.email_heading_color ?? '',
    email_font: store.email_font ?? 'inter',
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
    send_consumer_transactional_emails: values.send_consumer_transactional_emails,
    email_accent_color: values.email_accent_color || null,
    email_background_color: values.email_background_color || null,
    email_card_color: values.email_card_color || null,
    email_text_color: values.email_text_color || null,
    email_heading_color: values.email_heading_color || null,
    email_font: values.email_font,
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
      toastManager.add({ type: 'success', title: t('admin.messages.store_settings_updated') })
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
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('admin.errors.failed_to_update_store'),
      })
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const { errors } = form.formState
  // Mirror legacy behaviour: when consumer emails are off, hide the address +
  // logo cards. Their values stay in form state so toggling back doesn't
  // require re-entering anything.
  const sendConsumerEmails = form.watch('send_consumer_transactional_emails')

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <ResourceLayout
        header={
          <PageHeader
            docsPath="settings/emails"
            title={t('admin.pages.settings.emails.title')}
            description={t('admin.pages.settings.emails.subtitle')}
            actions={<FormActions form={form} />}
          />
        }
        main={
          <>
            <EmailsTabs current="settings" />

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
                        {t('admin.fields.store.send_consumer_transactional_emails.label')}
                      </FieldLabel>
                      <FieldDescription>
                        {t('admin.fields.store.send_consumer_transactional_emails.help')}
                      </FieldDescription>
                    </div>
                    <Controller
                      name="send_consumer_transactional_emails"
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

                <BrandingCard form={form} />
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

function BrandingCard({ form }: { form: ReturnType<typeof useForm<StoreEmailsFormValues>> }) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const { errors } = form.formState
  const fontOptions = EMAIL_FONTS.map((font) => ({
    value: font,
    label: t(`admin.pages.settings.emails.branding.fonts.${font}`),
  }))

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.settings.emails.branding.title')}</CardTitle>
        <CardDescription>{t('admin.pages.settings.emails.branding.description')}</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-6 lg:grid-cols-2">
        <FieldGroup>
          {EMAIL_BRANDING_COLORS.map((color) => {
            const name = `email_${color}` as const
            return (
              <Field key={color}>
                <FieldLabel htmlFor={`store-email-${color}`}>
                  {t(`admin.fields.store.${name}.label`)}
                </FieldLabel>
                <Controller
                  name={name}
                  control={form.control}
                  render={({ field }) => (
                    <ColorPicker
                      id={`store-email-${color}`}
                      value={field.value}
                      onChange={(value) => field.onChange(value ?? '')}
                      placeholder={t('admin.pages.settings.emails.branding.default_color')}
                      aria-invalid={!!errors[name] || undefined}
                    />
                  )}
                />
                <FieldError errors={[errors[name]]} />
              </Field>
            )
          })}
          <Field>
            <FieldLabel htmlFor="store-email-font">
              {t('admin.fields.store.email_font.label')}
            </FieldLabel>
            <Controller
              name="email_font"
              control={form.control}
              render={({ field }) => (
                <Select
                  items={fontOptions}
                  value={field.value}
                  onValueChange={(value) => field.onChange(value)}
                >
                  <SelectTrigger id="store-email-font">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {fontOptions.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
            <FieldDescription>{t('admin.fields.store.email_font.help')}</FieldDescription>
          </Field>
        </FieldGroup>
        {permissions.can('update', Subject.EmailTemplate) && <BrandingPreview form={form} />}
      </CardContent>
    </Card>
  )
}

function BrandingPreview({ form }: { form: ReturnType<typeof useForm<StoreEmailsFormValues>> }) {
  const { t } = useTranslation()
  const preview = useEmailTemplatePreview(BRANDING_PREVIEW_TEMPLATE)
  const [accent, background, card, text, heading, font] = useWatch({
    control: form.control,
    name: [
      'email_accent_color',
      'email_background_color',
      'email_card_color',
      'email_text_color',
      'email_heading_color',
      'email_font',
    ],
  })
  const branding = useDebouncedValue(
    JSON.stringify({
      accent_color: accent,
      background_color: background,
      card_color: card,
      text_color: text,
      heading_color: heading,
      font,
    }),
    PREVIEW_DELAY_MS,
  )
  const { mutate } = preview

  useEffect(() => {
    mutate({ branding: JSON.parse(branding) })
  }, [branding, mutate])

  // No customer emails installed, so there is nothing to preview.
  if (preview.error instanceof SpreeError && preview.error.status === 404) return null

  if (preview.error) {
    return (
      <p className="text-sm text-muted-foreground">
        {preview.error.message || t('admin.email_templates.preview.unavailable')}
      </p>
    )
  }

  return <EmailPreviewFrame html={preview.data?.html} className="h-[32rem]" />
}
