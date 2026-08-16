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
  /**
   * True for a release this installation has already been through. Shown as
   * history and never runnable — re-running a completed conversion is how an
   * upgrade does damage.
   */
  superseded: boolean
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

export interface UpgradeStepsMeta {
  /** The release this installation is running. */
  installed_version: string
  /** The boundary whose steps are already done, and where the list starts. */
  completed_version: string | null
  /**
   * False when `completed_version` was assumed from the installed version
   * rather than recorded by an upgrade walk or a fresh install. A store that
   * postponed several releases needs the older steps, so offer them rather
   * than hide them when this is false.
   */
  completed_version_recorded: boolean
  /** How many steps belong to releases this store has already been through. */
  superseded_step_count: number
  /**
   * False for a store installed fresh at this release — it has no historical
   * data to convert, so there is no upgrade to show and `data` is empty.
   */
  upgrade_relevant: boolean
}
