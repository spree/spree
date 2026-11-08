import {
  adminClient,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Empty,
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { RunDetailSheet } from '../../../../components/spree/maintenance-tasks/run-detail-sheet'
import { UpgradePanel } from '../../../../components/spree/maintenance-tasks/upgrade-panel'
import { useUpgradeSteps } from '../../../../hooks/use-maintenance-tasks'
import '../../../../tables/maintenance-task-runs'

// The page shares its URL with the run-history `<ResourceTable>`; `run` is the
// prefixed ID of the run whose detail sheet is open, so a run in progress can
// be linked to and survives a reload.
const searchSchema = resourceSearchSchema.extend({
  run: z.string().optional(),
  tab: z.enum(['upgrade', 'history']).optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/maintenance-tasks')({
  validateSearch: searchSchema,
  component: MaintenanceTasksRoute,
})

// The settings entry is hidden without access, but a bookmark still lands
// here — including on an installation that turned maintenance tasks off,
// where every request would be refused.
function MaintenanceTasksRoute() {
  const { t } = useTranslation()
  const { permissions } = usePermissions()

  if (permissions.can('read', Subject.MaintenanceTaskRun)) return <MaintenanceTasksPage />

  return (
    <div className="flex flex-col gap-6">
      <PageHeader />
      <Empty>{t('admin.maintenance_tasks.unavailable')}</Empty>
    </div>
  )
}

function PageHeader() {
  const { t } = useTranslation()

  return (
    <header className="flex flex-col gap-1">
      <h1 className="font-semibold text-2xl">{t('admin.maintenance_tasks.title')}</h1>
      <p className="text-muted-foreground text-sm">{t('admin.maintenance_tasks.description')}</p>
    </header>
  )
}

function MaintenanceTasksPage() {
  const { t } = useTranslation()
  const navigate = useNavigate({ from: Route.fullPath })
  const search = Route.useSearch()
  const openRunId = search.run

  const { data: upgradeData } = useUpgradeSteps()

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
  // run sheet.
  useRowClickBridge('data-maintenance-task-run-id', openRun)

  // Steps still outstanding — what the Upgrade tab is counting.
  const pendingUpgradeSteps = (upgradeData?.data ?? []).filter((step) => !step.superseded)

  return (
    <div className="flex flex-col gap-6">
      <PageHeader />

      <Tabs
        value={search.tab ?? 'upgrade'}
        onValueChange={(value) =>
          navigate({
            search: (previous: Record<string, unknown>) => ({ ...previous, tab: value }),
            replace: true,
          })
        }
      >
        <TabsList>
          <TabsTrigger value="upgrade" count={pendingUpgradeSteps.length || undefined}>
            {t('admin.maintenance_tasks.tabs.upgrade')}
          </TabsTrigger>
          <TabsTrigger value="history">{t('admin.maintenance_tasks.tabs.history')}</TabsTrigger>
        </TabsList>

        <TabsContent value="upgrade">
          <UpgradePanel onOpenRun={openRun} />
        </TabsContent>

        {/* Kept mounted so the run table's loaded page, scroll position and
            polling survive a tab switch. */}
        <TabsContent value="history" keepMounted>
          <ResourceTable
            tableKey="maintenance-task-runs"
            queryKey="maintenance-task-runs"
            queryFn={(params) =>
              adminClient.maintenanceTaskRuns.list({
                ...(params as Record<string, unknown>),
                expand: ['admin_user'],
              })
            }
            searchParams={search}
            hideHeader
          />
        </TabsContent>
      </Tabs>

      <RunDetailSheet
        runId={openRunId}
        open={!!openRunId}
        onOpenChange={(open) => !open && openRun(undefined)}
      />
    </div>
  )
}
