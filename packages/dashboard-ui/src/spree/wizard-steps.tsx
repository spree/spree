import { CheckIcon } from 'lucide-react'
import { cn } from '../lib/utils'

/** One step in a wizard: what it is called, and how far in it sits. */
export interface WizardStep {
  /** Stable key, used for React identity and by the host to switch panes. */
  key: string
  label: string
}

export interface WizardStepsProps {
  steps: WizardStep[]
  /** Key of the step being shown. */
  current: string
  /**
   * Jump straight to an earlier step. Omit for a strictly linear wizard —
   * a step ahead is never reachable this way, since it may depend on
   * answers the merchant has not given yet.
   */
  onStepSelect?: (key: string) => void
  className?: string
}

/**
 * The progress rail above a multi-step flow: which steps there are, which one
 * is open, and which are behind.
 *
 * Headless — it renders no panes and holds no state. The host owns which step
 * is current and what each one contains, so the same rail serves flows whose
 * steps are validated differently.
 *
 * Steps already completed are clickable when `onStepSelect` is given, so
 * going back to correct an earlier answer is one click rather than a walk
 * backwards. Steps ahead never are: a linear flow only knows a step is
 * reachable once the one before it is answered.
 */
export function WizardSteps({ steps, current, onStepSelect, className }: WizardStepsProps) {
  const currentIndex = steps.findIndex((step) => step.key === current)

  return (
    <ol className={cn('flex items-center gap-2', className)}>
      {steps.map((step, index) => {
        const state = index < currentIndex ? 'done' : index === currentIndex ? 'current' : 'ahead'
        const navigable = state === 'done' && !!onStepSelect

        return (
          <li key={step.key} className="flex flex-1 items-center gap-2">
            <button
              type="button"
              disabled={!navigable}
              onClick={navigable ? () => onStepSelect(step.key) : undefined}
              // The rail is a summary of a flow the host drives, so a step
              // that cannot be jumped to is not a disabled control the
              // keyboard should stop on.
              tabIndex={navigable ? undefined : -1}
              aria-current={state === 'current' ? 'step' : undefined}
              className={cn(
                'flex min-w-0 flex-1 items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm',
                navigable && 'cursor-pointer hover:bg-muted',
                state === 'ahead' && 'text-muted-foreground',
              )}
            >
              <span
                aria-hidden
                className={cn(
                  'flex size-6 shrink-0 items-center justify-center rounded-full border text-xs',
                  state === 'current' && 'border-primary bg-primary text-primary-foreground',
                  state === 'done' && 'border-primary text-primary',
                  state === 'ahead' && 'border-border text-muted-foreground',
                )}
              >
                {state === 'done' ? <CheckIcon className="size-3.5" /> : index + 1}
              </span>
              <span className={cn('truncate', state === 'current' && 'font-medium')}>
                {step.label}
              </span>
            </button>
            {index < steps.length - 1 && (
              <span aria-hidden className="h-px flex-1 bg-border last:hidden" />
            )}
          </li>
        )
      })}
    </ol>
  )
}
