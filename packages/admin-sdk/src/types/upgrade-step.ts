import type { MaintenanceTaskRun } from './generated'

/**
 * One step of an upgrade manifest — the data work a release requires, in the
 * order it has to run (docs/plans/6.0-maintenance-tasks.md).
 *
 * Hand-written: the endpoint describes manifest entries rather than a
 * serialized record, so there is no serializer to derive it from.
 */
export interface UpgradeStep {
  /** Manifest step id, stable across releases and used with `STEP=` on the CLI. */
  id: string
  name: string
  /** Operator guidance from the manifest — ordering constraints, knobs, caveats. */
  notes: string | null
  /** Release boundary this step belongs to. */
  from: string
  to: string
  docs: string | null
  /** The maintenance task to start for this step. */
  task_name: string
  /**
   * Arguments to start it with. Empty for a step that is its own task; carries
   * `step_id` for the steps of released manifests, which share one wrapper.
   */
  arguments: Record<string, unknown>
  last_run: MaintenanceTaskRun | null
}
