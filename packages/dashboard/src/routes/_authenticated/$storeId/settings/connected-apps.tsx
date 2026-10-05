import type { OauthApplication } from '@spree/admin-sdk'
import { PageHeader, Subject, usePermissions } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
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
  const { t, i18n } = useTranslation()
  const confirm = useConfirm()
  const { data, isLoading } = useOauthApplications()
  const revoke = useRevokeOauthApplication()
  const { permissions } = usePermissions()

  const applications = data ?? []
  const canRevoke = permissions.can('update', Subject.Store)

  const formatDate = (value: string | null) =>
    value ? new Date(value).toLocaleDateString(i18n.language) : '—'

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
                      {formatDate(application.last_used_at)}
                    </TableCell>
                    <TableCell className="text-right">
                      {canRevoke ? (
                        <Button
                          variant="ghost"
                          size="sm"
                          disabled={revoke.isPending}
                          onClick={() => handleRevoke(application)}
                        >
                          {t('admin.pages.settings.connected_apps.revoke')}
                        </Button>
                      ) : null}
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
