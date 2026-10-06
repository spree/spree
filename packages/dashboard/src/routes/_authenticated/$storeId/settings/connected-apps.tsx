import type { OauthApplication } from '@spree/admin-sdk'
import {
  adminClient,
  PageHeader,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import { Button, RowActions, useConfirm } from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { McpConnectSheet } from '../../../../components/spree/mcp-connect-sheet'
import { useRevokeOauthApplication } from '../../../../hooks/use-oauth'
import '../../../../tables/oauth-applications'

export const Route = createFileRoute('/_authenticated/$storeId/settings/connected-apps')({
  validateSearch: resourceSearchSchema,
  component: ConnectedAppsSettingsPage,
})

function ConnectedAppsSettingsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch()
  const confirm = useConfirm()
  const revoke = useRevokeOauthApplication()
  const { permissions } = usePermissions()
  const [connectOpen, setConnectOpen] = useState(false)

  async function handleRevoke(application: OauthApplication) {
    const ok = await confirm({
      title: t('admin.pages.settings.connected_apps.revoke_confirm.title'),
      message: t('admin.pages.settings.connected_apps.revoke_confirm.message', {
        name: application.name,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.pages.settings.connected_apps.revoke'),
    })
    if (!ok) return

    await revoke.mutateAsync(application.id).catch(() => undefined)
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.pages.settings.connected_apps.title')}
        description={t('admin.pages.settings.connected_apps.subtitle')}
        actions={
          <Button size="sm" onClick={() => setConnectOpen(true)}>
            {t('admin.mcp_connect.open_cta')}
          </Button>
        }
      />

      <McpConnectSheet open={connectOpen} onOpenChange={setConnectOpen} />

      <ResourceTable<OauthApplication>
        tableKey="oauth-applications"
        queryKey="oauth-applications"
        hideHeader
        queryFn={(params) => adminClient.oauth.applications.list(params)}
        searchParams={search}
        rowActions={(application) => (
          <RowActions
            actions={[
              {
                key: 'revoke',
                label: t('admin.pages.settings.connected_apps.revoke'),
                destructive: true,
                visible: permissions.can('update', Subject.OauthApplication),
                disabled: revoke.isPending,
                onSelect: () => handleRevoke(application),
              },
            ]}
          />
        )}
      />
    </div>
  )
}
