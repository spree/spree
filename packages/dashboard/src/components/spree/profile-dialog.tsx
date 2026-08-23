import { zodResolver } from '@hookform/resolvers/zod'
import { type MeResponse, SpreeError } from '@spree/admin-sdk'
import {
  ImageUploadField,
  i18n,
  mapSpreeErrorsToForm,
  switchLocale,
  useAuth,
} from '@spree/dashboard-core'
import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  ErrorState,
  Field,
  FieldError,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
} from '@spree/dashboard-ui'
import { useEffect, useMemo } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useProfile, useUpdateProfile } from '../../hooks/use-profile'
import { getAvailableUiLocales } from '../../i18n-setup'
import { type MeFormValues, meFormSchema, meToForm, meToParams } from '../../schemas/me'

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

/**
 * Edit-profile dialog for the signed-in admin. Opened from the top-bar user
 * menu — the profile has no page of its own.
 */
export function ProfileDialog({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  // The dialog is mounted on every store page; don't fetch until it opens.
  const { data: me, isLoading, error, refetch } = useProfile(open)

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.profile.title')}</DialogTitle>
          <DialogDescription>{t('admin.pages.profile.subtitle')}</DialogDescription>
        </DialogHeader>
        {error ? (
          <DialogBody>
            <ErrorState
              title={t('admin.pages.profile.load_failed_title')}
              description={error instanceof Error ? error.message : undefined}
              onRetry={() => refetch()}
            />
          </DialogBody>
        ) : isLoading || !me ? (
          <DialogBody className="flex flex-col gap-4">
            <Skeleton className="h-16 w-16 rounded-md" />
            <Skeleton className="h-9 w-full" />
            <Skeleton className="h-9 w-full" />
            <Skeleton className="h-9 w-full" />
          </DialogBody>
        ) : (
          // Mount the form only once `me` is loaded so `useForm` initializes
          // with concrete string defaults — keeps the inputs/Select controlled
          // from the first render.
          <ProfileForm me={me} onOpenChange={onOpenChange} />
        )}
      </DialogContent>
    </Dialog>
  )
}

function ProfileForm({
  me,
  onOpenChange,
}: {
  me: MeResponse
  onOpenChange: (open: boolean) => void
}) {
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

  // Release the picked avatar's object URL when it's replaced or the dialog
  // unmounts. ImageUploadField hands the blob URL to the form (its caller), so
  // the form owns revoking it — otherwise form.reset() (re-baseline above) or a
  // close drops it without freeing the blob. Double-revokes (the field also
  // revokes on replace/remove) are harmless no-ops.
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
      // Closing unmounts the form, so the avatar state doesn't need preserving
      // across the save — the reopened dialog re-hydrates from the mutation
      // response that `useUpdateProfile` writes into the cache.
      form.reset({ ...values, avatar_signed_id: null })
      onOpenChange(false)
      // Apply a changed admin language by reloading in the new language.
      const code = values.selected_locale
      if (code && code !== i18n.language) switchLocale(code)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(err instanceof Error ? err.message : t('admin.errors.failed_to_update_profile'))
    }
  }

  // Admin-UI language options come from the dashboard's own shipped locale
  // bundles (see getAvailableUiLocales) — NOT the backend. The picker is hidden
  // when fewer than two languages are installed (nothing to choose).
  const localeOptions = useMemo(
    () => getAvailableUiLocales().map((l) => ({ value: l.code, label: l.name })),
    [],
  )
  const showLanguagePicker = localeOptions.length >= 2

  const { errors, isDirty, isSubmitting } = form.formState

  return (
    <form onSubmit={form.handleSubmit(onSubmit)} className="contents">
      <DialogBody className="flex flex-col gap-4">
        {errors.root?.message && (
          <p className="text-sm text-destructive" role="alert">
            {errors.root.message}
          </p>
        )}
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
          <FieldLabel htmlFor="profile-email">{t('admin.fields.profile.email.label')}</FieldLabel>
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
          <Controller
            name="selected_locale"
            control={form.control}
            render={({ field, fieldState }) => (
              <Field>
                <FieldLabel htmlFor="profile-language">
                  {t('admin.fields.profile.selected_locale.label')}
                </FieldLabel>
                <Select
                  items={localeOptions as never}
                  value={field.value}
                  onValueChange={field.onChange}
                >
                  <SelectTrigger
                    id="profile-language"
                    aria-invalid={!!fieldState.error || undefined}
                  >
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {localeOptions.map((o) => (
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
        )}
      </DialogBody>
      <DialogFooter>
        <Button
          type="button"
          variant="outline"
          onClick={() => onOpenChange(false)}
          disabled={isSubmitting}
        >
          {t('admin.actions.cancel')}
        </Button>
        {/* Gated on `isDirty` to match `FormActions` (what the page this
            replaced used) — without it a pristine Save PATCHes and toasts
            success having changed nothing. */}
        <Button type="submit" disabled={!isDirty || isSubmitting}>
          {isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
        </Button>
      </DialogFooter>
    </form>
  )
}
