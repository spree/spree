import { zodResolver } from '@hookform/resolvers/zod'
import { type MeResponse, SpreeError } from '@spree/admin-sdk'
import {
  ImageUploadField,
  i18n,
  mapSpreeErrorsToForm,
  PageHeader,
  switchLocale,
  useAuth,
} from '@spree/dashboard-core'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  ErrorState,
  Field,
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
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useEffect, useMemo } from 'react'
import {
  type Control,
  Controller,
  type FieldPath,
  type FieldValues,
  useForm,
} from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useProfile, useUpdateProfile } from '@/hooks/use-profile'
import { getAvailableUiLocales } from '@/i18n-setup'
import { type MeFormValues, meFormSchema, meToForm, meToParams } from '@/schemas/me'

export const Route = createFileRoute('/_authenticated/$storeId/settings/profile')({
  component: ProfilePage,
})

// The language the dashboard is currently displaying — persisted in
// localStorage and applied by i18next at boot. Used as the profile language
// fallback when the account has no saved `selected_locale`, so the picker
// reflects what the user actually sees (and a save persists it) instead of
// initializing to an empty value that matches no option and renders blank.
function currentUiLocale(): string {
  const available = getAvailableUiLocales().map((l) => l.code)
  const active = i18n.resolvedLanguage ?? i18n.language
  return active && available.includes(active) ? active : 'en'
}

function ProfilePage() {
  const { t } = useTranslation()
  const { data: me, isLoading, error, refetch } = useProfile()

  // Check error first: a failed fetch leaves `me` undefined, which would
  // otherwise render the skeleton forever instead of the error state.
  if (error) {
    return (
      <ErrorState
        title={t('admin.pages.profile.load_failed_title')}
        description={error instanceof Error ? error.message : undefined}
        onRetry={() => refetch()}
      />
    )
  }

  if (isLoading || !me) {
    return (
      <div className="flex flex-col gap-6">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-64 w-full" />
      </div>
    )
  }

  // Mount the form only once `me` is loaded so `useForm` initializes with
  // concrete string defaults — keeps the inputs/Select controlled from the
  // first render.
  return <ProfileForm me={me} />
}

function ProfileForm({ me }: { me: MeResponse }) {
  const { t } = useTranslation()
  const { updateUser } = useAuth()
  const updateMutation = useUpdateProfile()

  const form = useForm<MeFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(meFormSchema) as any,
    defaultValues: meToForm(me, currentUiLocale()),
  })

  // Re-baseline from the refetched profile after a save (e.g. to surface the
  // newly-persisted avatar_url as the server image), unless the admin has
  // unsaved edits in flight.
  useEffect(() => {
    if (form.formState.isDirty) return
    form.reset(meToForm(me, currentUiLocale()))
  }, [me, form])

  // Release the picked avatar's object URL when it's replaced or the page
  // unmounts. ImageUploadField hands the blob URL to the form (its caller), so
  // the form owns revoking it — otherwise form.reset() (re-baseline above) or a
  // navigate-away drops it without freeing the blob. Double-revokes (the field
  // also revokes on replace/remove) are harmless no-ops.
  const avatarPreviewUrl = form.watch('avatar_preview_url')
  useEffect(() => {
    if (!avatarPreviewUrl) return
    return () => URL.revokeObjectURL(avatarPreviewUrl)
  }, [avatarPreviewUrl])

  const onSubmit = async (values: MeFormValues) => {
    try {
      const updated = await updateMutation.mutateAsync(meToParams(values))
      // Reflect the new name/locale/avatar in the auth context (top-bar, etc.)
      // immediately instead of waiting for the next token refresh.
      updateUser(updated.user)
      toast.success(t('admin.messages.profile_updated'))
      // Reset FIRST so the form is no longer dirty — otherwise the language
      // switch below reloads the page while the `beforeunload` dirty-guard is
      // still armed, triggering the browser's "unsaved changes" prompt. Drop the
      // consumed signed_id so a second save can't re-attach it, but KEEP
      // avatar_cleared: forcing it false here would make the field fall back to
      // the still-cached (stale) avatar_url and briefly re-show a just-removed
      // photo. The re-hydrate effect resets it once the profile refetch lands.
      form.reset({ ...values, avatar_signed_id: null })
      // Apply a changed admin language by reloading in the new language.
      const code = values.selected_locale
      if (code && code !== i18n.language) switchLocale(code)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(err instanceof Error ? err.message : t('admin.errors.failed_to_update_profile'))
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  // Admin-UI language options come from the dashboard's own shipped locale
  // bundles (see getAvailableUiLocales) — NOT the backend. The picker is hidden
  // when fewer than two languages are installed (nothing to choose).
  const localeOptions = useMemo(
    () => getAvailableUiLocales().map((l) => ({ value: l.code, label: l.name })),
    [],
  )
  const showLanguagePicker = localeOptions.length >= 2

  const { errors } = form.formState

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <ResourceLayout
        header={
          <PageHeader
            title={t('admin.pages.profile.title')}
            subtitle={t('admin.pages.profile.subtitle')}
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
                <CardTitle>{t('admin.pages.profile.personal_details')}</CardTitle>
              </CardHeader>
              <CardContent>
                <FieldGroup>
                  <ImageUploadField
                    square
                    serverUrl={me.user.avatar_url}
                    label={t('admin.fields.profile.avatar.label')}
                    help={t('admin.fields.profile.avatar.help')}
                    value={{
                      signedId: form.watch('avatar_signed_id'),
                      previewUrl: form.watch('avatar_preview_url'),
                      cleared: form.watch('avatar_cleared'),
                    }}
                    onChange={(next) => {
                      form.setValue('avatar_signed_id', next.signedId, { shouldDirty: true })
                      form.setValue('avatar_preview_url', next.previewUrl, { shouldDirty: true })
                      form.setValue('avatar_cleared', next.cleared, { shouldDirty: true })
                    }}
                  />
                  <Field>
                    <FieldLabel htmlFor="profile-email">
                      {t('admin.fields.profile.email.label')}
                    </FieldLabel>
                    {/* Email is identity-bound; PATCH /me does not accept it. */}
                    <Input id="profile-email" type="email" value={me.user.email} disabled />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="profile-first-name">
                      {t('admin.fields.profile.first_name.label')}
                    </FieldLabel>
                    <Input
                      id="profile-first-name"
                      aria-invalid={!!errors.first_name || undefined}
                      {...form.register('first_name')}
                    />
                    <FieldError errors={[errors.first_name]} />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="profile-last-name">
                      {t('admin.fields.profile.last_name.label')}
                    </FieldLabel>
                    <Input
                      id="profile-last-name"
                      aria-invalid={!!errors.last_name || undefined}
                      {...form.register('last_name')}
                    />
                    <FieldError errors={[errors.last_name]} />
                  </Field>
                  {showLanguagePicker && (
                    <SelectField
                      id="profile-language"
                      label={t('admin.fields.profile.selected_locale.label')}
                      name="selected_locale"
                      control={form.control}
                      options={localeOptions}
                    />
                  )}
                </FieldGroup>
              </CardContent>
            </Card>
          </>
        }
      />
    </form>
  )
}

interface SelectFieldProps<TValues extends FieldValues> {
  id: string
  label: string
  placeholder?: string
  name: FieldPath<TValues>
  control: Control<TValues>
  options: ReadonlyArray<{ value: string; label: string }>
}

function SelectField<TValues extends FieldValues>({
  id,
  label,
  placeholder,
  name,
  control,
  options,
}: SelectFieldProps<TValues>) {
  return (
    <Controller
      name={name}
      control={control}
      render={({ field, fieldState }) => (
        <Field>
          <FieldLabel htmlFor={id}>{label}</FieldLabel>
          <Select items={options as never} value={field.value} onValueChange={field.onChange}>
            <SelectTrigger id={id} aria-invalid={!!fieldState.error || undefined}>
              <SelectValue placeholder={placeholder} />
            </SelectTrigger>
            <SelectContent>
              {options.map((o) => (
                <SelectItem key={o.value} value={o.value}>
                  {o.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <FieldError errors={[fieldState.error]} />
        </Field>
      )}
    />
  )
}
