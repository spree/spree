import { Field, FieldGroup, FieldLabel, Input, Textarea } from '@spree/dashboard-ui'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import type { CustomerGroupFormValues } from '../../../schemas/customer-group'

/** A customer group's name and description, for its create sheet and its page. */
export function NameDescriptionFields({
  form,
  autoFocus = true,
}: {
  form: UseFormReturn<CustomerGroupFormValues>
  autoFocus?: boolean
}) {
  const { t } = useTranslation()
  const { errors } = form.formState
  return (
    <FieldGroup>
      {errors.root?.message && (
        <p className="text-base text-destructive" role="alert">
          {errors.root.message}
        </p>
      )}
      <Field>
        <FieldLabel htmlFor="name">{t('admin.fields.name.label')}</FieldLabel>
        <Input
          id="name"
          autoFocus={autoFocus}
          placeholder={t('admin.fields.customer_group.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        {errors.name && <p className="text-base text-destructive">{errors.name.message}</p>}
      </Field>

      <Field>
        <FieldLabel htmlFor="description">{t('admin.fields.description.label')}</FieldLabel>
        <Textarea
          id="description"
          rows={3}
          placeholder={t('admin.fields.customer_group.description.placeholder')}
          aria-invalid={!!errors.description || undefined}
          {...form.register('description')}
        />
        {errors.description && (
          <p className="text-base text-destructive">{errors.description.message}</p>
        )}
      </Field>
    </FieldGroup>
  )
}
