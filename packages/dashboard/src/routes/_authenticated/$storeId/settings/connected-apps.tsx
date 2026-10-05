import type { OauthApplication } from '@spree/admin-sdk'
import { PageHeader, Subject, usePermissions } from '@spree/dashboard-core'
import {
  Badge,
  Card,
  CardContent,
  RelativeTime,
  RowActions,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { useOauthApplications, useRevokeOauthApplication } from '../../../../hooks/use-oauth'

export const Route = createFileRoute('/_authenticated/$storeId/settings/connected-apps')({
  component: ConnectedAppsSettingsPage,
})

function ConnectedAppsSettingsPage() {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { data, isLoading } = useOauthApplications()
  const revoke = useRevokeOauthApplication()
  const { permissions } = usePermissions()

  const applications = data?.data ?? []
  const canRevoke = permissions.can('update', Subject.Store)

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
      />

      <Card>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex flex-col gap-3 p-6">
              <Skeleton className="h-4 w-full" />
              <Skeleton className="h-4 w-2/3" />
            </div>
          ) : applications.length === 0 ? (
            <p className="p-6 text-muted-foreground text-sm">
              {t('admin.pages.settings.connected_apps.empty')}
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.pages.settings.connected_apps.table.name')}</TableHead>
                  <TableHead>{t('admin.pages.settings.connected_apps.table.access')}</TableHead>
                  <TableHead>{t('admin.pages.settings.connected_apps.table.last_used')}</TableHead>
                  <TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {applications.map((application) => (
                  <TableRow key={application.id}>
                    <TableCell className="font-medium">{application.name}</TableCell>
                    <TableCell>
                      <div className="flex flex-wrap gap-1">
                        {application.scopes.length === 0 ? (
                          <span className="text-muted-foreground text-sm">—</span>
                        ) : (
                          application.scopes.map((scope) => (
                            <Badge key={scope} variant="secondary">
                              {scope}
                            </Badge>
                          ))
                        )}
                      </div>
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      <RelativeTime iso={application.last_used_at} />
                    </TableCell>
                    <TableCell className="text-right">
                      <RowActions
                        actions={[
                          {
                            key: 'revoke',
                            label: t('admin.pages.settings.connected_apps.revoke'),
                            destructive: true,
                            visible: canRevoke,
                            disabled: revoke.isPending,
                            onSelect: () => handleRevoke(application),
                          },
                        ]}
                      />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
