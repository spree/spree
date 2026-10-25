import type { MaintenanceTaskParameter, MaintenanceTaskRun } from '@spree/admin-sdk'

/**
 * A task's short name as a label — `backfill_order_markets` reads as
 * "Backfill order markets" in a table cell.
 */
export function taskShortName(taskName: string): string {
  return taskName.replaceAll('_', ' ').replace(/^./, (character) => character.toUpperCase())
}

/**
 * A run's label. A one-pass upgrade step runs through the shared
 * `upgrade_step` task, so its own step id is what tells the runs apart.
 */
export function runTitle(run: Pick<MaintenanceTaskRun, 'task_name' | 'arguments'>): string {
  const stepId = run.task_name === 'upgrade_step' ? run.arguments?.step_id : undefined
  return taskShortName(typeof stepId === 'string' && stepId !== '' ? stepId : run.task_name)
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

/**
 * Seeds a run form from the parameter schema the server published.
 *
 * Values are kept as the strings the inputs produce; the server casts them
 * through the task's own attribute types, which is what makes a parameter's
 * declared type the single source of truth for how it is parsed.
 */
export function defaultTaskArguments(
  parameters: MaintenanceTaskParameter[],
): Record<string, unknown> {
  const values: Record<string, unknown> = {}

  for (const parameter of parameters) {
    if (parameter.default !== null && parameter.default !== undefined) {
      values[parameter.name] = parameter.default
    } else if (parameter.type === 'boolean') {
      values[parameter.name] = false
    } else {
      values[parameter.name] = ''
    }
  }

  return values
}

/**
 * Drops empty optional parameters so the server applies its own defaults
 * rather than casting an empty string to zero.
 */
export function pruneTaskArguments(
  parameters: MaintenanceTaskParameter[],
  values: Record<string, unknown>,
): Record<string, unknown> {
  const result: Record<string, unknown> = {}

  for (const parameter of parameters) {
    const value = values[parameter.name]
    if (value === '' || value === undefined || value === null) continue
    result[parameter.name] = value
  }

  return result
}

/** Client-side check for the required parameters, so an empty form never round-trips. */
export function missingRequiredArguments(
  parameters: MaintenanceTaskParameter[],
  values: Record<string, unknown>,
): string[] {
  return parameters
    .filter((parameter) => parameter.required)
    .filter((parameter) => {
      const value = values[parameter.name]
      return value === '' || value === undefined || value === null
    })
    .map((parameter) => parameter.name)
}
