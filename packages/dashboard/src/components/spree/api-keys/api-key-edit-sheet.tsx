import { zodResolver } from '@hookform/resolvers/zod'
import { type ApiKey, SpreeError } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldLabel,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  toastManager,
} from '@spree/dashboard-ui'
import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { useUpdateApiKey } from '../../../hooks/use-api-keys'
import { ApiKeyNameField, FormErrorBanner } from './api-key-form-fields'
import { ScopePicker } from './api-key-scope-picker'

type EditFormValues = { name: string }

// Lifted dialog (one instance per page, driven by `apiKey`) — mirrors
// TokenRevealDialog. Only `name` is editable; secret keys show their scopes
// disabled since scopes are fixed for the life of a key.
export function EditApiKeyDialog({
  apiKey,
  onOpenChange,
}: {
  apiKey: ApiKey | null
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const updateMutation = useUpdateApiKey()

  const form = useForm<EditFormValues>({
    resolver: zodResolver(
      z.object({ name: z.string().min(1, t('admin.fields.api_key.name.required')) }),
    ),
    defaultValues: { name: '' },
  })

  // Re-sync the form when a different key is opened. `defaultValues` alone won't
  // update across opens (the dialog is mounted once and reused), so reset
  // explicitly when the key changes.
  useEffect(() => {
    if (apiKey) form.reset({ name: apiKey.name })
  }, [apiKey, form])

  async function onSubmit(values: EditFormValues) {
    if (!apiKey) return
    try {
      await updateMutation.mutateAsync({ id: apiKey.id, params: { name: values.name } })
      toastManager.add({ type: 'success', title: t('admin.messages.key_updated') })
      onOpenChange(false)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('admin.api_keys.errors.failed_to_update'),
      })
    }
  }

  return (
    <Sheet open={!!apiKey} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.api_keys.edit_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.api_keys.edit_sheet_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FormErrorBanner message={form.formState.errors.root?.message} />
            <ApiKeyNameField
              id="edit-api-key-name"
              register={form.register}
              error={form.formState.errors.name}
            />

            {apiKey?.key_type === 'secret' && apiKey.scopes.length > 0 && (
              <Field>
                <FieldLabel>{t('admin.fields.api_key.scopes.label')}</FieldLabel>
                {/* Scopes are fixed for the life of a key — rendered disabled.
                    To change authority, create a new key and revoke this one. */}
                <ScopePicker value={apiKey.scopes} disabled />
                <p className="text-xs text-muted-foreground">
                  {t('admin.api_keys.scopes_immutable_help')}
                </p>
              </Field>
            )}
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
