import { useTranslation } from 'react-i18next'
import { type ChoiceCardOption, ChoiceCardPicker } from '../choice-card-picker'

export type MatchPolicyOption<TValue extends string> = ChoiceCardOption<TValue>

/**
 * Card-style toggle group used by promotion rules with a `match_policy`
 * preference (Product → any/all/none, Taxon → any/all).
 */
export function MatchPolicyPicker<TValue extends string>({
  label,
  policies,
  value,
  onChange,
}: {
  label?: string
  policies: readonly MatchPolicyOption<TValue>[]
  value: TValue
  onChange: (value: TValue) => void
}) {
  const { t } = useTranslation()
  return (
    <ChoiceCardPicker
      label={label ?? t('admin.fields.match_policy.label')}
      options={policies}
      value={value}
      onChange={onChange}
    />
  )
}
