import {
  cn,
  Field,
  FieldContent,
  FieldError,
  FieldGroup,
  FieldLabel,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
} from '@spree/dashboard-ui'
import type { ComponentProps, ReactNode } from 'react'
import { type Control, Controller, type FieldPath, type FieldValues } from 'react-hook-form'

/**
 * A settings card's rows, with a rule between each. Rows put the label on the
 * left and the control on the right once the card is wide enough, and stack
 * on a narrow screen.
 */
export function SettingsFieldGroup({ className, ...props }: ComponentProps<typeof FieldGroup>) {
  return (
    <FieldGroup
      className={cn(
        'gap-0 divide-y divide-border-subtle *:py-4 *:first:pt-0 *:last:pb-0',
        className,
      )}
      {...props}
    />
  )
}

/**
 * One setting: its label and help on the left, its control on the right.
 * `horizontal` keeps it a row at any width, for a narrow column whose
 * controls are short anyway.
 */
export function SettingsRow({
  label,
  htmlFor,
  help,
  error,
  orientation = 'responsive',
  children,
}: {
  label: ReactNode
  htmlFor?: string
  help?: ReactNode
  error?: { message?: string }
  orientation?: 'responsive' | 'horizontal'
  children: ReactNode
}) {
  const horizontal = orientation === 'horizontal'
  return (
    // Centred against the control, which the field would otherwise top-align
    // beside a label and its help.
    <Field
      orientation={orientation}
      className={
        horizontal
          ? 'gap-4 has-[>[data-slot=field-content]]:items-center'
          : '@md/field-group:gap-6 @md/field-group:has-[>[data-slot=field-content]]:items-center'
      }
    >
      <FieldContent>
        <FieldLabel htmlFor={htmlFor}>{label}</FieldLabel>
        {help && <span className="text-xs text-muted-foreground">{help}</span>}
        <FieldError errors={[error]} />
      </FieldContent>
      <div
        className={cn(
          'flex min-w-0 shrink-0 items-center gap-2',
          horizontal ? 'max-w-[60%]' : '@md/field-group:max-w-[50%]',
        )}
      >
        {children}
      </div>
    </Field>
  )
}

interface SelectFieldProps<TValues extends FieldValues> {
  id: string
  label: string
  placeholder?: string
  help?: string
  name: FieldPath<TValues>
  control: Control<TValues>
  options: ReadonlyArray<{ value: string; label: string }>
}

export function SettingsSelectField<TValues extends FieldValues>({
  id,
  label,
  placeholder,
  help,
  name,
  control,
  options,
}: SelectFieldProps<TValues>) {
  return (
    <Controller
      name={name}
      control={control}
      render={({ field, fieldState }) => (
        <SettingsRow label={label} htmlFor={id} help={help} error={fieldState.error}>
          <Select items={options as never} value={field.value} onValueChange={field.onChange}>
            {/* As wide as its value in a row, rather than half the card. */}
            <SelectTrigger
              id={id}
              aria-invalid={!!fieldState.error || undefined}
              className="@md/field-group:w-auto @md/field-group:min-w-40"
            >
              <SelectValue placeholder={placeholder} />
            </SelectTrigger>
            <SelectContent>
              {options.map((o) => (
                <SelectItem key={o.value} value={o.value}>
                  {o.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </SettingsRow>
      )}
    />
  )
}

interface SwitchFieldProps<TValues extends FieldValues> {
  id: string
  label: string
  help?: string
  name: FieldPath<TValues>
  control: Control<TValues>
}

export function SettingsSwitchField<TValues extends FieldValues>({
  id,
  label,
  help,
  name,
  control,
}: SwitchFieldProps<TValues>) {
  return (
    // A switch sits beside its label at every width.
    <Field orientation="horizontal" className="gap-4 has-[>[data-slot=field-content]]:items-center">
      <FieldContent>
        <FieldLabel htmlFor={id} className="cursor-pointer">
          {label}
        </FieldLabel>
        {help && <span className="text-xs text-muted-foreground">{help}</span>}
      </FieldContent>
      <Controller
        name={name}
        control={control}
        render={({ field }) => (
          <Switch id={id} checked={!!field.value} onCheckedChange={field.onChange} />
        )}
      />
    </Field>
  )
}
