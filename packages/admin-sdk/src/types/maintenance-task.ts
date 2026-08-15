/**
 * A registered maintenance task — a deployed Ruby class an operator can run,
 * not a database record (docs/plans/6.0-maintenance-tasks.md).
 *
 * Hand-written rather than generated: the discovery endpoint describes classes
 * and their parameter schemas, so there is no serializer to derive it from.
 */
export interface MaintenanceTaskParameter {
  name: string
  type: 'string' | 'integer' | 'decimal' | 'boolean' | 'date' | 'datetime'
  /** Whether the task declares a presence validator on this parameter. */
  required: boolean
  /** Permitted values when the task declares an inclusion validator — render a select. */
  options: string[] | null
  /** Never echo a value back for these; the server returns them masked. */
  masked: boolean
  default: unknown
}

export interface MaintenanceTask {
  /** The Ruby class name, which is also the identifier used to fetch and run it. */
  name: string
  description: string | null
  parameters: MaintenanceTaskParameter[]
  /** Show a preview toggle only when this is true — the task honors it itself. */
  supports_dry_run: boolean
  /** A single operation rather than an iteration; there is no progress bar to draw. */
  no_collection: boolean
  /** Non-null while a run of this task is in flight — starting a second is refused. */
  active_run: import('./generated').MaintenanceTaskRun | null
  last_run: import('./generated').MaintenanceTaskRun | null
}
