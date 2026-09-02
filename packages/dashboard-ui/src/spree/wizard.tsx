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
import { useConfirm } from './confirm-dialog'
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
    <ol className={cn('flex flex-col', className)}>
      {steps.map((step, index) => {
        const state = index < currentIndex ? 'done' : index === currentIndex ? 'current' : 'ahead'
        const navigable = state === 'done' && !!onStepSelect
        const last = index === steps.length - 1

        return (
          <li key={step.key} className="flex gap-3">
            {/* Marker and connector share a column so the line always meets
                the dots, whatever a label wraps to. */}
            <div className="flex flex-col items-center">
              <span
                aria-hidden
                className={cn(
                  'flex size-4 shrink-0 items-center justify-center rounded-full border-2 transition-colors',
                  state === 'done' && 'border-success bg-success text-white',
                  state === 'current' && 'border-ring bg-background',
                  state === 'ahead' && 'border-border bg-background',
                )}
              >
                {state === 'done' ? <CheckIcon className="size-2.5" strokeWidth={3} /> : null}
              </span>
              {last ? null : <span aria-hidden className="w-px flex-auto bg-border" />}
            </div>
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
                'min-w-0 pb-7 text-left text-sm leading-none',
                navigable && 'cursor-pointer hover:text-foreground',
                state === 'current' ? 'font-medium text-foreground' : 'text-muted-foreground',
                last && 'pb-0',
              )}
            >
              <span className="truncate">{step.label}</span>
            </button>
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
  subtitle,
  status,
  steps,
  current,
  onStepSelect,
  onSubmit,
  onKeyDown,
  contentClassName,
  children,
  back,
  forward,
  hasUnsavedChanges = false,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  /** Shown after the title behind a divider — what this run is about. */
  subtitle?: ReactNode
  /** Right-aligned ambient status, e.g. a save state or a badge. */
  status?: ReactNode
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
  /**
   * Whether closing now would discard the merchant's work. The host decides,
   * since only it knows what its steps have collected.
   */
  hasUnsavedChanges?: boolean
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()

  async function requestClose() {
    if (hasUnsavedChanges) {
      const discard = await confirm({
        title: t('admin.components.wizard.discard_title'),
        message: t('admin.components.wizard.discard_message'),
        confirmLabel: t('admin.components.wizard.discard_confirm'),
        cancelLabel: t('admin.components.wizard.discard_cancel'),
        variant: 'destructive',
      })
      if (!discard) return
    }
    onOpenChange(false)
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next, details) => {
        if (next) return onOpenChange(true)
        // A wizard holds several steps of work, so a stray Escape or a click
        // past its edge must not throw that away without asking.
        if (details?.reason === 'escape-key' || details?.reason === 'outside-press') {
          void requestClose()
          return
        }
        onOpenChange(false)
      }}
      modal
    >
      <DialogContent
        // Edge-to-edge minus a gutter, like the import wizard and the bulk
        // price editor — every inset/translate/max is overridden.
        className="!inset-3 !w-auto !max-w-none !translate-x-0 !translate-y-0 flex flex-col p-0"
        style={{ maxHeight: 'none' }}
        showCloseButton={false}
      >
        <DialogHeader className="h-14 shrink-0 flex-row items-center gap-3 space-y-0 border-b border-border-subtle bg-background px-4 py-0">
          <div className="flex min-w-0 items-center gap-3">
            <DialogTitle className="truncate text-base">{title}</DialogTitle>
            {subtitle ? (
              <>
                <span aria-hidden className="h-4 w-px shrink-0 bg-border" />
                <span className="truncate text-muted-foreground text-sm">{subtitle}</span>
              </>
            ) : null}
          </div>
          <div className="ms-auto flex shrink-0 items-center gap-3">
            {status}
            <Button
              type="button"
              size="icon-sm"
              variant="ghost"
              onClick={() => void requestClose()}
              aria-label={t('admin.actions.close')}
            >
              <XIcon />
            </Button>
          </div>
        </DialogHeader>

        <form onSubmit={onSubmit} onKeyDown={onKeyDown} className="flex min-h-0 flex-1 flex-col">
          {/* The body itself does not scroll: the rail stays put while the
              step's own column scrolls, so a long form never carries the
              progress list off-screen. */}
          <DialogBody className="flex min-h-0 flex-1 gap-8 overflow-hidden p-0">
            <WizardProgress
              steps={steps}
              current={current}
              onStepSelect={onStepSelect}
              className="hidden w-56 shrink-0 py-8 ps-8 md:flex"
            />
            <div className="min-w-0 flex-1 overflow-y-auto py-8 pe-8 ps-8 md:ps-0">
              {/* No width cap here: `contentClassName` is what sets it, and a
                  default with a breakpoint would outrank the caller's own. */}
              <div className={cn('flex w-full min-w-0 flex-col gap-6', contentClassName)}>
                {children}
              </div>
            </div>
          </DialogBody>

          {/* Back sits opposite the forward action rather than beside it, so
              the footer's end-justification is overridden. It stays a row at
              every width too: stacked, Back would sit above Next and read as
              the order to press them in. */}
          <DialogFooter className="h-16 shrink-0 flex-row items-center justify-between border-border-subtle bg-background px-4 py-0 sm:justify-between">
            {back}
            {forward}
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
