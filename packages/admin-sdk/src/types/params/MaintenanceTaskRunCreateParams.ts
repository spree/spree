// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type MaintenanceTaskRunCreateParams = {
  /** The task to run, as `task_name` from `GET /upgrade_steps`. */
  task_name: string
  /**
   * Values for the task's declared parameters, keyed by parameter name. A key the task does not
   * declare is rejected.
   */
  arguments?: Record<string, unknown>
  /**
   * Report what would change without writing. Ignored by tasks that do not support a dry run, which
   * run for real.
   */
  dry_run?: boolean
}
