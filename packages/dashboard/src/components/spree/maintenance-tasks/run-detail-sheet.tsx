import { Can, Subject } from '@spree/dashboard-core'
import {
  Button,
  Progress,
  ProgressLabel,
  ProgressValue,
  RelativeTime,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'
import {
  useCancelMaintenanceTaskRun,
  useMaintenanceTaskRun,
  usePauseMaintenanceTaskRun,
  useResumeMaintenanceTaskRun,
} from '../../../hooks/use-maintenance-tasks'
import { taskShortName } from '../../../lib/maintenance-tasks'

export function RunDetailSheet({
  runId,
  open,
  onOpenChange,
}: {
  runId: string | undefined
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()

  const { data: run, isLoading } = useMaintenanceTaskRun(open ? runId : undefined)
  const pauseMutation = usePauseMaintenanceTaskRun()
  const resumeMutation = useResumeMaintenanceTaskRun()
  const cancelMutation = useCancelMaintenanceTaskRun()

  const busy = pauseMutation.isPending || resumeMutation.isPending || cancelMutation.isPending

  async function handleCancel() {
    if (!run) return

    const confirmed = await confirm({
      title: t('admin.maintenance_tasks.cancel_confirm.title'),
      message: t('admin.maintenance_tasks.cancel_confirm.message'),
      variant: 'destructive',
      confirmLabel: t('admin.maintenance_tasks.actions.cancel_run'),
    })
    if (!confirmed) return

    await cancelMutation.mutateAsync(run.id).catch(() => undefined)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {run ? taskShortName(run.task_name) : t('admin.maintenance_tasks.run.loading')}
          </SheetTitle>
          <SheetDescription>
            {run && t(`admin.maintenance_tasks.initiated_via.${run.initiated_via}`)}
          </SheetDescription>
        </SheetHeader>

        <div className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-6 overflow-y-auto p-4">
            {isLoading && !run && (
              <p className="text-muted-foreground text-sm">
                {t('admin.maintenance_tasks.run.loading')}
              </p>
            )}

            {run && (
              <>
                <div className="flex flex-wrap items-center gap-2">
                  <StatusBadge
                    status={run.status}
                    label={t(`admin.maintenance_tasks.status.${run.status}`)}
                  />
                  {run.dry_run && (
                    <span className="rounded bg-muted px-2 py-0.5 text-muted-foreground text-xs">
                      {t('admin.maintenance_tasks.dry_run_badge')}
                    </span>
                  )}
                </div>

                {/* A task that could not count its collection gets an
                  indeterminate bar rather than a fake percentage. */}
                <Progress
                  value={run.tick_total == null ? null : run.tick_count}
                  max={run.tick_total ?? undefined}
                >
                  <ProgressLabel>{t('admin.maintenance_tasks.run.progress_label')}</ProgressLabel>
                  <ProgressValue>
                    {() =>
                      run.tick_total == null
                        ? t('admin.maintenance_tasks.run.processed_count', {
                            count: run.tick_count,
                          })
                        : `${run.tick_count} / ${run.tick_total}`
                    }
                  </ProgressValue>
                </Progress>

                <DetailRows run={run} />

                {Object.keys(run.tallies).length > 0 && (
                  <section className="flex flex-col gap-2">
                    <h3 className="font-medium text-sm">
                      {t('admin.maintenance_tasks.run.results')}
                    </h3>
                    <dl className="flex flex-col gap-1 text-sm">
                      {Object.entries(run.tallies).map(([key, count]) => (
                        <div key={key} className="flex justify-between gap-4">
                          <dt className="text-muted-foreground">{humanizeTally(key)}</dt>
                          <dd className="tabular-nums">{count}</dd>
                        </div>
                      ))}
                    </dl>
                  </section>
                )}

                {run.error_message && (
                  <section className="flex flex-col gap-2">
                    <h3 className="font-medium text-destructive text-sm">
                      {run.error_class ?? t('admin.maintenance_tasks.run.error')}
                    </h3>
                    <p className="text-sm">{run.error_message}</p>
                    {run.error_backtrace && (
                      <details className="text-muted-foreground text-xs">
                        <summary className="cursor-pointer">
                          {t('admin.maintenance_tasks.run.show_backtrace')}
                        </summary>
                        <pre className="mt-2 overflow-x-auto whitespace-pre-wrap">
                          {run.error_backtrace}
                        </pre>
                      </details>
                    )}
                  </section>
                )}

                {Object.keys(run.arguments).length > 0 && (
                  <section className="flex flex-col gap-2">
                    <h3 className="font-medium text-sm">
                      {t('admin.maintenance_tasks.run.arguments')}
                    </h3>
                    <dl className="flex flex-col gap-1 text-sm">
                      {Object.entries(run.arguments).map(([key, value]) => (
                        <div key={key} className="flex justify-between gap-4">
                          <dt className="text-muted-foreground">{key}</dt>
                          <dd className="break-all">{String(value)}</dd>
                        </div>
                      ))}
                    </dl>
                  </section>
                )}
              </>
            )}
          </div>
        </div>

        {run && (
          <SheetFooter>
            <Can I="update" a={Subject.MaintenanceTaskRun}>
              {run.status === 'running' && (
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => pauseMutation.mutateAsync(run.id).catch(() => undefined)}
                  disabled={busy}
                >
                  {t('admin.maintenance_tasks.actions.pause')}
                </Button>
              )}

              {run.resumable && (
                <Button
                  type="button"
                  size="sm"
                  onClick={() => resumeMutation.mutateAsync(run.id).catch(() => undefined)}
                  disabled={busy}
                >
                  {t('admin.maintenance_tasks.actions.resume')}
                </Button>
              )}

              {run.cancelable && (
                <Button
                  type="button"
                  variant="destructive"
                  size="sm"
                  onClick={handleCancel}
                  disabled={busy}
                >
                  {t('admin.maintenance_tasks.actions.cancel_run')}
                </Button>
              )}
            </Can>
          </SheetFooter>
        )}
      </SheetContent>
    </Sheet>
  )
}

function DetailRows({
  run,
}: {
  run: NonNullable<ReturnType<typeof useMaintenanceTaskRun>['data']>
}) {
  const { t } = useTranslation()

  return (
    <dl className="flex flex-col gap-1 text-sm">
      {run.admin_user && (
        <Row label={t('admin.maintenance_tasks.run.initiated_by')}>{run.admin_user.email}</Row>
      )}
      {run.started_at && (
        <Row label={t('admin.maintenance_tasks.run.started')}>
          <RelativeTime iso={run.started_at} />
        </Row>
      )}
      {run.ended_at && (
        <Row label={t('admin.maintenance_tasks.run.ended')}>
          <RelativeTime iso={run.ended_at} />
        </Row>
      )}
      {run.duration != null && (
        <Row label={t('admin.maintenance_tasks.run.duration')}>
          {t('admin.maintenance_tasks.run.seconds', { count: Math.round(run.duration) })}
        </Row>
      )}
    </dl>
  )
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex justify-between gap-4">
      <dt className="text-muted-foreground">{label}</dt>
      <dd>{children}</dd>
    </div>
  )
}

function humanizeTally(key: string): string {
  return key.replace(/_/g, ' ').replace(/^./, (character) => character.toUpperCase())
}
