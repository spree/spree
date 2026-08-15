import type { MaintenanceTask } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  ResourceTable,
  resourceSearchSchema,
  Subject,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Progress,
  StatusBadge,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlayIcon, WrenchIcon } from 'lucide-react'
import { useCallback, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { RunDetailSheet } from '../../../../components/spree/maintenance-tasks/run-detail-sheet'
import { RunTaskDialog } from '../../../../components/spree/maintenance-tasks/run-task-dialog'
import { UpgradePanel } from '../../../../components/spree/maintenance-tasks/upgrade-panel'
import {
  isRunActive,
  useMaintenanceTasks,
  useUpgradeSteps,
} from '../../../../hooks/use-maintenance-tasks'
import { taskShortName } from '../../../../lib/maintenance-tasks'
import '../../../../tables/maintenance-task-runs'

// The page shares its URL with the run-history `<ResourceTable>`; `run` is the
// prefixed ID of the run whose detail sheet is open, so a run in progress can
// be linked to and survives a reload.
const searchSchema = resourceSearchSchema.extend({
  run: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/maintenance-tasks')({
  validateSearch: searchSchema,
  component: MaintenanceTasksPage,
})

function MaintenanceTasksPage() {
  const { t } = useTranslation()
  const navigate = useNavigate({ from: Route.fullPath })
  const search = Route.useSearch()
  const openRunId = search.run

  const { data, isLoading } = useMaintenanceTasks()
  const [taskToRun, setTaskToRun] = useState<MaintenanceTask | null>(null)

  // Upgrade steps have their own panel, where the manifest order and the
  // operator notes are what make them legible. Listing them again as loose
  // cards would bury the handful of tasks that are not part of an upgrade.
  //
  // Which tasks those are comes from the manifest rather than from a naming
  // convention: a task belongs to an upgrade because a manifest names it.
  const { data: upgradeData } = useUpgradeSteps()
  const upgradeTaskNames = new Set((upgradeData?.data ?? []).map((step) => step.task_name))
  const tasks = (data?.data ?? []).filter((task) => !upgradeTaskNames.has(task.name))

  const openRun = useCallback(
    (runId: string | undefined) => {
      navigate({
        search: (previous: Record<string, unknown>) => ({ ...previous, run: runId }),
        replace: true,
      })
    },
    [navigate],
  )

  // The history table's task cell carries the run id; clicking a row opens the
  // same sheet a card's progress bar does.
  useRowClickBridge('data-maintenance-task-run-id', openRun)

  return (
    <div className="flex flex-col gap-8">
      <header className="flex flex-col gap-1">
        <h1 className="font-semibold text-2xl">{t('admin.maintenance_tasks.title')}</h1>
        <p className="text-muted-foreground text-sm">{t('admin.maintenance_tasks.description')}</p>
      </header>

      <UpgradePanel onOpenRun={openRun} />

      <section className="flex flex-col gap-3">
        {isLoading && (
          <p className="text-muted-foreground text-sm">{t('admin.maintenance_tasks.loading')}</p>
        )}

        {!isLoading && tasks.length === 0 && (
          <Card>
            <CardContent className="flex flex-col items-center gap-2 py-10 text-center">
              <WrenchIcon className="size-8 text-muted-foreground" />
              <p className="font-medium">{t('admin.maintenance_tasks.empty_title')}</p>
              <p className="text-muted-foreground text-sm">
                {t('admin.maintenance_tasks.empty_description')}
              </p>
            </CardContent>
          </Card>
        )}

        <div className="grid gap-4 md:grid-cols-2">
          {tasks.map((task) => (
            <TaskCard
              key={task.name}
              task={task}
              onRun={() => setTaskToRun(task)}
              onOpenRun={openRun}
            />
          ))}
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="font-semibold text-lg">{t('admin.maintenance_tasks.history.title')}</h2>
        <ResourceTable
          tableKey="maintenance-task-runs"
          queryKey="maintenance-task-runs"
          queryFn={(params) => adminClient.maintenanceTaskRuns.list(params)}
          searchParams={search}
        />
      </section>

      <RunTaskDialog
        task={taskToRun}
        open={!!taskToRun}
        onOpenChange={(open) => !open && setTaskToRun(null)}
        onStarted={openRun}
      />

      <RunDetailSheet
        runId={openRunId}
        open={!!openRunId}
        onOpenChange={(open) => !open && openRun(undefined)}
      />
    </div>
  )
}

function TaskCard({
  task,
  onRun,
  onOpenRun,
}: {
  task: MaintenanceTask
  onRun: () => void
  onOpenRun: (runId: string) => void
}) {
  const { t } = useTranslation()
  const activeRun = task.active_run
  const lastRun = task.last_run
  const busy = isRunActive(activeRun?.status ?? undefined)

  return (
    <Card>
      <CardHeader>
        <div className="flex items-start justify-between gap-3">
          <div className="flex flex-col gap-1">
            <CardTitle className="text-base">{taskShortName(task.name)}</CardTitle>
            <CardDescription>
              {task.description ?? t('admin.maintenance_tasks.run.no_description')}
            </CardDescription>
          </div>

          <Can I="update" a={Subject.MaintenanceTaskRun}>
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={onRun}
              disabled={busy}
              title={busy ? t('admin.maintenance_tasks.already_running') : undefined}
            >
              <PlayIcon className="size-4" />
              {t('admin.maintenance_tasks.actions.run')}
            </Button>
          </Can>
        </div>
      </CardHeader>

      <CardContent className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center gap-2">
          {task.supports_dry_run && (
            <Badge variant="secondary">{t('admin.maintenance_tasks.supports_dry_run')}</Badge>
          )}
        </div>

        {busy && activeRun && (
          <button
            type="button"
            className="flex flex-col gap-1 text-left"
            onClick={() => onOpenRun(activeRun.id)}
          >
            <Progress
              value={activeRun.tick_total == null ? null : activeRun.tick_count}
              max={activeRun.tick_total ?? undefined}
            />
            <span className="text-muted-foreground text-xs">
              {t('admin.maintenance_tasks.run.processed_count', { count: activeRun.tick_count })}
            </span>
          </button>
        )}

        {!busy && lastRun && (
          <button
            type="button"
            className="flex items-center gap-2 text-left text-sm"
            onClick={() => onOpenRun(lastRun.id)}
          >
            <span className="text-muted-foreground">{t('admin.maintenance_tasks.last_run')}</span>
            <StatusBadge
              status={lastRun.status}
              label={t(`admin.maintenance_tasks.status.${lastRun.status}`)}
            />
          </button>
        )}

        {!busy && !lastRun && (
          <p className="text-muted-foreground text-sm">{t('admin.maintenance_tasks.never_run')}</p>
        )}
      </CardContent>
    </Card>
  )
}
