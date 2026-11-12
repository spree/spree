import { cn } from '../lib/utils'

const R = 6.5
const CIRCUMFERENCE = 2 * Math.PI * R

/** Progress through a checklist as a ring that fills green. */
export function StepProgressRing({
  value,
  max,
  className,
}: {
  value: number
  max: number
  className?: string
}) {
  return (
    <svg viewBox="0 0 16 16" className={cn('size-4 shrink-0 -rotate-90', className)} aria-hidden>
      <circle cx="8" cy="8" r={R} fill="none" strokeWidth="1.5" className="stroke-border" />
      <circle
        cx="8"
        cy="8"
        r={R}
        fill="none"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeDasharray={CIRCUMFERENCE}
        strokeDashoffset={CIRCUMFERENCE * (1 - value / (max || 1))}
        className="stroke-success"
      />
    </svg>
  )
}

export type StepStatus = 'done' | 'in_progress' | 'todo'

/**
 * A checklist step's state: a green check once done, a dashed blue ring while
 * it is started but waiting on someone else (such as a review), and a plain
 * ring before it is started.
 */
export function StepIcon({ status, className }: { status: StepStatus; className?: string }) {
  const classes = cn('size-4 shrink-0', className)

  if (status === 'done') {
    return (
      <svg viewBox="0 0 16 16" className={classes} aria-hidden>
        <circle cx="8" cy="8" r="7.5" className="fill-success" />
        <path
          d="M5 8.2 7 10.2 11 6"
          fill="none"
          stroke="white"
          strokeWidth="1.75"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    )
  }

  return (
    <svg viewBox="0 0 16 16" className={classes} aria-hidden>
      <circle
        cx="8"
        cy="8"
        r={R}
        fill="none"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeDasharray={status === 'in_progress' ? '2.5 2.6' : undefined}
        className={status === 'in_progress' ? 'stroke-blue-500' : 'stroke-border'}
      />
    </svg>
  )
}
