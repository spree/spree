import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { cn } from '../lib/utils'
import { Button } from '../ui/button'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '../ui/dialog'
import { CheckIcon, XIcon } from './icons'

/** One step in a wizard: what it is called, and how far in it sits. */
export interface WizardStep {
  /** Stable key, used for React identity and by the host to switch panes. */
  key: string
  label: string
}

export interface WizardProgressProps {
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
export function WizardProgress({ steps, current, onStepSelect, className }: WizardProgressProps) {
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

/**
 * The chrome a multi-step flow sits in: a full-window dialog with a title, a
 * progress rail, a scrolling body and a footer that moves between steps.
 *
 * Deliberately a shell. Which step is open, what each one contains and
 * whether the flow may advance are the host's, because per-step validation
 * differs enough between flows that a shared guard would fit the first caller
 * and fight the second. What is shared is the shape — and the fact that a
 * wizard goes *deeper into* the page behind it rather than navigating away,
 * so that page keeps its state and closing returns to it.
 *
 * The body is a plain `<form>`: a wizard collects input, and the last step's
 * action is a submit, so browser semantics (Enter, validation, submit events)
 * work rather than being reimplemented.
 */
export function Wizard({
  open,
  onOpenChange,
  title,
  steps,
  current,
  onStepSelect,
  onSubmit,
  onKeyDown,
  contentClassName,
  children,
  back,
  forward,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  steps: WizardStep[]
  current: string
  onStepSelect?: (key: string) => void
  onSubmit: React.FormEventHandler<HTMLFormElement>
  onKeyDown?: React.KeyboardEventHandler<HTMLFormElement>
  /** Widths differ by step — a two-column step wants room a form does not. */
  contentClassName?: string
  children: ReactNode
  /** Rendered at the footer's leading edge, opposite the forward action. */
  back: ReactNode
  /** Next, or the submit on the last step. */
  forward: ReactNode
}) {
  const { t } = useTranslation()

  return (
    <Dialog open={open} onOpenChange={onOpenChange} modal>
      <DialogContent
        // Edge-to-edge minus a gutter, like the import wizard and the bulk
        // price editor — every inset/translate/max is overridden.
        className="!inset-3 !w-auto !max-w-none !translate-x-0 !translate-y-0 flex flex-col p-0"
        style={{ maxHeight: 'none' }}
        showCloseButton={false}
      >
        <DialogHeader className="flex flex-row items-center justify-between gap-3 space-y-0 border-b p-3">
          <DialogTitle>{title}</DialogTitle>
          <Button
            type="button"
            size="icon-sm"
            variant="ghost"
            onClick={() => onOpenChange(false)}
            aria-label={t('admin.actions.close')}
          >
            <XIcon />
          </Button>
        </DialogHeader>

        <form onSubmit={onSubmit} onKeyDown={onKeyDown} className="flex min-h-0 flex-1 flex-col">
          <div className="border-b border-border-subtle px-6 py-4">
            <WizardProgress steps={steps} current={current} onStepSelect={onStepSelect} />
          </div>

          <DialogBody className="flex-1 overflow-y-auto p-6">
            <div className={cn('mx-auto flex w-full flex-col gap-6', contentClassName)}>
              {children}
            </div>
          </DialogBody>

          {/* Back sits opposite the forward action rather than beside it, so
              the footer's end-justification is overridden. It stays a row at
              every width too: stacked, Back would sit above Next and read as
              the order to press them in. */}
          <DialogFooter className="flex-row justify-between sm:justify-between">
            {back}
            {forward}
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
