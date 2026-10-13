// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type MaintenanceTaskRunCreateParams = {
  /** The task to run, as `name` from `GET /maintenance_tasks`. */
  task_name: string
  /**
   * Values for the task's declared parameters, keyed by parameter name. A key the task does not
   * declare is rejected.
   */
  arguments?: Record<string, unknown>
  /**
   * Report what would change without writing. Honored only by tasks whose `supports_dry_run` is
   * true.
   */
  dry_run?: boolean
  /** The `signed_id` of an uploaded CSV, for tasks whose `csv` is true. Rejected by the rest. */
  csv_file?: string
}
