import { zodResolver } from '@hookform/resolvers/zod'
import {
  blankToNull,
  mapSpreeErrorsToForm,
  PageHeader,
  SettingsFieldGroup,
  SettingsRow,
  SettingsSection,
  StoreDatePicker,
} from '@spree/dashboard-core'
import {
  CardContent,
  FormActions,
  Input,
  ResourceLayout,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { Building2Icon, CalendarOffIcon, MailIcon, MapPinIcon } from '@spree/dashboard-ui/icons'
import type { Profile } from '@spree/seller-sdk'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { CenteredMessage } from '../components/centered-message'
import { SellerAddressCard } from '../components/seller-address-card'
import { SellerReturnsLocationCard } from '../components/seller-returns-location-card'
import { useProfile, useUpdateProfile } from '../hooks/use-profile'

const generalSettingsSchema = z.object({
  contact_email: z.email().or(z.literal('')),
  billing_email: z.email().or(z.literal('')),
  legal_name: z.string().trim(),
  registration_number: z.string().trim(),
  holiday_mode_until: z.string(),
})

type GeneralSettingsValues = z.infer<typeof generalSettingsSchema>

function formValues(profile: Profile): GeneralSettingsValues {
  return {
    contact_email: profile.contact_email ?? '',
    billing_email: profile.billing_email ?? '',
    legal_name: profile.legal_name ?? '',
    registration_number: profile.registration_number ?? '',
    holiday_mode_until: profile.holiday_mode_until ?? '',
  }
}

/**
 * The seller's own configuration that buyers never see: how the marketplace
 * reaches them, the business behind them, where post and returns go, and
 * whether they are taking orders.
 */
export function GeneralSettingsPage() {
  const { t } = useTranslation()
  const { data: profile, isLoading, error } = useProfile()

  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (error || !profile) return <CenteredMessage>{t('common.error')}</CenteredMessage>

  return <GeneralSettingsForm profile={profile} />
}

function GeneralSettingsForm({ profile }: { profile: Profile }) {
  const { t } = useTranslation()
  const update = useUpdateProfile()

  const form = useForm<GeneralSettingsValues>({
    resolver: zodResolver(generalSettingsSchema),
    defaultValues: formValues(profile),
  })

  async function onSubmit(values: GeneralSettingsValues) {
    try {
      const updated = await update.mutateAsync({
        contact_email: blankToNull(values.contact_email),
        billing_email: blankToNull(values.billing_email),
        legal_name: blankToNull(values.legal_name),
        registration_number: blankToNull(values.registration_number),
        holiday_mode_until: blankToNull(values.holiday_mode_until),
      })
      form.reset(formValues(updated))
    } catch (err) {
      // Anything that is not a field error has already been toasted.
      mapSpreeErrorsToForm(err, form.setError)
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const { errors } = form.formState

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <ResourceLayout
        header={
          <PageHeader
            title={t('settings_general.title')}
            description={t('settings_general.description')}
            sticky={false}
            actions={<FormActions form={form} />}
          />
        }
        main={
          <>
            <SettingsSection title={t('settings_general.sections.contact')} icon={<MailIcon />}>
              <CardContent>
                <SettingsFieldGroup>
                  <SettingsRow
                    label={t('admin.fields.contact_email.label')}
                    htmlFor="seller-contact-email"
                    help={t('admin.fields.seller.contact_email.help')}
                    error={errors.contact_email}
                  >
                    <Input
                      id="seller-contact-email"
                      type="email"
                      className="@md/field-group:w-80"
                      aria-invalid={!!errors.contact_email || undefined}
                      {...form.register('contact_email')}
                    />
                  </SettingsRow>
                  <SettingsRow
                    label={t('admin.fields.seller.billing_email.label')}
                    htmlFor="seller-billing-email"
                    help={t('admin.fields.seller.billing_email.help')}
                    error={errors.billing_email}
                  >
                    <Input
                      id="seller-billing-email"
                      type="email"
                      className="@md/field-group:w-80"
                      aria-invalid={!!errors.billing_email || undefined}
                      {...form.register('billing_email')}
                    />
                  </SettingsRow>
                </SettingsFieldGroup>
              </CardContent>
            </SettingsSection>

            <SettingsSection
              title={t('settings_general.sections.business')}
              icon={<Building2Icon />}
            >
              <CardContent>
                <SettingsFieldGroup>
                  <SettingsRow
                    label={t('profile.legal_name')}
                    htmlFor="seller-legal-name"
                    error={errors.legal_name}
                  >
                    <Input
                      id="seller-legal-name"
                      className="@md/field-group:w-80"
                      {...form.register('legal_name')}
                    />
                  </SettingsRow>
                  <SettingsRow
                    label={t('profile.registration_number')}
                    htmlFor="seller-registration-number"
                    error={errors.registration_number}
                  >
                    <Input
                      id="seller-registration-number"
                      className="@md/field-group:w-80"
                      {...form.register('registration_number')}
                    />
                  </SettingsRow>
                </SettingsFieldGroup>
              </CardContent>
            </SettingsSection>

            {/* Each address saves on its own from a dialog. The dialog's form
                is portalled but still a React child of this one, so its submit
                would bubble here and save the page too. */}
            <section onSubmit={(event) => event.stopPropagation()}>
              <SettingsSection
                title={t('settings_general.sections.addresses')}
                icon={<MapPinIcon />}
              >
                <CardContent>
                  <SettingsFieldGroup>
                    <SettingsRow label={t('profile.billing_address')}>
                      <SellerAddressCard profile={profile} headless />
                    </SettingsRow>
                    <SettingsRow label={t('profile.returns_address')}>
                      <SellerReturnsLocationCard headless />
                    </SettingsRow>
                  </SettingsFieldGroup>
                </CardContent>
              </SettingsSection>
            </section>

            <SettingsSection
              title={t('settings_general.sections.holiday')}
              icon={<CalendarOffIcon />}
            >
              <CardContent>
                <SettingsFieldGroup>
                  <Controller
                    name="holiday_mode_until"
                    control={form.control}
                    render={({ field, fieldState }) => (
                      <SettingsRow
                        label={t('admin.fields.seller.holiday_mode_until.label')}
                        htmlFor="seller-holiday-mode-until"
                        help={t('admin.fields.seller.holiday_mode_until.help')}
                        error={fieldState.error}
                      >
                        <StoreDatePicker
                          className="w-full @md/field-group:w-80"
                          id="seller-holiday-mode-until"
                          value={field.value || null}
                          onChange={(next) => field.onChange(next ?? '')}
                          placeholder={t('admin.fields.seller.holiday_mode_until.placeholder')}
                          includeTime
                        />
                      </SettingsRow>
                    )}
                  />
                </SettingsFieldGroup>
              </CardContent>
            </SettingsSection>
          </>
        }
      />
    </form>
  )
}
