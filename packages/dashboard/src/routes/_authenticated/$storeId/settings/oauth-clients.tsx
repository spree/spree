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
import { OauthApplicationSheet } from '../../../../components/spree/oauth-application-sheet'
import { useDeleteOauthApplication } from '../../../../hooks/use-oauth'
import '../../../../tables/oauth-clients'

export const Route = createFileRoute('/_authenticated/$storeId/settings/oauth-clients')({
  validateSearch: resourceSearchSchema,
  component: OauthClientsSettingsPage,
})

/**
 * The developer's surface: the OAuth client registrations themselves.
 *
 * Connected agents answers "what did someone connect, and how do I stop it".
 * This answers "what clients exist and how is one configured" — the client
 * id and callback a developer needs, which a merchant never does.
 */
function OauthClientsSettingsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch()
  const confirm = useConfirm()
  const remove = useDeleteOauthApplication()
  const { permissions } = usePermissions()
  const [editing, setEditing] = useState<OauthApplication | undefined>()
  const [formOpen, setFormOpen] = useState(false)

  function openForm(client?: OauthApplication) {
    setEditing(client)
    setFormOpen(true)
  }

  async function handleDelete(client: OauthApplication) {
    const ok = await confirm({
      title: t('admin.pages.settings.oauth_clients.delete_confirm.title'),
      message: t('admin.pages.settings.oauth_clients.delete_confirm.message', {
        name: client.name,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.common.delete'),
    })
    if (!ok) return

    await remove.mutateAsync(client.id).catch(() => undefined)
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.pages.settings.oauth_clients.title')}
        description={t('admin.pages.settings.oauth_clients.subtitle')}
        actions={
          permissions.can('update', Subject.OauthApplication) ? (
            <Button size="sm" onClick={() => openForm()}>
              {t('admin.pages.settings.oauth_clients.register')}
            </Button>
          ) : undefined
        }
      />

      <OauthApplicationSheet
        application={editing}
        open={formOpen}
        onOpenChange={(next) => {
          setFormOpen(next)
          if (!next) setEditing(undefined)
        }}
      />

      <ResourceTable<OauthApplication>
        tableKey="oauth-clients"
        queryKey="oauth-applications"
        hideHeader
        queryFn={(params) => adminClient.oauth.applications.list(params)}
        searchParams={search}
        rowActions={(client) => (
          <RowActions
            actions={[
              {
                key: 'edit',
                label: t('admin.common.edit'),
                visible: permissions.can('update', Subject.OauthApplication),
                onSelect: () => openForm(client),
              },
              {
                key: 'delete',
                label: t('admin.common.delete'),
                destructive: true,
                visible: permissions.can('destroy', Subject.OauthApplication),
                disabled: remove.isPending,
                onSelect: () => handleDelete(client),
              },
            ]}
          />
        )}
      />
    </div>
  )
}
