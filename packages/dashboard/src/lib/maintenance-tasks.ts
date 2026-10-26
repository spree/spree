import type { MaintenanceTaskRun } from '@spree/admin-sdk'

/**
 * A snake_case name as a label — `backfill_order_markets` reads as
 * "Backfill order markets".
 */
export function humanizeName(taskName: string): string {
  return taskName.replaceAll('_', ' ').replace(/^./, (character) => character.toUpperCase())
}

/**
 * A run's label. A one-pass upgrade step runs through the shared
 * `upgrade_step` task, so its own step id is what tells the runs apart.
 */
export function runTitle(run: Pick<MaintenanceTaskRun, 'task_name' | 'arguments'>): string {
  const stepId = run.task_name === 'upgrade_step' ? run.arguments?.step_id : undefined
  return humanizeName(typeof stepId === 'string' && stepId !== '' ? stepId : run.task_name)
}

/**
 * The value and maximum for a run's progress bar.
 *
 * A task that could not count its collection gets an indeterminate bar while
 * it works, but once it has finished that bar would still read as running —
 * a succeeded run fills the bar, and a run that stopped early shows what it
 * reached, or nothing when there was no total to measure against.
 */
export function runProgress(
  run: Pick<MaintenanceTaskRun, 'active' | 'status' | 'tick_count' | 'tick_total'>,
): {
  value: number | null
  max: number | undefined
} {
  if (run.status === 'succeeded') return { value: 1, max: 1 }
  if (run.tick_total != null) return { value: run.tick_count, max: run.tick_total }
  return run.active ? { value: null, max: undefined } : { value: 0, max: 1 }
}
