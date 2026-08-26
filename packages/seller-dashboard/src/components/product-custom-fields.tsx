import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldGroup,
  FieldLabel,
  Input,
  Switch,
  Textarea,
} from '@spree/dashboard-ui'
import type { ProductTypeCustomFieldDefinition } from '@spree/seller-sdk'
import type { Control, FieldValues, Path, UseFormRegister } from 'react-hook-form'
import { Controller } from 'react-hook-form'
import { useTranslation } from 'react-i18next'

/**
 * The fields a product type asks a seller to fill in.
 *
 * Values only. Which fields exist is the operator's to define, so there is no
 * affordance here to add one — a seller answers the questions rather than
 * setting them.
 */
export function ProductCustomFields<TFieldValues extends FieldValues>({
  definitions,
  register,
  control,
}: {
  definitions: ProductTypeCustomFieldDefinition[]
  // Generic over the caller's form rather than `any`: react-hook-form's
  // Control is invariant, so a loose type here does not accept a precise one.
  register: UseFormRegister<TFieldValues>
  control: Control<TFieldValues>
}) {
  const { t } = useTranslation()

  if (definitions.length === 0) return null

  const sorted = [...definitions].sort((a, b) => a.sort_order - b.sort_order)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('products.custom_fields')}</CardTitle>
      </CardHeader>
      <CardContent>
        <FieldGroup>
          {sorted.map((definition) => {
            const name = `custom_fields.${definition.key}` as Path<TFieldValues>

            return (
              <Field key={definition.id}>
                <FieldLabel htmlFor={name}>{definition.label}</FieldLabel>

                {definition.field_type === 'long_text' || definition.field_type === 'rich_text' ? (
                  <Textarea id={name} rows={4} {...register(name)} />
                ) : definition.field_type === 'boolean' ? (
                  <Controller
                    name={name}
                    control={control}
                    render={({ field }) => (
                      <Switch id={name} checked={!!field.value} onCheckedChange={field.onChange} />
                    )}
                  />
                ) : (
                  <Input
                    id={name}
                    inputMode={definition.field_type === 'number' ? 'decimal' : undefined}
                    {...register(name)}
                  />
                )}
              </Field>
            )
          })}
        </FieldGroup>
      </CardContent>
    </Card>
  )
}
