import { zodResolver } from '@hookform/resolvers/zod'
import {
  blankToNull,
  mapSpreeErrorsToForm,
  PageHeader,
  ResourceImageField,
  type SellerFormValues,
  SettingsSection,
  Slot,
  sellerFormSchema,
  sellerFormValues,
  signedIdParam,
} from '@spree/dashboard-core'
import {
  CardContent,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  FormActions,
  Input,
  ResourceLayout,
  RichTextEditor,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { ImageIcon, StoreIcon } from '@spree/dashboard-ui/icons'
import type { Profile } from '@spree/seller-sdk'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { CenteredMessage } from '../components/centered-message'
import { useProfile, useUpdateProfile } from '../hooks/use-profile'

/**
 * What buyers see of the seller — name, description and images — as one
 * form. Everything else the seller configures lives on the other settings
 * pages.
 */
export function ProfileSettingsPage() {
  const { t } = useTranslation()
  const { data: profile, isLoading, error } = useProfile()

  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (error || !profile) return <CenteredMessage>{t('common.error')}</CenteredMessage>

  return <ProfileForm profile={profile} />
}

function ProfileForm({ profile }: { profile: Profile }) {
  const { t } = useTranslation()
  const update = useUpdateProfile()

  const form = useForm<SellerFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(sellerFormSchema) as any,
    defaultValues: sellerFormValues(profile),
  })

  async function onSubmit(values: SellerFormValues) {
    try {
      const updated = await update.mutateAsync({
        name: values.name,
        about: blankToNull(values.about),
        ...signedIdParam('logo', values.logo_signed_id, values.logo_cleared),
        ...signedIdParam('square_logo', values.square_logo_signed_id, values.square_logo_cleared),
        ...signedIdParam('cover_photo', values.cover_photo_signed_id, values.cover_photo_cleared),
      })
      // Saved images come back as server URLs, so the upload fields start
      // empty again rather than holding the files just sent.
      form.reset(sellerFormValues(updated))
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
            title={t('nav.profile')}
            description={t('profile.subtitle')}
            sticky={false}
            actions={<FormActions form={form} />}
          />
        }
        main={
          <>
            <SettingsSection title={t('profile.sections.details')} icon={<StoreIcon />}>
              <CardContent>
                <FieldGroup>
                  <Field>
                    <FieldLabel htmlFor="seller-name">{t('admin.fields.name.label')}</FieldLabel>
                    <Input
                      id="seller-name"
                      aria-invalid={!!errors.name || undefined}
                      {...form.register('name')}
                    />
                    <FieldError errors={[errors.name]} />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="seller-about">
                      {t('admin.fields.seller.about.label')}
                    </FieldLabel>
                    <Controller
                      control={form.control}
                      name="about"
                      render={({ field }) => (
                        <RichTextEditor
                          id="seller-about"
                          ariaLabel={t('admin.fields.seller.about.label')}
                          value={field.value ?? ''}
                          onChange={field.onChange}
                        />
                      )}
                    />
                    <FieldDescription>{t('admin.fields.seller.about.help')}</FieldDescription>
                  </Field>
                </FieldGroup>
              </CardContent>
            </SettingsSection>

            <SettingsSection title={t('profile.sections.images')} icon={<ImageIcon />}>
              <CardContent>
                <FieldGroup>
                  <ResourceImageField
                    form={form}
                    kind="logo"
                    serverUrl={profile.logo_url}
                    square
                    translationNamespace="admin.sellers"
                    labelKey="logo_label"
                    helpKey="logo_help"
                  />
                  <ResourceImageField
                    form={form}
                    kind="square_logo"
                    serverUrl={profile.square_logo_url}
                    square
                    translationNamespace="admin.sellers"
                    labelKey="square_logo_label"
                    helpKey="square_logo_help"
                  />
                  <ResourceImageField
                    form={form}
                    kind="cover_photo"
                    serverUrl={profile.cover_photo_url}
                    translationNamespace="admin.sellers"
                    labelKey="cover_photo_label"
                    helpKey="cover_photo_help"
                  />
                </FieldGroup>
              </CardContent>
            </SettingsSection>

            <Slot name="seller.profile.form_main" context={{ profile }} />
            <Slot name="seller.profile.form_sidebar" context={{ profile }} />
          </>
        }
      />
    </form>
  )
}
