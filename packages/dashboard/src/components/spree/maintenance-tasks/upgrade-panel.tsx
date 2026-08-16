import type { UpgradeStep, UpgradeStepsMeta } from '@spree/admin-sdk'
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

interface Boundary {
  from: string
  to: string
  steps: UpgradeStep[]
  /** A release this installation has already been through. */
  superseded: boolean
  docs: string | null
}

/**
 * The upgrade manifests, one card per release.
 *
 * The release being upgraded to comes first, open, with its steps runnable.
 * Releases already crossed follow as collapsed history — a store should be
 * able to see which upgrades it has been through, but re-running a conversion
 * it already applied is how an upgrade does damage, so those are never
 * runnable.
 *
 * Renders nothing at all for a store installed fresh at this release: it has
 * no historical data to convert, so neither the steps nor the history describe
 * anything real for it.
 */
export function UpgradePanel({ onOpenRun }: { onOpenRun: (runId: string) => void }) {
  const { data, isLoading } = useUpgradeSteps()

  const allSteps = data?.data ?? []
  if (isLoading || allSteps.length === 0) return null

  const boundaries = groupByBoundary(allSteps)
  const current = boundaries.filter((boundary) => !boundary.superseded)
  // Newest first: the most recently completed upgrade is the one an operator
  // is most likely to be checking.
  const history = boundaries.filter((boundary) => boundary.superseded).reverse()

  return (
    <div className="flex flex-col gap-4">
      {current.map((boundary) => (
        <BoundaryCard
          key={`${boundary.from}-${boundary.to}`}
          boundary={boundary}
          meta={data?.meta}
          onOpenRun={onOpenRun}
        />
      ))}

      {history.map((boundary) => (
        <BoundaryCard
          key={`${boundary.from}-${boundary.to}`}
          boundary={boundary}
          onOpenRun={onOpenRun}
        />
      ))}
    </div>
  )
}

function BoundaryCard({
  boundary,
  meta,
  onOpenRun,
}: {
  boundary: Boundary
  meta?: UpgradeStepsMeta
  onOpenRun: (runId: string) => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const startMutation = useStartMaintenanceTask()

  // History starts collapsed — it is reference, not work.
  const [open, setOpen] = useState(!boundary.superseded)
  const [expandedStep, setExpandedStep] = useState<string | null>(null)

  const { steps, superseded } = boundary
  const done = superseded
    ? steps.length
    : steps.filter((step) => step.last_run?.status === 'succeeded').length
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
    <Card className={superseded ? 'border-dashed' : undefined}>
      <CardHeader>
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="flex flex-col gap-1">
            <CardTitle className={superseded ? 'text-base text-muted-foreground' : 'text-base'}>
              {superseded
                ? t('admin.maintenance_tasks.upgrade.boundary', {
                    from: boundary.from,
                    to: boundary.to,
                  })
                : t('admin.maintenance_tasks.upgrade.title', { version: boundary.to })}
            </CardTitle>
            <CardDescription>
              {superseded
                ? t('admin.maintenance_tasks.upgrade.history_description')
                : t('admin.maintenance_tasks.upgrade.description')}
            </CardDescription>
          </div>

          <div className="flex items-center gap-3">
            <span className="text-muted-foreground text-sm tabular-nums">
              {superseded
                ? t('admin.maintenance_tasks.upgrade.already_completed')
                : t('admin.maintenance_tasks.upgrade.progress', { done, total: steps.length })}
            </span>

            {superseded ? (
              <Button type="button" size="sm" variant="ghost" onClick={() => setOpen(!open)}>
                {open
                  ? t('admin.maintenance_tasks.upgrade.hide_steps')
                  : t('admin.maintenance_tasks.upgrade.show_steps')}
              </Button>
            ) : (
              // Runs the next unfinished step rather than the whole manifest:
              // steps have ordering constraints, and a failure part way needs
              // the operator to look before the walk carries on.
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
            )}
          </div>
        </div>

        {!superseded && <Progress value={done} max={steps.length} className="mt-2" />}
      </CardHeader>

      {open && (
        <CardContent className="flex flex-col gap-1">
          {steps.map((step, index) => (
            <StepRow
              key={`${step.to}-${step.id}`}
              step={step}
              position={index + 1}
              superseded={superseded}
              expanded={expandedStep === step.id}
              onToggle={() => setExpandedStep(expandedStep === step.id ? null : step.id)}
              onRun={() => runStep(step)}
              onOpenRun={onOpenRun}
              disabled={busy || startMutation.isPending}
            />
          ))}

          {/* Without a recorded boundary the earlier releases are shown as
              completed on an assumption. A store that actually skipped them
              needs to know their steps are still runnable. */}
          {meta && !meta.completed_version_recorded && meta.superseded_step_count > 0 && (
            <p className="px-2 pt-2 text-muted-foreground text-xs">
              {t('admin.maintenance_tasks.upgrade.assumed_boundary', {
                version: meta.completed_version,
              })}
            </p>
          )}

          {boundary.docs && (
            <a
              href={boundary.docs}
              target="_blank"
              rel="noreferrer"
              className="mt-2 flex items-center gap-1 text-muted-foreground text-xs hover:underline"
            >
              <ExternalLinkIcon className="size-3" />
              {t('admin.maintenance_tasks.upgrade.read_guide')}
            </a>
          )}
        </CardContent>
      )}
    </Card>
  )
}

function StepRow({
  step,
  position,
  superseded,
  expanded,
  onToggle,
  onRun,
  onOpenRun,
  disabled,
}: {
  step: UpgradeStep
  position: number
  superseded: boolean
  expanded: boolean
  onToggle: () => void
  onRun: () => void
  onOpenRun: (runId: string) => void
  disabled: boolean
}) {
  const { t } = useTranslation()
  const run = step.last_run
  // A superseded step belongs to a release this store has already been
  // through, so it counts as done whether or not a run row exists for it —
  // most were run long before runs were recorded.
  const succeeded = superseded || run?.status === 'succeeded'
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

        {!superseded && (
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
        )}
      </div>

      {/* The manifest's own guidance: ordering constraints and caveats that
          decide whether a step is safe to run right now. */}
      {expanded && step.notes && (
        <p className="whitespace-pre-line px-10 pb-3 text-muted-foreground text-xs">{step.notes}</p>
      )}
    </div>
  )
}

function groupByBoundary(steps: UpgradeStep[]): Boundary[] {
  const boundaries: Boundary[] = []

  for (const step of steps) {
    const last = boundaries[boundaries.length - 1]

    if (last && last.from === step.from && last.to === step.to) {
      last.steps.push(step)
      // A boundary is history only when every one of its steps is.
      last.superseded = last.superseded && step.superseded
    } else {
      boundaries.push({
        from: step.from,
        to: step.to,
        steps: [step],
        superseded: step.superseded,
        docs: step.docs,
      })
    }
  }

  return boundaries
}
