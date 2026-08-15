import type { UpgradeStep } from '@spree/admin-sdk'
import { Can, Subject } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Progress,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import { CheckIcon, ChevronRightIcon, ExternalLinkIcon, PlayIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  isRunActive,
  useStartMaintenanceTask,
  useUpgradeSteps,
} from '../../../hooks/use-maintenance-tasks'

/**
 * The upgrade manifest as an ordered checklist.
 *
 * The steps are ordinary maintenance tasks and can be run from the task list
 * like any other. What this adds is the part a task cannot know about itself:
 * the order it must run in, the operator notes the manifest carries, and how
 * far through the release an installation has got.
 */
export function UpgradePanel({ onOpenRun }: { onOpenRun: (runId: string) => void }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const startMutation = useStartMaintenanceTask()

  const { data, isLoading } = useUpgradeSteps()
  const [expanded, setExpanded] = useState<string | null>(null)

  const steps = data?.data ?? []
  if (isLoading || steps.length === 0) return null

  // The release being upgraded TO is the last boundary in the walk, not the
  // first: a store several versions behind runs older manifests on the way,
  // and naming one of those as the destination would misreport the target.
  const targetVersion = steps[steps.length - 1].to
  const guideUrl = [...steps].reverse().find((step) => step.docs)?.docs

  const done = steps.filter((step) => step.last_run?.status === 'succeeded').length
  const busy = steps.some((step) => isRunActive(step.last_run?.status ?? undefined))
  const nextStep = steps.find((step) => step.last_run?.status !== 'succeeded')

  async function runStep(step: UpgradeStep) {
    const confirmed = await confirm({
      title: t('admin.maintenance_tasks.upgrade.confirm.title', { name: step.name }),
      message: t('admin.maintenance_tasks.upgrade.confirm.message'),
      confirmLabel: t('admin.maintenance_tasks.upgrade.run_step'),
    })
    if (!confirmed) return

    const run = await startMutation
      .mutateAsync({ task_name: step.task_name, arguments: step.arguments })
      .catch(() => undefined)

    if (run) onOpenRun(run.id)
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="flex flex-col gap-1">
            <CardTitle className="text-base">
              {t('admin.maintenance_tasks.upgrade.title', { version: targetVersion })}
            </CardTitle>
            <CardDescription>{t('admin.maintenance_tasks.upgrade.description')}</CardDescription>
          </div>

          <div className="flex items-center gap-3">
            <span className="text-muted-foreground text-sm tabular-nums">
              {t('admin.maintenance_tasks.upgrade.progress', { done, total: steps.length })}
            </span>

            {/* Runs the next unfinished step rather than the whole manifest:
                steps have ordering constraints, and a failure part way needs
                the operator to look before the walk carries on. */}
            <Can I="update" a={Subject.MaintenanceTaskRun}>
              {nextStep && (
                <Button
                  type="button"
                  size="sm"
                  onClick={() => runStep(nextStep)}
                  disabled={busy || startMutation.isPending}
                >
                  <PlayIcon className="size-4" />
                  {t('admin.maintenance_tasks.upgrade.run_next')}
                </Button>
              )}
            </Can>
          </div>
        </div>

        <Progress value={done} max={steps.length} className="mt-2" />
      </CardHeader>

      <CardContent className="flex flex-col gap-1">
        {steps.map((step, index) => (
          <StepRow
            key={`${step.to}-${step.id}`}
            step={step}
            position={index + 1}
            expanded={expanded === step.id}
            onToggle={() => setExpanded(expanded === step.id ? null : step.id)}
            onRun={() => runStep(step)}
            onOpenRun={onOpenRun}
            disabled={busy || startMutation.isPending}
          />
        ))}

        {guideUrl && (
          <a
            href={guideUrl}
            target="_blank"
            rel="noreferrer"
            className="mt-2 flex items-center gap-1 text-muted-foreground text-xs hover:underline"
          >
            <ExternalLinkIcon className="size-3" />
            {t('admin.maintenance_tasks.upgrade.read_guide')}
          </a>
        )}
      </CardContent>
    </Card>
  )
}

function StepRow({
  step,
  position,
  expanded,
  onToggle,
  onRun,
  onOpenRun,
  disabled,
}: {
  step: UpgradeStep
  position: number
  expanded: boolean
  onToggle: () => void
  onRun: () => void
  onOpenRun: (runId: string) => void
  disabled: boolean
}) {
  const { t } = useTranslation()
  const run = step.last_run
  const succeeded = run?.status === 'succeeded'
  const active = isRunActive(run?.status ?? undefined)

  return (
    <div className="rounded-md border border-transparent hover:border-border">
      <div className="flex items-center gap-3 p-2">
        <span
          className={
            succeeded
              ? 'flex size-5 shrink-0 items-center justify-center rounded-full bg-green-500/15 text-green-600'
              : 'flex size-5 shrink-0 items-center justify-center rounded-full bg-muted text-muted-foreground text-xs tabular-nums'
          }
        >
          {succeeded ? <CheckIcon className="size-3" /> : position}
        </span>

        <button
          type="button"
          className="flex flex-1 items-center gap-2 text-left"
          onClick={onToggle}
        >
          <ChevronRightIcon
            className={
              expanded ? 'size-3 rotate-90 text-muted-foreground' : 'size-3 text-muted-foreground'
            }
          />
          <span className={succeeded ? 'text-muted-foreground text-sm' : 'text-sm'}>
            {step.name}
          </span>
        </button>

        {run && (
          <button type="button" onClick={() => onOpenRun(run.id)}>
            <StatusBadge
              status={run.status}
              label={t(`admin.maintenance_tasks.status.${run.status}`)}
            />
          </button>
        )}

        <Can I="update" a={Subject.MaintenanceTaskRun}>
          <Button
            type="button"
            size="sm"
            variant="ghost"
            onClick={onRun}
            disabled={disabled || active}
          >
            {succeeded
              ? t('admin.maintenance_tasks.upgrade.run_again')
              : t('admin.maintenance_tasks.upgrade.run_step')}
          </Button>
        </Can>
      </div>

      {/* The manifest's own guidance: ordering constraints and caveats that
          decide whether a step is safe to run right now. */}
      {expanded && step.notes && (
        <p className="whitespace-pre-line px-10 pb-3 text-muted-foreground text-xs">{step.notes}</p>
      )}
    </div>
  )
}
