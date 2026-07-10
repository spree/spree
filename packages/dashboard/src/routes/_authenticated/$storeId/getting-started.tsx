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
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  normalizeOrigin,
  StorefrontConnectSheet,
} from '@/components/spree/storefront-connect-sheet'

// Route targets for the built-in tasks. Extension-registered tasks without an
// entry here render without a CTA (their copy comes from the same i18n
// convention, so extensions ship keys + optionally patch this map via a PR).
const TASK_LINKS: Record<string, string> = {
  setup_payment_method: '/$storeId/settings/payment-methods',
  add_products: '/$storeId/products',
  set_customer_support_email: '/$storeId/settings/emails',
  setup_taxes_collection: '/$storeId/settings/tax-categories',
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
  const { store, storeId, refetch } = useStore()
  const { 'deployment-url': deploymentUrl } = Route.useSearch()

  // The provider's store snapshot goes stale while the merchant completes
  // tasks on other pages (e.g. adds a payment method) — refresh it whenever
  // they come back so the checklist and the nav badge reflect reality.
  useEffect(() => {
    void refetch()
  }, [refetch])
  // '' means the user explicitly collapsed everything; null means "no choice
  // yet", which falls back to the first pending task.
  const [expanded, setExpanded] = useState<string | null>(null)
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
  const firstPending = tasks.find((task) => !task.done)?.name ?? ''
  const expandedTask = expanded ?? firstPending

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
          const link = TASK_LINKS[task.name]
          const description = taskCopy(task, 'description')
          const cta = taskCopy(task, 'cta')
          const isOpen = expandedTask === task.name

          return (
            <Card key={task.name} className="overflow-hidden py-0">
              <Collapsible open={isOpen}>
                <CollapsibleTrigger
                  className="flex w-full cursor-pointer items-center gap-3 p-4 text-left hover:bg-muted/50"
                  onClick={() => setExpanded(isOpen ? '' : task.name)}
                >
                  {task.done ? (
                    <CheckCircle2Icon className="size-5 shrink-0 text-green-600" />
                  ) : (
                    <CircleIcon className="size-5 shrink-0 text-muted-foreground" />
                  )}
                  <span className="grow font-medium capitalize">{taskCopy(task, 'title')}</span>
                  <ChevronDownIcon
                    className={`size-4 shrink-0 text-muted-foreground transition-transform ${isOpen ? 'rotate-180' : ''}`}
                  />
                </CollapsibleTrigger>
                <CollapsibleContent>
                  <div className="flex flex-col items-start gap-3 border-t px-4 py-4 pl-12">
                    {description && <p className="text-sm text-muted-foreground">{description}</p>}
                    {task.name === 'setup_storefront' ? (
                      <Button
                        variant={task.done ? 'outline' : 'default'}
                        onClick={() => setSheetOpen(true)}
                      >
                        {cta}
                      </Button>
                    ) : (
                      link &&
                      cta && (
                        <Button asChild variant={task.done ? 'outline' : 'default'}>
                          <Link to={link} params={{ storeId }}>
                            {cta}
                          </Link>
                        </Button>
                      )
                    )}
                  </div>
                </CollapsibleContent>
              </Collapsible>
            </Card>
          )
        })}
      </div>

      <StorefrontConnectSheet
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        initialUrl={deployedOrigin ?? undefined}
      />
    </div>
  )
}
