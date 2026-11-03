import { StoreDatePicker } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldDescription,
  FieldError,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectSeparator,
  SelectTrigger,
  SelectValue,
  Switch,
} from '@spree/dashboard-ui'
import { PlusIcon, Trash2Icon } from '@spree/dashboard-ui/icons'
import { Controller, type UseFormReturn, useFieldArray } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCustomFieldResourceTypes } from '../../../hooks/use-custom-field-resource-types'
import {
  type CustomFieldDefinitionFormValues,
  DEFAULT_RESOURCE_TYPES,
  FIELD_TYPES,
  fieldTypeBoundKind,
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
  const multipleChoices = fieldType === 'choice' && form.watch('validations.multiple')
  const searchableSupported = fieldTypeSupportsSearchable(fieldType)
  // Several stored values have no single sort position.
  const sortableSupported = fieldTypeSupportsSortable(fieldType) && !multipleChoices

  const fieldTypeItems = FIELD_TYPES.map((value) => ({
    value,
    label: fieldTypeLabel(value),
  }))

  // From the server's registry. `DEFAULT_RESOURCE_TYPES` covers the first
  // render while that request is in flight, so the select is never empty.
  const { data: resourceTypesResponse } = useCustomFieldResourceTypes()
  const resourceTypeItems = (
    resourceTypesResponse?.data ??
    DEFAULT_RESOURCE_TYPES.map((value) => ({ resource_type: value, name: undefined }))
  ).map(({ resource_type, name }) => ({
    value: resource_type,
    label: resourceTypeLabel(resource_type, name),
  }))
  // Types the dashboard edits come first; the rest are still definable for
  // integrations, but say so, since no screen here fills them in.
  const editableTypes = new Set<string>(DEFAULT_RESOURCE_TYPES)
  const byLabel = (a: { label: string }, b: { label: string }) => a.label.localeCompare(b.label)
  const editableTypeItems = resourceTypeItems
    .filter((item) => editableTypes.has(item.value))
    .sort(byLabel)
  const apiOnlyTypeItems = resourceTypeItems
    .filter((item) => !editableTypes.has(item.value))
    .sort(byLabel)

  return (
    <div className="flex flex-col gap-4">
      {errors.root?.message && (
        <p className="text-base text-destructive" role="alert">
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
                  <SelectGroup>
                    {editableTypeItems.map((o) => (
                      <SelectItem key={o.value} value={o.value}>
                        {o.label}
                      </SelectItem>
                    ))}
                  </SelectGroup>
                  {apiOnlyTypeItems.length > 0 && (
                    <>
                      <SelectSeparator />
                      <SelectGroup>
                        <SelectLabel>
                          {t('admin.fields.custom_field_definition.resource_type.api_only_group')}
                        </SelectLabel>
                        {apiOnlyTypeItems.map((o) => (
                          <SelectItem key={o.value} value={o.value}>
                            {o.label}
                          </SelectItem>
                        ))}
                      </SelectGroup>
                    </>
                  )}
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
                // A bound means something different for each type.
                form.setValue('validations.min', '')
                form.setValue('validations.max', '')
                form.clearErrors(['searchable', 'sortable', 'validations'])
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

      <ValidationRulesFields form={form} />
    </div>
  )
}

/** The `validations` rules, showing only those the chosen field type takes. */
function ValidationRulesFields({ form }: { form: UseFormReturn<CustomFieldDefinitionFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const fieldType = form.watch('field_type')
  const boundKind = fieldTypeBoundKind(fieldType)
  const choices = useFieldArray({ control: form.control, name: 'validations.choices' })
  const prefix = 'admin.fields.custom_field_definition.validations'

  return (
    <div className="flex flex-col gap-4 border-t pt-4">
      <div className="flex flex-col gap-1">
        <h3 className="text-sm font-medium">{t(`${prefix}.title`)}</h3>
        <FieldDescription>{t(`${prefix}.help`)}</FieldDescription>
      </div>
      {errors.validations?.message && (
        <p className="text-sm text-destructive" role="alert">
          {errors.validations.message}
        </p>
      )}

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col gap-1">
            <FieldLabel htmlFor="cfd-required" className="cursor-pointer">
              {t(`${prefix}.required.label`)}
            </FieldLabel>
            <span className="text-xs text-muted-foreground">{t(`${prefix}.required.help`)}</span>
          </div>
          <Controller
            name="validations.required"
            control={form.control}
            render={({ field }) => (
              <Switch id="cfd-required" checked={!!field.value} onCheckedChange={field.onChange} />
            )}
          />
        </div>
      </Field>

      {boundKind && (
        <div className="grid grid-cols-2 gap-3">
          {(['min', 'max'] as const).map((bound) => (
            <Field key={bound}>
              <FieldLabel htmlFor={`cfd-${bound}`}>
                {t(`${prefix}.${bound}.${boundKind}`)}
              </FieldLabel>
              {boundKind === 'date' || boundKind === 'date_time' ? (
                <Controller
                  name={`validations.${bound}`}
                  control={form.control}
                  render={({ field }) => (
                    <StoreDatePicker
                      id={`cfd-${bound}`}
                      inline
                      includeTime={boundKind === 'date_time'}
                      value={field.value || null}
                      onChange={(value) => field.onChange(value ?? '')}
                    />
                  )}
                />
              ) : (
                <Input
                  id={`cfd-${bound}`}
                  type="number"
                  min={boundKind === 'length' ? 0 : undefined}
                  step={boundKind === 'length' ? 1 : 'any'}
                  {...form.register(`validations.${bound}`)}
                />
              )}
            </Field>
          ))}
        </div>
      )}

      {fieldType === 'choice' && (
        <>
          <Field>
            <FieldLabel>{t(`${prefix}.choices.label`)}</FieldLabel>
            <div className="flex flex-col gap-2">
              {choices.fields.map((choice, index) => (
                <div key={choice.id} className="flex items-start gap-2">
                  <div className="flex flex-1 flex-col gap-1">
                    <Input
                      aria-label={t(`${prefix}.choices.value`)}
                      placeholder={t(`${prefix}.choices.value`)}
                      aria-invalid={!!errors.validations?.choices?.[index]?.value || undefined}
                      {...form.register(`validations.choices.${index}.value`)}
                    />
                    <FieldError errors={[errors.validations?.choices?.[index]?.value]} />
                  </div>
                  <Input
                    className="flex-1"
                    aria-label={t(`${prefix}.choices.choice_label`)}
                    placeholder={t(`${prefix}.choices.choice_label`)}
                    {...form.register(`validations.choices.${index}.label`)}
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon-sm"
                    aria-label={t(`${prefix}.choices.remove`)}
                    onClick={() => choices.remove(index)}
                  >
                    <Trash2Icon className="size-4" />
                  </Button>
                </div>
              ))}
              <div>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => choices.append({ value: '', label: '' })}
                >
                  <PlusIcon className="size-4" />
                  {t(`${prefix}.choices.add`)}
                </Button>
              </div>
            </div>
            <FieldError
              errors={[errors.validations?.choices?.root ?? errors.validations?.choices]}
            />
          </Field>

          <Field>
            <div className="flex items-start justify-between gap-4">
              <div className="flex flex-col gap-1">
                <FieldLabel htmlFor="cfd-multiple" className="cursor-pointer">
                  {t(`${prefix}.multiple.label`)}
                </FieldLabel>
                <span className="text-xs text-muted-foreground">
                  {t(`${prefix}.multiple.help`)}
                </span>
              </div>
              <Controller
                name="validations.multiple"
                control={form.control}
                render={({ field }) => (
                  <Switch
                    id="cfd-multiple"
                    checked={!!field.value}
                    onCheckedChange={(checked) => {
                      field.onChange(checked)
                      if (checked) form.setValue('sortable', false)
                    }}
                  />
                )}
              />
            </div>
          </Field>
        </>
      )}
    </div>
  )
}
