import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError, type Store, type StoreUpdateParams } from '@spree/admin-sdk'
import { EMAIL_FONTS } from '@spree/core'
import {
  ImageUploadField,
  mapSpreeErrorsToForm,
  PageHeader,
  SettingsFieldGroup,
  SettingsRow,
  SettingsSection,
  SettingsSwitchField,
  Subject,
  signedIdParam,
  usePermissions,
} from '@spree/dashboard-core'
import {
  CardContent,
  ColorPicker,
  ErrorState,
  FormActions,
  Input,
  ResourceLayout,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  toastManager,
  useDebouncedValue,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { MailIcon, PaletteIcon, SendIcon } from '@spree/dashboard-ui/icons'
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
    ...signedIdParam('mailer_logo', values.mailer_logo_signed_id, values.mailer_logo_cleared),
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
              <p className="text-base text-destructive" role="alert">
                {errors.root.message}
              </p>
            )}

            <SettingsSection
              title={t('admin.pages.settings.emails.section_delivery')}
              icon={<SendIcon />}
            >
              <CardContent>
                <SettingsSwitchField
                  id="store-send-consumer-emails"
                  label={t('admin.fields.store.send_consumer_transactional_emails.label')}
                  help={t('admin.fields.store.send_consumer_transactional_emails.help')}
                  name="send_consumer_transactional_emails"
                  control={form.control}
                />
              </CardContent>
            </SettingsSection>

            {sendConsumerEmails && (
              <>
                <SettingsSection
                  title={t('admin.pages.settings.emails.section_addresses')}
                  icon={<MailIcon />}
                >
                  <CardContent>
                    <SettingsFieldGroup>
                      <SettingsRow
                        label={t('admin.fields.store.mail_from_address.label')}
                        htmlFor="store-mail-from-address"
                        help={t('admin.fields.store.mail_from_address.help')}
                        error={errors.mail_from_address}
                      >
                        <Input
                          id="store-mail-from-address"
                          type="email"
                          className="@md/field-group:w-72"
                          placeholder={t('admin.fields.store.mail_from_address.placeholder')}
                          aria-invalid={!!errors.mail_from_address || undefined}
                          {...form.register('mail_from_address')}
                        />
                      </SettingsRow>
                      <SettingsRow
                        label={t('admin.fields.store.customer_support_email.label')}
                        htmlFor="store-customer-support-email"
                        help={t('admin.fields.store.customer_support_email.help')}
                        error={errors.customer_support_email}
                      >
                        <Input
                          id="store-customer-support-email"
                          type="email"
                          className="@md/field-group:w-72"
                          placeholder={t('admin.fields.store.customer_support_email.placeholder')}
                          aria-invalid={!!errors.customer_support_email || undefined}
                          {...form.register('customer_support_email')}
                        />
                      </SettingsRow>
                      <SettingsRow
                        label={t('admin.fields.store.new_order_notifications_email.label')}
                        htmlFor="store-new-order-notifications-email"
                        help={t('admin.fields.store.new_order_notifications_email.help')}
                        error={errors.new_order_notifications_email}
                      >
                        <Input
                          id="store-new-order-notifications-email"
                          type="email"
                          className="@md/field-group:w-72"
                          placeholder={t(
                            'admin.fields.store.new_order_notifications_email.placeholder',
                          )}
                          aria-invalid={!!errors.new_order_notifications_email || undefined}
                          {...form.register('new_order_notifications_email')}
                        />
                      </SettingsRow>
                    </SettingsFieldGroup>
                  </CardContent>
                </SettingsSection>

                <BrandingCard form={form} logoUrl={store.mailer_logo_url} />
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

function BrandingCard({
  form,
  logoUrl,
}: {
  form: ReturnType<typeof useForm<StoreEmailsFormValues>>
  logoUrl: string | null
}) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const { errors } = form.formState
  const fontOptions = EMAIL_FONTS.map((font) => ({
    value: font,
    label: t(`admin.pages.settings.emails.branding.fonts.${font}`),
  }))

  return (
    <SettingsSection
      title={t('admin.pages.settings.emails.branding.title')}
      icon={<PaletteIcon />}
      description={t('admin.pages.settings.emails.branding.description')}
    >
      <CardContent className="grid gap-6 lg:grid-cols-[2fr_3fr]">
        <SettingsFieldGroup>
          <LogoField form={form} initialLogoUrl={logoUrl} />
          {/* Rows even in this half-width column: the controls are short. */}
          {EMAIL_BRANDING_COLORS.map((color) => {
            const name = `email_${color}` as const
            return (
              <SettingsRow
                key={color}
                orientation="horizontal"
                label={t(`admin.fields.store.${name}.label`)}
                htmlFor={`store-email-${color}`}
                error={errors[name]}
              >
                <Controller
                  name={name}
                  control={form.control}
                  render={({ field }) => (
                    <ColorPicker
                      id={`store-email-${color}`}
                      className="w-40"
                      value={field.value}
                      onChange={(value) => field.onChange(value ?? '')}
                      placeholder={t('admin.pages.settings.emails.branding.default_color')}
                      aria-invalid={!!errors[name] || undefined}
                    />
                  )}
                />
              </SettingsRow>
            )
          })}
          <SettingsRow
            orientation="horizontal"
            label={t('admin.fields.store.email_font.label')}
            htmlFor="store-email-font"
            help={t('admin.fields.store.email_font.help')}
          >
            <Controller
              name="email_font"
              control={form.control}
              render={({ field }) => (
                <Select
                  items={fontOptions}
                  value={field.value}
                  onValueChange={(value) => field.onChange(value)}
                >
                  <SelectTrigger id="store-email-font" className="w-40">
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
          </SettingsRow>
        </SettingsFieldGroup>
        {permissions.can('update', Subject.EmailTemplate) && <BrandingPreview form={form} />}
      </CardContent>
    </SettingsSection>
  )
}

function BrandingPreview({ form }: { form: ReturnType<typeof useForm<StoreEmailsFormValues>> }) {
  const { t } = useTranslation()
  const preview = useEmailTemplatePreview(BRANDING_PREVIEW_TEMPLATE)
  const [accent, background, card, text, heading, font, logoSignedId, logoCleared] = useWatch({
    control: form.control,
    name: [
      'email_accent_color',
      'email_background_color',
      'email_card_color',
      'email_text_color',
      'email_heading_color',
      'email_font',
      'mailer_logo_signed_id',
      'mailer_logo_cleared',
    ],
  })
  // Saving resets the logo fields, which changes the params and re-renders
  // the preview with the logo the store now has.
  const params = useDebouncedValue(
    JSON.stringify({
      branding: {
        accent_color: accent,
        background_color: background,
        card_color: card,
        text_color: text,
        heading_color: heading,
        font,
      },
      ...signedIdParam('mailer_logo', logoSignedId, logoCleared),
    }),
    PREVIEW_DELAY_MS,
  )
  const { mutate } = preview

  useEffect(() => {
    mutate(JSON.parse(params))
  }, [params, mutate])

  // No customer emails installed, so there is nothing to preview.
  if (preview.error instanceof SpreeError && preview.error.status === 404) return null

  if (preview.error) {
    return (
      <p className="text-base text-muted-foreground">
        {preview.error.message || t('admin.email_templates.preview.unavailable')}
      </p>
    )
  }

  return <EmailPreviewFrame html={preview.data?.html} className="h-[32rem]" />
}
