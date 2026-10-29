import type { SetupTask } from '@spree/admin-sdk'
import { PageHeader, Slot, useStore } from '@spree/dashboard-core'
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
  Button,
  Card,
  Progress,
  ProgressValue,
  Skeleton,
  StepIcon,
} from '@spree/dashboard-ui'
import { createFileRoute, Link } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import '../../../components/spree/setup-tasks/register'
import {
  SETUP_TASK_LINKS,
  setupTaskCopy,
  setupTaskSlot,
} from '../../../components/spree/setup-tasks/types'

export const Route = createFileRoute('/_authenticated/$storeId/getting-started')({
  // `task` opens that step. Other params pass through: the storefront step
  // reads Vercel's `deployment-url` callback param.
  validateSearch: (
    search: Record<string, unknown>,
  ): { task?: string } & Record<string, unknown> => ({
    ...search,
    task: typeof search.task === 'string' ? search.task : undefined,
  }),
  component: GettingStartedPage,
})

function GettingStartedPage() {
  const { t } = useTranslation()
  const { store, storeId } = useStore()
  const { task: requested } = Route.useSearch()
  const [open, setOpen] = useState<string[] | null>(null)
  // A click in the sidebar while already on this page opens the new step.
  const [seen, setSeen] = useState(requested)
  if (seen !== requested) {
    setSeen(requested)
    setOpen(requested ? [requested] : null)
  }

  if (!store) {
    return (
      <div className="flex flex-col gap-4">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-40" />
        <Skeleton className="h-40" />
      </div>
    )
  }

  const tasks = store.setup_tasks ?? []
  const doneCount = tasks.filter((task) => task.done).length
  const firstPending = tasks.find((task) => !task.done)?.name

  const taskCopy = (task: SetupTask, facet: 'title' | 'description' | 'cta') =>
    setupTaskCopy(t, task.name, facet)

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.pages.getting_started.title')}
        subtitle={t('admin.pages.getting_started.description')}
      />

      {/* `flex-nowrap` overrides the component's default wrap: the caption is
          short enough to sit beside the track at any width, and wrapping it
          below leaves the bar looking orphaned. */}
      <Progress value={doneCount} max={tasks.length || 1} className="flex-nowrap gap-3">
        <ProgressValue className="order-last shrink-0">
          {() =>
            t('admin.pages.getting_started.progress', { done: doneCount, total: tasks.length })
          }
        </ProgressValue>
      </Progress>

      {/* One card holding every step, rather than a card each: this is a single
          checklist read top to bottom, and five separate frames made it read as
          five unrelated things. Opens on the requested step, or else the first
          unfinished one. */}
      <Card className="overflow-hidden py-0">
        <Accordion
          value={open ?? (requested ? [requested] : firstPending ? [firstPending] : [])}
          onValueChange={(value) => setOpen(value as string[])}
        >
          {tasks.map((task) => {
            const link = SETUP_TASK_LINKS[task.name]
            const description = taskCopy(task, 'description')
            const cta = taskCopy(task, 'cta')

            return (
              <AccordionItem key={task.name} value={task.name}>
                <AccordionTrigger>
                  <StepIcon status={task.done ? 'done' : 'todo'} className="size-5" />
                  {/* Muted once done, so a glance down the list separates what
                      is left from what is finished without reading the icons. */}
                  <span className={task.done ? 'text-muted-foreground' : undefined}>
                    {taskCopy(task, 'title')}
                  </span>
                </AccordionTrigger>
                {/* keepMounted so slot components mount even while their step is
                    collapsed — the storefront task auto-opens its sheet from the
                    Vercel callback param, which requires being mounted. */}
                <AccordionContent keepMounted className="flex flex-col items-start gap-3 ps-12">
                  <Slot
                    name={setupTaskSlot(task.name)}
                    context={{ task, store, storeId }}
                    fallback={
                      <>
                        {description && (
                          <p className="text-muted-foreground text-sm">{description}</p>
                        )}
                        {link && cta && (
                          <Button asChild variant={task.done ? 'outline' : 'default'}>
                            <Link to={link} params={{ storeId }}>
                              {cta}
                            </Link>
                          </Button>
                        )}
                      </>
                    }
                  />
                </AccordionContent>
              </AccordionItem>
            )
          })}
        </Accordion>
      </Card>
    </div>
  )
}
