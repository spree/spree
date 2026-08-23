import { zodResolver } from '@hookform/resolvers/zod'
import { type ApiKey, type ApiKeyCreateParams, SpreeError } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldLabel,
  RadioGroup,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  toastManager,
} from '@spree/dashboard-ui'
import type { TFunction } from 'i18next'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { useCreateApiKey } from '../../../hooks/use-api-keys'
import {
  ApiKeyNameField,
  ChannelBindingSelect,
  FormErrorBanner,
  KeyTypeChoice,
} from './api-key-form-fields'
import { ScopePicker } from './api-key-scope-picker'

// `channel_id` holds the raw channel selection: `''` means "All channels"
// (store-wide) and is dropped on submit; a prefixed `ch_…` binds a publishable
// key to that channel. Only publishable keys can bind — the value is ignored
// (and never sent) for secret keys.
const buildCreateSchema = (t: TFunction) =>
  z
    .object({
      name: z.string().min(1, t('admin.fields.api_key.name.required')),
      key_type: z.enum(['publishable', 'secret']),
      scopes: z.array(z.string()),
      channel_id: z.string(),
    })
    .refine((v) => v.key_type !== 'secret' || v.scopes.length > 0, {
      message: t('admin.api_keys.validation.scope_required'),
      path: ['scopes'],
    })

type CreateFormValues = z.infer<ReturnType<typeof buildCreateSchema>>

// Create UX is a side Sheet (not a Dialog) because the scope grid makes the
// form taller than most viewports — Sheet handles overflow with internal
// scroll and avoids the centered-modal "content cut off" problem.
export function CreateApiKeyDialog({
  open,
  onOpenChange,
  onCreated,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  onCreated: (key: ApiKey) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateApiKey()

  const form = useForm<CreateFormValues>({
    resolver: zodResolver(buildCreateSchema(t)),
    defaultValues: { name: '', key_type: 'secret', scopes: [], channel_id: '' },
  })

  const keyType = form.watch('key_type')

  async function onSubmit(values: CreateFormValues) {
    const isPublishable = values.key_type === 'publishable'
    const params: ApiKeyCreateParams = {
      name: values.name,
      key_type: values.key_type,
      scopes: isPublishable ? undefined : values.scopes,
      // Channel binding is publishable-only; omit for secret keys and for the
      // "All channels" default (empty string) so the key stays store-wide.
      channel_id: isPublishable && values.channel_id ? values.channel_id : undefined,
    }
    try {
      const key = await createMutation.mutateAsync(params)
      toastManager.add({ type: 'success', title: t('admin.messages.key_created') })
      form.reset({ name: '', key_type: 'secret', scopes: [], channel_id: '' })
      onCreated(key)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('admin.api_keys.errors.failed_to_create'),
      })
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset({ name: '', key_type: 'secret', scopes: [], channel_id: '' })
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.api_keys.create_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.api_keys.create_sheet_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          {/* `flex-1 overflow-y-auto` keeps the footer pinned while the body
              scrolls when the scope grid overflows. */}
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FormErrorBanner message={form.formState.errors.root?.message} />
            <ApiKeyNameField
              id="api-key-name"
              register={form.register}
              error={form.formState.errors.name}
            />

            <Field>
              <FieldLabel>{t('admin.fields.api_key.key_type.label')}</FieldLabel>
              <Controller
                name="key_type"
                control={form.control}
                render={({ field }) => (
                  <RadioGroup value={field.value} onValueChange={(value) => field.onChange(value)}>
                    <KeyTypeChoice
                      value="secret"
                      title={t('admin.api_keys.key_type.secret_title')}
                      description={t('admin.api_keys.key_type.secret_description')}
                    />
                    <KeyTypeChoice
                      value="publishable"
                      title={t('admin.api_keys.key_type.publishable_title')}
                      description={t('admin.api_keys.key_type.publishable_description')}
                    />
                  </RadioGroup>
                )}
              />
            </Field>

            {keyType === 'publishable' && (
              <Field>
                <FieldLabel htmlFor="api-key-channel">
                  {t('admin.fields.api_key.channel.label')}
                </FieldLabel>
                <Controller
                  name="channel_id"
                  control={form.control}
                  render={({ field }) => (
                    <ChannelBindingSelect
                      id="api-key-channel"
                      value={field.value}
                      onChange={field.onChange}
                    />
                  )}
                />
                <p className="text-xs text-muted-foreground">
                  {t('admin.fields.api_key.channel.help')}
                </p>
              </Field>
            )}

            {keyType === 'secret' && (
              <Field>
                <FieldLabel>{t('admin.fields.api_key.scopes.label')}</FieldLabel>
                <Controller
                  name="scopes"
                  control={form.control}
                  render={({ field }) => (
                    <ScopePicker value={field.value} onChange={field.onChange} />
                  )}
                />
                {form.formState.errors.scopes && (
                  <p className="text-sm text-destructive">{form.formState.errors.scopes.message}</p>
                )}
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
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.api_keys.create_key_cta')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
