import type * as React from 'react'
import type { Control, FieldValues, Path } from 'react-hook-form'
import { Controller } from 'react-hook-form'
import { Card, CardContent, CardHeader, CardTitle } from '../../ui/card'
import { Field, FieldLabel } from '../../ui/field'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../ui/select'

export type StatusOption = { value: string; label: string }

/**
 * The product's status, chosen from whatever the caller allows.
 *
 * The options are a prop rather than a constant because the two dashboards
 * offer different ones: an operator publishes directly, while a seller submits
 * for review and can only take a listing back down. Headless, so the labels
 * arrive translated.
 */
export function StatusCard<TFieldValues extends FieldValues>({
  control,
  name,
  title,
  label,
  options,
  disabled,
  description,
  actions,
}: {
  control: Control<TFieldValues>
  name: Path<TFieldValues>
  title: string
  label: string
  options: StatusOption[]
  disabled?: boolean
  description?: string
  /**
   * Rendered under the field. The moves out of a status this picker cannot
   * assign live here — a review decision is a mutation, which the panel owns
   * rather than the design system.
   */
  actions?: React.ReactNode
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <Field>
          <FieldLabel>{label}</FieldLabel>
          <Controller
            name={name}
            control={control}
            render={({ field }) => (
              <Select
                items={options as never}
                value={field.value}
                onValueChange={field.onChange}
                disabled={disabled}
              >
                <SelectTrigger className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {options.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
          {description && <p className="text-muted-foreground text-sm">{description}</p>}
        </Field>
        {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
      </CardContent>
    </Card>
  )
}
