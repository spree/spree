import { zodResolver } from '@hookform/resolvers/zod'
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
  toastManager,
} from '@spree/dashboard-ui'
import { type MeResponse, SpreeError } from '@spree/seller-sdk'
import { useEffect, useMemo } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useAccount, useUpdateAccount } from '../hooks/use-account'
import { getAvailableUiLocales } from '../i18n'
import {
  type AccountFormValues,
  accountFormSchema,
  accountToForm,
  accountToParams,
} from '../schemas/account'

// The language the panel is currently displaying — persisted in localStorage
// and applied by i18next at boot. Used as the fallback when the account has no
// saved `selected_locale`, so the picker reflects what the person actually
// sees (and a save persists it) rather than starting empty and matching no
// option.
function currentUiLocale(): string {
  const available = getAvailableUiLocales().map((locale) => locale.code)
  const active = i18n.resolvedLanguage ?? i18n.language
  return active && available.includes(active) ? active : 'en'
}

/**
 * Edit-account dialog for the signed-in person — their name, photo and the
 * panel's language. Opened from the sidebar's account menu; it has no page of
 * its own.
 *
 * Not to be confused with the profile page, which is the seller business they
 * act for. This is theirs, and follows them between sellers.
 */
export function AccountDialog({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  // Mounted on every page of the panel; don't fetch until it opens.
  const { data: me, isLoading, error, refetch } = useAccount(open)

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('account.title')}</DialogTitle>
          <DialogDescription>{t('account.subtitle')}</DialogDescription>
        </DialogHeader>
        {error ? (
          <DialogBody>
            <ErrorState
              title={t('account.load_failed_title')}
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
          // Mount the form only once the account has loaded, so `useForm`
          // initializes with concrete string defaults — that keeps the inputs
          // and the Select controlled from their first render.
          <AccountForm me={me} onOpenChange={onOpenChange} />
        )}
      </DialogContent>
    </Dialog>
  )
}

function AccountForm({
  me,
  onOpenChange,
}: {
  me: MeResponse
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { updateUser } = useAuth()
  const updateMutation = useUpdateAccount()

  const form = useForm<AccountFormValues>({
    resolver: zodResolver(accountFormSchema),
    defaultValues: accountToForm(me, currentUiLocale()),
  })

  // Re-baseline from the refetched account after a save (to surface the
  // newly-persisted photo as the server image), unless there are unsaved
  // edits in flight.
  useEffect(() => {
    if (form.formState.isDirty) return
    form.reset(accountToForm(me, currentUiLocale()))
  }, [me, form])

  // Release the picked photo's object URL when it is replaced or the dialog
  // unmounts. `ImageUploadField` hands the blob URL to the form, so the form
  // owns revoking it — otherwise a `reset` (the re-baseline above) or a close
  // drops the reference without freeing the blob. Double revokes are harmless.
  const avatarPreviewUrl = form.watch('avatar_preview_url')
  useEffect(() => {
    if (!avatarPreviewUrl) return
    return () => URL.revokeObjectURL(avatarPreviewUrl)
  }, [avatarPreviewUrl])

  const onSubmit = async (values: AccountFormValues) => {
    try {
      const updated = await updateMutation.mutateAsync(accountToParams(values))
      // Reflect the new name and photo in the auth context (the sidebar's
      // account row) straight away, rather than waiting for a token refresh.
      updateUser(updated.user)
      toastManager.add({ type: 'success', title: t('account.saved') })
      // Closing unmounts the form, so the avatar state needs no preserving
      // across the save — reopening re-hydrates from the mutation response
      // that `useUpdateAccount` writes into the cache.
      form.reset({ ...values, avatar_signed_id: null })
      onOpenChange(false)
      // A changed language takes effect by reloading in it.
      const code = values.selected_locale
      if (code && code !== i18n.language) switchLocale(code)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('account.save_failed'),
      })
    }
  }

  // The panel's own shipped locale bundles, not the backend — those are what
  // it can actually display. Hidden when fewer than two are installed, since
  // there is then nothing to choose.
  const localeOptions = useMemo(
    () => getAvailableUiLocales().map((locale) => ({ value: locale.code, label: locale.name })),
    [],
  )
  const showLanguagePicker = localeOptions.length >= 2

  const { errors, isDirty, isSubmitting } = form.formState

  return (
    <form onSubmit={form.handleSubmit(onSubmit)} className="contents">
      <DialogBody className="flex flex-col gap-4">
        {errors.root?.message && (
          <p className="text-destructive text-sm" role="alert">
            {errors.root.message}
          </p>
        )}
        <ImageUploadField
          square
          serverUrl={me.user.avatar_url}
          label={t('account.avatar')}
          help={t('account.avatar_help')}
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
          <FieldLabel htmlFor="account-email">{t('account.email')}</FieldLabel>
          {/* Email is identity-bound; PATCH /me does not accept it. */}
          <Input id="account-email" type="email" value={me.user.email} disabled />
        </Field>
        <Field>
          <FieldLabel htmlFor="account-first-name">{t('account.first_name')}</FieldLabel>
          <Input
            id="account-first-name"
            aria-invalid={!!errors.first_name || undefined}
            {...form.register('first_name')}
          />
          <FieldError errors={[errors.first_name]} />
        </Field>
        <Field>
          <FieldLabel htmlFor="account-last-name">{t('account.last_name')}</FieldLabel>
          <Input
            id="account-last-name"
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
                <FieldLabel htmlFor="account-language">{t('account.language')}</FieldLabel>
                <Select
                  items={localeOptions as never}
                  value={field.value}
                  onValueChange={field.onChange}
                >
                  <SelectTrigger
                    id="account-language"
                    aria-invalid={!!fieldState.error || undefined}
                  >
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {localeOptions.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
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
          {t('common.cancel')}
        </Button>
        {/* Gated on `isDirty`: without it a pristine Save sends a PATCH and
            toasts success having changed nothing. */}
        <Button type="submit" disabled={!isDirty || isSubmitting}>
          {isSubmitting ? t('account.saving') : t('common.save')}
        </Button>
      </DialogFooter>
    </form>
  )
}
