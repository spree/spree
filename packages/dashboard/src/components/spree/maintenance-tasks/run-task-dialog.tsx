import type { MaintenanceTask } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldLabel,
  Switch,
} from '@spree/dashboard-ui'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useStartMaintenanceTask } from '../../../hooks/use-maintenance-tasks'
import {
  defaultTaskArguments,
  missingRequiredArguments,
  pruneTaskArguments,
  taskShortName,
} from '../../../lib/maintenance-tasks'
import { TaskParametersForm } from './task-parameters-form'

export function RunTaskDialog({
  task,
  open,
  onOpenChange,
  onStarted,
}: {
  task: MaintenanceTask | null
  open: boolean
  onOpenChange: (open: boolean) => void
  onStarted: (runId: string) => void
}) {
  const { t } = useTranslation()
  const startMutation = useStartMaintenanceTask()

  const [values, setValues] = useState<Record<string, unknown>>({})
  const [dryRun, setDryRun] = useState(false)
  const [missing, setMissing] = useState<string[]>([])
  const [submitError, setSubmitError] = useState<string | null>(null)

  // Reseeding on the task rather than on `open` keeps a reopened dialog from
  // discarding nothing, while still starting clean for a different task.
  useEffect(() => {
    if (!task) return
    setValues(defaultTaskArguments(task.parameters))
    // A task that can preview defaults to previewing: the safe run is the one
    // an operator should have to opt out of, not into.
    setDryRun(task.supports_dry_run)
    setMissing([])
    setSubmitError(null)
  }, [task])

  if (!task) return null

  async function handleSubmit() {
    if (!task) return

    const blank = missingRequiredArguments(task.parameters, values)
    setMissing(blank)
    if (blank.length > 0) return

    setSubmitError(null)

    try {
      const run = await startMutation.mutateAsync({
        task_name: task.name,
        arguments: pruneTaskArguments(task.parameters, values),
        dry_run: dryRun,
      })
      onOpenChange(false)
      onStarted(run.id)
    } catch (error) {
      // No react-hook-form here — the fields come from a server schema, so
      // there is no static field map to route errors onto. Show what the
      // server said above the form instead.
      if (!mapSpreeErrorsToForm(error, () => undefined)) throw error
      setSubmitError(error instanceof Error ? error.message : String(error))
    }
  }

  const running = startMutation.isPending

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{taskShortName(task.name)}</DialogTitle>
          <DialogDescription>
            {task.description ?? t('admin.maintenance_tasks.run.no_description')}
          </DialogDescription>
        </DialogHeader>

        <DialogBody className="flex flex-col gap-4">
          {submitError && (
            <p className="text-destructive text-sm" role="alert">
              {submitError}
            </p>
          )}

          <TaskParametersForm
            parameters={task.parameters}
            values={values}
            onChange={setValues}
            missing={missing}
          />

          {task.supports_dry_run && (
            <Field orientation="horizontal">
              <Switch id="maintenance-task-dry-run" checked={dryRun} onCheckedChange={setDryRun} />
              <div className="flex flex-col">
                <FieldLabel htmlFor="maintenance-task-dry-run">
                  {t('admin.maintenance_tasks.run.dry_run_label')}
                </FieldLabel>
                <span className="text-muted-foreground text-xs">
                  {t('admin.maintenance_tasks.run.dry_run_help')}
                </span>
              </div>
            </Field>
          )}

          {/* The runner has no undo: it stops a run, it cannot unwrite one. */}
          {!dryRun && (
            <p className="text-muted-foreground text-xs">
              {t('admin.maintenance_tasks.run.write_warning')}
            </p>
          )}
        </DialogBody>

        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => onOpenChange(false)}
            disabled={running}
          >
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" size="sm" onClick={handleSubmit} disabled={running}>
            {running
              ? t('admin.maintenance_tasks.run.starting')
              : dryRun
                ? t('admin.maintenance_tasks.run.start_dry_run')
                : t('admin.maintenance_tasks.run.start')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
