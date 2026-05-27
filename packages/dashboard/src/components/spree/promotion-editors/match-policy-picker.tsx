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

export interface MatchPolicyOption<TValue extends string> {
  value: TValue
  label: string
  description: string
}

/**
 * Card-style toggle group used by promotion rules with a `match_policy`
 * preference (Product → any/all/none, Taxon → any/all). Each option is
 * a labelled card with a description; the selected one tints via the
 * shared `FieldLabel` choice-card styling.
 */
export function MatchPolicyPicker<TValue extends string>({
  label = 'Match policy',
  policies,
  value,
  onChange,
}: {
  label?: string
  policies: readonly MatchPolicyOption<TValue>[]
  value: TValue
  onChange: (value: TValue) => void
}) {
  return (
    <FieldGroup>
      <FieldLabel>{label}</FieldLabel>
      <RadioGroup value={value} onValueChange={(next) => onChange(next as TValue)}>
        {policies.map((policy) => (
          <FieldLabel key={policy.value}>
            <Field orientation="horizontal">
              <FieldContent>
                <FieldTitle>{policy.label}</FieldTitle>
                <FieldDescription>{policy.description}</FieldDescription>
              </FieldContent>
              <RadioGroupItem value={policy.value} />
            </Field>
          </FieldLabel>
        ))}
      </RadioGroup>
    </FieldGroup>
  )
}
