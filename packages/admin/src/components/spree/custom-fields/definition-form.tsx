import { zodResolver } from '@hookform/resolvers/zod'
import { Loader2Icon } from 'lucide-react'
import type { ReactNode } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { Button } from '@/components/ui/button'
import { Field, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { useCreateCustomFieldDefinition } from '@/hooks/use-custom-fields'
import { mapSpreeErrorsToForm } from '@/lib/form-errors'
import { i18n } from '@/lib/i18n'
import { requiredMessage } from '@/lib/validation-messages'

// Labels live in `en.json` under
// `admin.fields.custom_field_definition.field_type.options.*` — consumers
// translate at render time.
const FIELD_TYPES = ['short_text', 'long_text', 'rich_text', 'number', 'boolean', 'json'] as const

const definitionSchema = z.object({
  label: z.string().min(1, { error: requiredMessage('custom_field_definition.label') }),
  namespace: z.string().min(1, { error: requiredMessage('custom_field_definition.namespace') }),
  key: z
    .string()
    .min(1, { error: requiredMessage('custom_field_definition.key') })
    .regex(/^[a-z0-9_]+$/i, {
      error: () => i18n.t('admin.fields.custom_field_definition.key.invalid_format'),
    }),
  field_type: z.enum(FIELD_TYPES),
  storefront_visible: z.boolean(),
})

export type DefinitionFormValues = z.infer<typeof definitionSchema>

interface DefinitionFormProps {
  resourceType: string
  /** Default namespace; "custom" mirrors Shopify/Saleor convention. */
  defaultNamespace?: string
  onSuccess: (definitionId: string) => void
  /**
   * Render-prop that builds the surrounding chrome (header/footer/etc) AROUND
   * the form fields and the submit button. The submit button must stay inside
   * the same `<form>` as the inputs, so the consumer composes layout, not the
   * form element itself.
   */
  renderShell: (parts: { fields: ReactNode; submitButton: ReactNode }) => ReactNode
}

export function DefinitionForm({
  resourceType,
  defaultNamespace = 'custom',
  onSuccess,
  renderShell,
}: DefinitionFormProps) {
  const { t } = useTranslation()
  const create = useCreateCustomFieldDefinition(resourceType)

  const form = useForm<DefinitionFormValues>({
    resolver: zodResolver(definitionSchema),
    defaultValues: {
      label: '',
      namespace: defaultNamespace,
      key: '',
      field_type: 'short_text',
      storefront_visible: false,
    },
  })
  const { errors } = form.formState

  const onSubmit = async (values: DefinitionFormValues) => {
    try {
      const result = await create.mutateAsync({ ...values, resource_type: resourceType })
      onSuccess(result.id)
    } catch (err) {
      // 422s map to inline field errors; anything else (network, 5xx) lands
      // on the form-level `root` so the user gets feedback inside the sheet.
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        form.setError('root', {
          type: 'server',
          message: err instanceof Error ? err.message : t('admin.errors.unexpected'),
        })
      }
    }
  }

  const fields = (
    <div className="flex flex-col gap-4">
      {errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {errors.root.message}
        </p>
      )}
      <Field>
        <FieldLabel htmlFor="cfd-label">
          {t('admin.fields.custom_field_definition.label.label')}
        </FieldLabel>
        <Input
          id="cfd-label"
          placeholder={t('admin.fields.custom_field_definition.label.placeholder')}
          aria-invalid={!!errors.label || undefined}
          {...form.register('label')}
        />
        {errors.label && <p className="text-sm text-destructive">{errors.label.message}</p>}
      </Field>
      <div className="grid grid-cols-3 gap-3">
        <Field className="col-span-1">
          <FieldLabel htmlFor="cfd-namespace">
            {t('admin.fields.custom_field_definition.namespace.label')}
          </FieldLabel>
          <Input
            id="cfd-namespace"
            placeholder={t('admin.fields.custom_field_definition.namespace.placeholder')}
            aria-invalid={!!errors.namespace || undefined}
            {...form.register('namespace')}
          />
          {errors.namespace && (
            <p className="text-sm text-destructive">{errors.namespace.message}</p>
          )}
        </Field>
        <Field className="col-span-2">
          <FieldLabel htmlFor="cfd-key">
            {t('admin.fields.custom_field_definition.key.label')}
          </FieldLabel>
          <Input
            id="cfd-key"
            placeholder={t('admin.fields.custom_field_definition.key.placeholder')}
            aria-invalid={!!errors.key || undefined}
            {...form.register('key')}
          />
          {errors.key && <p className="text-sm text-destructive">{errors.key.message}</p>}
        </Field>
      </div>
      <Field>
        <FieldLabel htmlFor="cfd-field-type">
          {t('admin.fields.custom_field_definition.field_type.label')}
        </FieldLabel>
        <Controller
          name="field_type"
          control={form.control}
          render={({ field }) => {
            const items = FIELD_TYPES.map((value) => ({
              value,
              label: t(`admin.fields.custom_field_definition.field_type.options.${value}`),
            }))
            return (
              <Select items={items} value={field.value} onValueChange={field.onChange}>
                <SelectTrigger id="cfd-field-type" aria-invalid={!!errors.field_type || undefined}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {items.map((o) => (
                    <SelectItem key={o.value} value={o.value}>
                      {o.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )
          }}
        />
      </Field>
      <Field>
        <div className="flex items-start justify-between gap-4">
          <FieldLabel htmlFor="cfd-storefront-visible" className="cursor-pointer">
            {t('admin.fields.custom_field_definition.storefront_visible.label')}
          </FieldLabel>
          <Controller
            name="storefront_visible"
            control={form.control}
            render={({ field }) => (
              <Switch
                id="cfd-storefront-visible"
                checked={!!field.value}
                onCheckedChange={field.onChange}
              />
            )}
          />
        </div>
      </Field>
    </div>
  )

  const submitButton = (
    <Button type="submit" size="sm" disabled={create.isPending}>
      {create.isPending && <Loader2Icon className="size-4 animate-spin" />}
      Create definition
    </Button>
  )

  return (
    <form
      onSubmit={form.handleSubmit(onSubmit)}
      className="flex h-full flex-col"
      // The drawer is portaled out of the DOM but React bubbles synthetic
      // events through the React tree, so without this guard the outer
      // product form's onSubmit also fires. Hard-stop here.
      onSubmitCapture={(e) => e.stopPropagation()}
    >
      {renderShell({ fields, submitButton })}
    </form>
  )
}
