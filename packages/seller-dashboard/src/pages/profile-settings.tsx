import { zodResolver } from '@hookform/resolvers/zod'
import {
  blankToNull,
  extensionFormValues,
  extensionSubmitValues,
  mapSpreeErrorsToForm,
  PageHeader,
  ResourceImageField,
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
import { useState } from 'react'
import { Controller, FormProvider, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import type { z } from 'zod/v4'
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

// Only what this page shows. The operator's schema also checks fields edited
// elsewhere (the emails), and an error on a field that is not on the page
// would block Save with nothing to see.
const profileFormSchema = sellerFormSchema.pick({
  name: true,
  about: true,
  logo_signed_id: true,
  logo_preview_url: true,
  logo_cleared: true,
  square_logo_signed_id: true,
  square_logo_preview_url: true,
  square_logo_cleared: true,
  cover_photo_signed_id: true,
  cover_photo_preview_url: true,
  cover_photo_cleared: true,
})

type ProfileFormValues = z.infer<typeof profileFormSchema>

// Fields a plugin adds through this page's slots register under this key and
// save with the page; the API accepts what extensions opened to sellers.
const FORM_KEY = 'seller.profile'

function formValues(profile: Profile) {
  return { ...sellerFormValues(profile), ...extensionFormValues(FORM_KEY, profile) }
}

function ProfileForm({ profile }: { profile: Profile }) {
  const { t } = useTranslation()
  const update = useUpdateProfile()

  const form = useForm<ProfileFormValues>({
    resolver: zodResolver(profileFormSchema),
    defaultValues: formValues(profile),
  })

  // An image's signed id only exists once its upload finishes, so saving
  // before then would silently drop the new image.
  const [uploading, setUploading] = useState<ReadonlySet<string>>(new Set())
  const trackUpload = (kind: string) => (active: boolean) =>
    setUploading((current) => {
      const next = new Set(current)
      if (active) next.add(kind)
      else next.delete(kind)
      return next
    })

  async function onSubmit(values: ProfileFormValues) {
    if (uploading.size > 0) return

    try {
      const updated = await update.mutateAsync({
        ...extensionSubmitValues(FORM_KEY, form),
        name: values.name,
        about: blankToNull(values.about),
        ...signedIdParam('logo', values.logo_signed_id, values.logo_cleared),
        ...signedIdParam('square_logo', values.square_logo_signed_id, values.square_logo_cleared),
        ...signedIdParam('cover_photo', values.cover_photo_signed_id, values.cover_photo_cleared),
      })
      // Saved images come back as server URLs, so the upload fields start
      // empty again rather than holding the files just sent.
      form.reset(formValues(updated))
    } catch (err) {
      // Anything that is not a field error has already been toasted.
      mapSpreeErrorsToForm(err, form.setError)
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const { errors } = form.formState

  return (
    <FormProvider {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <ResourceLayout
          header={
            <PageHeader
              title={t('nav.profile')}
              description={t('profile.subtitle')}
              sticky={false}
              actions={<FormActions form={form} disabled={uploading.size > 0} />}
            />
          }
          main={
            <>
              {errors.root?.message && (
                <p className="text-base text-destructive" role="alert">
                  {errors.root.message}
                </p>
              )}
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
                      onUploadingChange={trackUpload('logo')}
                      serverUrl={profile.logo_url}
                      square
                      translationNamespace="admin.sellers"
                      labelKey="logo_label"
                      helpKey="logo_help"
                    />
                    <ResourceImageField
                      form={form}
                      kind="square_logo"
                      onUploadingChange={trackUpload('square_logo')}
                      serverUrl={profile.square_logo_url}
                      square
                      translationNamespace="admin.sellers"
                      labelKey="square_logo_label"
                      helpKey="square_logo_help"
                    />
                    <ResourceImageField
                      form={form}
                      kind="cover_photo"
                      onUploadingChange={trackUpload('cover_photo')}
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
    </FormProvider>
  )
}
