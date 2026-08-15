import type { MaintenanceTaskRun, MaintenanceTaskRunCreateParams } from '@spree/admin-sdk'
import {
  adminClient,
  i18n,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

const RUN_POLL_INTERVAL_MS = 2000

/** Statuses that mean the runner still has work to do, so keep polling. */
export function isRunActive(status: string | undefined): boolean {
  if (!status) return false
  return ['enqueued', 'running', 'pausing', 'paused', 'interrupted', 'cancelling'].includes(status)
}

/**
 * The tasks this installation can run. Task classes only change on deploy, so
 * this refetches on the poll interval only while a run of any task is active —
 * that is what keeps each card's `active_run` badge honest.
 */
export function useMaintenanceTasks() {
  return useQuery({
    queryKey: useResourceKey('maintenance-tasks'),
    queryFn: () => adminClient.maintenanceTasks.list(),
    refetchInterval: (query) =>
      query.state.data?.data.some((task) => isRunActive(task.active_run?.status ?? undefined))
        ? RUN_POLL_INTERVAL_MS
        : false,
  })
}

/**
 * One run, polled while the runner is working.
 *
 * A finished run invalidates the task list so the card it came from stops
 * showing a run in flight, and the run history so the row's status is current.
 * A maintenance task writes records outside any tracked mutation, so nothing
 * else would ever mark those caches stale.
 */
export function useMaintenanceTaskRun(id: string | undefined) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useQuery({
    queryKey: useResourceKey('maintenance-task-runs', id),
    queryFn: () => adminClient.maintenanceTaskRuns.get(id as string),
    enabled: !!id,
    refetchInterval: (query) => {
      if (isRunActive(query.state.data?.status)) return RUN_POLL_INTERVAL_MS

      // The run just reached a terminal status on this tick.
      if (query.state.data) {
        queryClient.invalidateQueries({ queryKey: buildKey('maintenance-tasks') })
        queryClient.invalidateQueries({ queryKey: buildKey('maintenance-task-runs') })
        queryClient.invalidateQueries({ queryKey: buildKey('upgrade-steps') })
      }
      return false
    },
  })
}

/**
 * The upgrade manifest as an ordered checklist. Polled while any step is
 * working, so the panel advances as the walk does.
 */
export function useUpgradeSteps() {
  return useQuery({
    queryKey: useResourceKey('upgrade-steps'),
    queryFn: () => adminClient.upgradeSteps.list(),
    refetchInterval: (query) =>
      query.state.data?.data.some((step) => isRunActive(step.last_run?.status ?? undefined))
        ? RUN_POLL_INTERVAL_MS
        : false,
  })
}

export function useStartMaintenanceTask() {
  return useResourceMutation<MaintenanceTaskRun, Error, MaintenanceTaskRunCreateParams>({
    mutationFn: (params) => adminClient.maintenanceTaskRuns.create(params),
    invalidate: [['maintenance-tasks'], ['maintenance-task-runs'], ['upgrade-steps']],
    successMessage: i18n.t('admin.maintenance_tasks.messages.started'),
    errorMessage: i18n.t('admin.maintenance_tasks.messages.start_failed'),
  })
}

export function usePauseMaintenanceTaskRun() {
  return useRunControl('pause', 'paused')
}

export function useResumeMaintenanceTaskRun() {
  return useRunControl('resume', 'resumed')
}

export function useCancelMaintenanceTaskRun() {
  return useRunControl('cancel', 'canceled')
}

/**
 * Pause, resume and cancel differ only in which endpoint they call and what
 * they say afterwards. Each writes the returned run straight into the cache so
 * the buttons settle on the new status without waiting for the next poll.
 */
function useRunControl(action: 'pause' | 'resume' | 'cancel', messageKey: string) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<MaintenanceTaskRun, Error, string>({
    mutationFn: (id) => adminClient.maintenanceTaskRuns[action](id),
    invalidate: [['maintenance-tasks'], ['maintenance-task-runs'], ['upgrade-steps']],
    successMessage: i18n.t(`admin.maintenance_tasks.messages.${messageKey}`),
    errorMessage: i18n.t('admin.errors.generic'),
    onSuccess: (run) => {
      queryClient.setQueryData(buildKey('maintenance-task-runs', run.id), run)
    },
  })
}
