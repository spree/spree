import {
  Field,
  FieldError,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
} from '@spree/dashboard-ui'
import { Controller, type UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  type CustomFieldDefinitionFormValues,
  DEFAULT_RESOURCE_TYPES,
  FIELD_TYPES,
  fieldTypeLabel,
  fieldTypeSupportsSearchable,
  fieldTypeSupportsSortable,
  resourceTypeLabel,
} from '../../../schemas/custom-field-definition'

interface DefinitionFormFieldsProps {
  form: UseFormReturn<CustomFieldDefinitionFormValues>
  /**
   * When true, the `resource_type` picker is rendered. Off by default — the
   * inline create sheet (`CreateDefinitionSheet`) creates definitions for a
   * known owner and pre-fills/hides the resource, but the settings page (where
   * the user picks from a list) opts in.
   */
  showResourceType?: boolean
  /**
   * Disable the `resource_type` picker. Used in edit mode where changing the
   * owner would orphan stored values.
   */
  resourceTypeReadOnly?: boolean
  /**
   * Disable the `field_type` picker. Used in edit mode — flipping the type
   * after values have been stored would leave them misinterpreted by the UI.
   */
  fieldTypeReadOnly?: boolean
}

/**
 * Pure form fields for a custom field definition. The caller supplies the
 * `<form>` element and submit handler — this just renders the controls.
 *
 * Used by:
 *   - `CreateDefinitionSheet` in custom-fields-inline.tsx (the inline card's
 *     empty-state create flow; resource type pre-set and hidden).
 *   - The Settings → Custom field definitions page (create + edit sheets).
 */
export function DefinitionFormFields({
  form,
  showResourceType = false,
  resourceTypeReadOnly = false,
  fieldTypeReadOnly = false,
}: DefinitionFormFieldsProps) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const fieldType = form.watch('field_type')
  const searchableSupported = fieldTypeSupportsSearchable(fieldType)
  const sortableSupported = fieldTypeSupportsSortable(fieldType)

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
            <Select
              items={fieldTypeItems}
              value={field.value}
              onValueChange={(value) => {
                field.onChange(value)
                const next = String(value)
                if (!fieldTypeSupportsSearchable(next)) {
                  form.setValue('searchable', false)
                }
                if (!fieldTypeSupportsSortable(next)) {
                  form.setValue('sortable', false)
                }
                form.clearErrors(['searchable', 'sortable'])
              }}
              disabled={fieldTypeReadOnly}
            >
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
        {fieldTypeReadOnly && (
          <span className="text-xs text-muted-foreground">
            {t('admin.fields.custom_field_definition.field_type.read_only_help')}
          </span>
        )}
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

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-1">
            <FieldLabel htmlFor="cfd-searchable" className="cursor-pointer">
              {t('admin.fields.custom_field_definition.searchable.label')}
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              {t('admin.fields.custom_field_definition.searchable.help')}
            </span>
          </div>
          <Controller
            name="searchable"
            control={form.control}
            render={({ field }) => (
              <Switch
                id="cfd-searchable"
                checked={!!field.value}
                onCheckedChange={field.onChange}
                disabled={!searchableSupported}
              />
            )}
          />
        </div>
        <FieldError errors={[errors.searchable]} />
      </Field>

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-1">
            <FieldLabel htmlFor="cfd-sortable" className="cursor-pointer">
              {t('admin.fields.custom_field_definition.sortable.label')}
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              {t('admin.fields.custom_field_definition.sortable.help')}
            </span>
          </div>
          <Controller
            name="sortable"
            control={form.control}
            render={({ field }) => (
              <Switch
                id="cfd-sortable"
                checked={!!field.value}
                onCheckedChange={field.onChange}
                disabled={!sortableSupported}
              />
            )}
          />
        </div>
        <FieldError errors={[errors.sortable]} />
      </Field>
    </div>
  )
}
