import { FieldGroup, FieldLabel } from '@/components/ui/field'
import { cn } from '@/lib/utils'

export interface MatchPolicyOption<TValue extends string> {
  value: TValue
  label: string
  description: string
}

/**
 * Card-style toggle group used by promotion rules with a `match_policy`
 * preference (Product → any/all/none, Taxon → any/all). Each option
 * is a labelled card with a description; visually emphasises the
 * selected one with a primary border + tinted background.
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
      <div className="grid gap-2">
        {policies.map((policy) => {
          const active = value === policy.value
          return (
            <button
              key={policy.value}
              type="button"
              onClick={() => onChange(policy.value)}
              className={cn(
                'flex flex-col items-start gap-0.5 rounded-lg border p-3 text-left transition-colors',
                active
                  ? 'border-blue-300 bg-blue-50 dark:border-blue-500/60 dark:bg-blue-500/10'
                  : 'hover:bg-muted',
              )}
              aria-pressed={active}
            >
              <span className="text-sm font-medium">{policy.label}</span>
              <span className="text-xs text-muted-foreground">{policy.description}</span>
            </button>
          )
        })}
      </div>
    </FieldGroup>
  )
}
