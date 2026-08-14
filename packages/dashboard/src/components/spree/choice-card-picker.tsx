import {
  Field,
  FieldContent,
  FieldDescription,
  FieldGroup,
  FieldLabel,
  FieldTitle,
  RadioGroup,
  RadioGroupItem,
} from '@spree/dashboard-ui'

export interface ChoiceCardOption<TValue extends string> {
  value: TValue
  label: string
  description: string
}

/**
 * Radio group rendered as labelled cards, one per option, each with a
 * description. Use it where the choices need explaining rather than just
 * naming — a plain select hides the descriptions behind a click.
 */
export function ChoiceCardPicker<TValue extends string>({
  label,
  help,
  options,
  value,
  onChange,
}: {
  label?: string
  /** Explains the field as a whole, above the options. */
  help?: string
  options: readonly ChoiceCardOption<TValue>[]
  value: TValue
  onChange: (value: TValue) => void
}) {
  return (
    <FieldGroup>
      {label ? <FieldLabel>{label}</FieldLabel> : null}
      {help ? <span className="text-xs text-muted-foreground">{help}</span> : null}
      <RadioGroup value={value} onValueChange={(next) => onChange(next as TValue)}>
        {options.map((option) => (
          <FieldLabel key={option.value}>
            <Field orientation="horizontal">
              <FieldContent>
                <FieldTitle>{option.label}</FieldTitle>
                <FieldDescription>{option.description}</FieldDescription>
              </FieldContent>
              <RadioGroupItem value={option.value} />
            </Field>
          </FieldLabel>
        ))}
      </RadioGroup>
    </FieldGroup>
  )
}
