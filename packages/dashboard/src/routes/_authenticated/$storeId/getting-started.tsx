import type { SetupTask } from '@spree/admin-sdk'
import { PageHeader, Slot, useStore } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardTitle,
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
  Progress,
  ProgressValue,
  Skeleton,
} from '@spree/dashboard-ui'
import { createFileRoute, Link } from '@tanstack/react-router'
import { CheckCircle2Icon, ChevronDownIcon, CircleIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import '../../../components/spree/setup-tasks/register'
import { setupTaskSlot } from '../../../components/spree/setup-tasks/types'

// Settings deep-links for the tasks whose default card body (copy + CTA
// button) suffices. Tasks needing real UI register a slot component under
// `getting-started.task.<name>` instead — see setup-tasks/register.ts.
const TASK_LINKS: Record<string, string> = {
  setup_payment_method: '/$storeId/settings/payment-methods',
  add_products: '/$storeId/products',
  set_customer_support_email: '/$storeId/settings/emails',
  // setup_taxes_collection has no CTA yet: the task completes on a TaxRate
  // existing, and the dashboard has no tax-rates surface to deep-link — add
  // one here when that settings page lands.
}

export const Route = createFileRoute('/_authenticated/$storeId/getting-started')({
  component: GettingStartedPage,
})

function GettingStartedPage() {
  const { t } = useTranslation()
  const { store, storeId } = useStore()

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

  const taskCopy = (task: SetupTask, facet: 'title' | 'description' | 'cta') => {
    // Extension tasks without registered copy fall back to a humanized name
    // for the title and render no description/CTA. Going through defaultValue
    // keeps the lookup inside i18next, so copy registered later (e.g. by a
    // plugin locale bundle) wins without a code change.
    const humanized = task.name.replace(/_/g, ' ').replace(/^./, (c) => c.toUpperCase())
    const fallback = facet === 'title' ? humanized : ''
    return (
      t(`admin.pages.getting_started.tasks.${task.name}.${facet}`, { defaultValue: fallback }) ||
      null
    )
  }

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

      <div className="flex flex-col gap-4">
        {tasks.map((task) => {
          const link = TASK_LINKS[task.name]
          const description = taskCopy(task, 'description')
          const cta = taskCopy(task, 'cta')

          return (
            <Card key={task.name} className="overflow-hidden py-0">
              <Collapsible defaultOpen={task.name === firstPending}>
                <CollapsibleTrigger className="group flex w-full cursor-pointer items-center gap-3 p-4 text-left hover:bg-muted/50">
                  {task.done ? (
                    <CheckCircle2Icon className="size-5 shrink-0 text-green-600" />
                  ) : (
                    <CircleIcon className="size-5 shrink-0 text-muted-foreground" />
                  )}
                  <CardTitle className="grow">{taskCopy(task, 'title')}</CardTitle>
                  <ChevronDownIcon className="size-4 shrink-0 text-muted-foreground transition-transform group-data-[panel-open]:rotate-180" />
                </CollapsibleTrigger>
                {/* keepMounted so slot components mount even while their card is
                    collapsed — the storefront task auto-opens its sheet from the
                    Vercel callback param, which requires being mounted. */}
                <CollapsibleContent keepMounted>
                  <div className="flex flex-col items-start gap-3 border-t px-4 py-4 pl-12">
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
                  </div>
                </CollapsibleContent>
              </Collapsible>
            </Card>
          )
        })}
      </div>
    </div>
  )
}
