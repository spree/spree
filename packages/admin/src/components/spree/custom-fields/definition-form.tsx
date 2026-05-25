import { zodResolver } from '@hookform/resolvers/zod'
import { Loader2Icon } from 'lucide-react'
import type { ReactNode } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { Button } from '@/components/ui/button'
import { Field, FieldError, FieldLabel } from '@/components/ui/field'
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
import {
  CUSTOM_FIELD_DEFINITION_DEFAULTS,
  type CustomFieldDefinitionFormValues,
  customFieldDefinitionSchema,
  customFieldDefinitionValuesToCreateParams,
  DEFAULT_RESOURCE_TYPES,
  FIELD_TYPES,
  fieldTypeLabel,
  resourceTypeLabel,
} from '@/schemas/custom-field-definition'

// Re-export so existing callers (drawer) don't have to chase paths.
export type { CustomFieldDefinitionFormValues as DefinitionFormValues }

interface DefinitionFormFieldsProps {
  form: UseFormReturn<CustomFieldDefinitionFormValues>
  /**
   * When true, the `resource_type` picker is rendered. Off by default — the
   * drawer creates definitions for a known owner and pre-fills the resource,
   * but the settings page (where the user picks from a list) opts in.
   */
  showResourceType?: boolean
  /**
   * Disable the `resource_type` picker. Used in edit mode where changing the
   * owner would orphan stored values.
   */
  resourceTypeReadOnly?: boolean
}

/**
 * Pure form fields for a custom field definition. The caller supplies the
 * `<form>` element and submit handler — this just renders the controls.
 *
 * Used by:
 *   - `<DefinitionForm>` below (drawer's inline create flow, owner pre-set).
 *   - The Settings → Custom field definitions page (create + edit sheets).
 */
export function DefinitionFormFields({
  form,
  showResourceType = false,
  resourceTypeReadOnly = false,
}: DefinitionFormFieldsProps) {
  const { t } = useTranslation()
  const { errors } = form.formState

  const fieldTypeItems = FIELD_TYPES.map((value) => ({
    value,
    label: fieldTypeLabel(value),
  }))

  const resourceTypeItems = DEFAULT_RESOURCE_TYPES.map((value) => ({
    value,
    label: resourceTypeLabel(value),
  }))

  return (
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
          autoFocus
          placeholder={t('admin.fields.custom_field_definition.label.placeholder')}
          aria-invalid={!!errors.label || undefined}
          {...form.register('label')}
        />
        <FieldError errors={[errors.label]} />
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
          <FieldError errors={[errors.namespace]} />
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
          <FieldError errors={[errors.key]} />
        </Field>
      </div>

      {showResourceType && (
        <Field>
          <FieldLabel htmlFor="cfd-resource-type">
            {t('admin.fields.custom_field_definition.resource_type.label')}
          </FieldLabel>
          <Controller
            name="resource_type"
            control={form.control}
            render={({ field }) => (
              <Select
                items={resourceTypeItems}
                value={field.value}
                onValueChange={field.onChange}
                disabled={resourceTypeReadOnly}
              >
                <SelectTrigger
                  id="cfd-resource-type"
                  aria-invalid={!!errors.resource_type || undefined}
                >
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {resourceTypeItems.map((o) => (
                    <SelectItem key={o.value} value={o.value}>
                      {o.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
          {resourceTypeReadOnly && (
            <span className="text-xs text-muted-foreground">
              {t('admin.fields.custom_field_definition.resource_type.read_only_help')}
            </span>
          )}
          <FieldError errors={[errors.resource_type]} />
        </Field>
      )}

      <Field>
        <FieldLabel htmlFor="cfd-field-type">
          {t('admin.fields.custom_field_definition.field_type.label')}
        </FieldLabel>
        <Controller
          name="field_type"
          control={form.control}
          render={({ field }) => (
            <Select items={fieldTypeItems} value={field.value} onValueChange={field.onChange}>
              <SelectTrigger id="cfd-field-type" aria-invalid={!!errors.field_type || undefined}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {fieldTypeItems.map((o) => (
                  <SelectItem key={o.value} value={o.value}>
                    {o.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
        <FieldError errors={[errors.field_type]} />
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
}

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

/**
 * Drawer-style create form. Owns its own `useForm` + create mutation, and
 * pre-fills `resource_type` from the owning record (so the resource picker
 * is hidden — the drawer only ever creates fields for one specific owner).
 */
export function DefinitionForm({
  resourceType,
  defaultNamespace = 'custom',
  onSuccess,
  renderShell,
}: DefinitionFormProps) {
  const { t } = useTranslation()
  const create = useCreateCustomFieldDefinition(resourceType)

  const form = useForm<CustomFieldDefinitionFormValues>({
    resolver: zodResolver(customFieldDefinitionSchema),
    defaultValues: {
      ...CUSTOM_FIELD_DEFINITION_DEFAULTS,
      namespace: defaultNamespace,
      resource_type: resourceType,
    },
  })

  const onSubmit = async (values: CustomFieldDefinitionFormValues) => {
    try {
      const result = await create.mutateAsync(
        customFieldDefinitionValuesToCreateParams({ ...values, resource_type: resourceType }),
      )
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

  const submitButton = (
    <Button type="submit" size="sm" disabled={create.isPending}>
      {create.isPending && <Loader2Icon className="size-4 animate-spin" />}
      {t('admin.custom_field_definitions.create_label')}
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
      {renderShell({ fields: <DefinitionFormFields form={form} />, submitButton })}
    </form>
  )
}
