import type { SetupTask } from '@spree/admin-sdk'
import { PageHeader, useStore } from '@spree/dashboard-core'
import {
  Button,
  Card,
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
  Skeleton,
} from '@spree/dashboard-ui'
import { createFileRoute, Link } from '@tanstack/react-router'
import { CheckCircle2Icon, ChevronDownIcon, CircleIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  normalizeOrigin,
  StorefrontConnectSheet,
} from '@/components/spree/storefront-connect-sheet'

// CTA behavior for the built-in tasks — a settings deep-link or the
// storefront-connect sheet. Extension-registered tasks without an entry
// render without a CTA (their copy comes from the same i18n convention).
type TaskAction = { link: string } | { sheet: true }

const TASK_ACTIONS: Record<string, TaskAction> = {
  setup_payment_method: { link: '/$storeId/settings/payment-methods' },
  add_products: { link: '/$storeId/products' },
  set_customer_support_email: { link: '/$storeId/settings/emails' },
  setup_taxes_collection: { link: '/$storeId/settings/tax-categories' },
  setup_storefront: { sheet: true },
}

export const Route = createFileRoute('/_authenticated/$storeId/getting-started')({
  component: GettingStartedPage,
  // Vercel's deploy button appends callback params to its redirect-url —
  // deployment-url carries the deployed storefront's host.
  validateSearch: (search: Record<string, unknown>) => ({
    'deployment-url':
      typeof search['deployment-url'] === 'string'
        ? (search['deployment-url'] as string)
        : undefined,
  }),
})

function GettingStartedPage() {
  const { t, i18n } = useTranslation()
  const { store, storeId } = useStore()
  const { 'deployment-url': deploymentUrl } = Route.useSearch()

  // Coming back from a Vercel deploy opens the sheet with the deployed URL
  // prefilled — one click left to finish the setup.
  const deployedOrigin = deploymentUrl ? normalizeOrigin(deploymentUrl) : null
  const [sheetOpen, setSheetOpen] = useState(deployedOrigin != null)

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
    const key = `admin.getting_started.tasks.${task.name}.${facet}`
    if (i18n.exists(key)) return t(key)
    // Extension task without registered copy — humanize the name for the
    // title, skip the other facets.
    return facet === 'title' ? task.name.replace(/_/g, ' ') : null
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.getting_started.title')}
        subtitle={t('admin.getting_started.description')}
      />

      <div className="flex items-center gap-3">
        <div className="h-2 grow overflow-hidden rounded-full bg-muted">
          <div
            className="h-full rounded-full bg-primary transition-all"
            style={{ width: `${tasks.length ? (doneCount / tasks.length) * 100 : 0}%` }}
          />
        </div>
        <span className="shrink-0 text-sm text-muted-foreground">
          {t('admin.getting_started.progress', { done: doneCount, total: tasks.length })}
        </span>
      </div>

      <div className="flex flex-col gap-4">
        {tasks.map((task) => {
          const action = TASK_ACTIONS[task.name]
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
                  <span className="grow font-medium capitalize">{taskCopy(task, 'title')}</span>
                  <ChevronDownIcon className="size-4 shrink-0 text-muted-foreground transition-transform group-data-[panel-open]:rotate-180" />
                </CollapsibleTrigger>
                <CollapsibleContent>
                  <div className="flex flex-col items-start gap-3 border-t px-4 py-4 pl-12">
                    {description && <p className="text-sm text-muted-foreground">{description}</p>}
                    {action && cta && (
                      <Button
                        asChild={'link' in action}
                        variant={task.done ? 'outline' : 'default'}
                        onClick={'sheet' in action ? () => setSheetOpen(true) : undefined}
                      >
                        {'link' in action ? (
                          <Link to={action.link} params={{ storeId }}>
                            {cta}
                          </Link>
                        ) : (
                          cta
                        )}
                      </Button>
                    )}
                  </div>
                </CollapsibleContent>
              </Collapsible>
            </Card>
          )
        })}
      </div>

      <StorefrontConnectSheet
        store={store}
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        initialUrl={deployedOrigin ?? undefined}
      />
    </div>
  )
}
