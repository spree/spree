import type { MaintenanceTaskRun, MaintenanceTaskRunCreateParams } from '@spree/admin-sdk'
import {
  adminClient,
  i18n,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useRef } from 'react'

const RUN_POLL_INTERVAL_MS = 2000

/** Statuses that mean the runner still has work to do, so keep polling. */
export function isRunActive(status: string | undefined): boolean {
  if (!status) return false
  return ['enqueued', 'running', 'pausing', 'paused', 'interrupted', 'cancelling'].includes(status)
}

/**
 * One run, polled while the runner is working.
 *
 * When a run this hook watched finishes, the run history and the upgrade
 * steps are marked stale: a maintenance task writes records
 * outside any tracked mutation, so nothing else would. Done in an effect on
 * the status changing, never from `refetchInterval` — that runs again on every
 * fetch, and the run history key covers this query too, so invalidating from
 * there refetches this run and invalidates again without end.
 */
export function useMaintenanceTaskRun(id: string | undefined) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  const query = useQuery({
    queryKey: useResourceKey('maintenance-task-runs', id),
    queryFn: () => adminClient.maintenanceTaskRuns.get(id as string, { expand: ['admin_user'] }),
    enabled: !!id,
    refetchInterval: (query) =>
      isRunActive(query.state.data?.status) ? RUN_POLL_INTERVAL_MS : false,
  })

  const status = query.data?.status
  const previousStatus = useRef(status)

  useEffect(() => {
    const finished =
      isRunActive(previousStatus.current) && status !== undefined && !isRunActive(status)
    previousStatus.current = status
    if (!finished) return

    queryClient.invalidateQueries({ queryKey: buildKey('maintenance-task-runs') })
    queryClient.invalidateQueries({ queryKey: buildKey('upgrade-steps') })
  }, [status, queryClient, buildKey])

  return query
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
    invalidate: [['maintenance-task-runs'], ['upgrade-steps']],
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
    invalidate: [['maintenance-task-runs'], ['upgrade-steps']],
    successMessage: i18n.t(`admin.maintenance_tasks.messages.${messageKey}`),
    errorMessage: i18n.t('admin.errors.generic'),
    // Merged rather than replaced: the control endpoints return the run
    // without the embedded admin user the detail query asked for.
    onSuccess: (run) => {
      queryClient.setQueryData<MaintenanceTaskRun>(
        buildKey('maintenance-task-runs', run.id),
        (cached) =>
          cached ? { ...cached, ...run, admin_user: run.admin_user ?? cached.admin_user } : run,
      )
    },
  })
}
