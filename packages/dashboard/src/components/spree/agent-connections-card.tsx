import type { OauthAccessToken, OauthApplication } from '@spree/admin-sdk'
import { getInitials, Subject, usePermissions } from '@spree/dashboard-core'
import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  Badge,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  RelativeTime,
  RowActions,
  Table,
  TableBody,
  TableCell,
  TableEmpty,
  TableHead,
  TableHeader,
  TableHeaderRow,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'
import { useOauthApplicationTokens, useRevokeOauthToken } from '../../hooks/use-oauth'
import { ScopeList } from './api-keys/api-key-table'

interface AgentConnectionsCardProps {
  application: OauthApplication
}

/**
 * One agent and the people connected through it.
 *
 * A store registers an agent once and every staff member connects to that
 * same registration, so permissions belong to each person's connection
 * rather than to the agent — listing them per person is the only way a
 * merchant can see who holds what, and revoke one without the rest.
 */
export function AgentConnectionsCard({ application }: AgentConnectionsCardProps) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const { data, isLoading } = useOauthApplicationTokens(application.id)

  const connections = data?.data ?? []
  const canRevoke = permissions.can('update', Subject.OauthApplication)

  return (
    <Card>
      <CardHeader>
        {/* The count rides in the title rather than a description, so the
            header stays one row and the actions menu sits beside the name
            instead of dropping below it. */}
        <CardTitle>
          {application.name}
          <Badge variant="outline">{connections.length}</Badge>
        </CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <Table>
          <TableHeader>
            <TableHeaderRow>
              <TableHead>{t('admin.pages.settings.ai_agents.connections.person')}</TableHead>
              <TableHead>{t('admin.pages.settings.ai_agents.table.access')}</TableHead>
              <TableHead>{t('admin.pages.settings.ai_agents.connections.connected')}</TableHead>
              <TableHead className="w-12" />
            </TableHeaderRow>
          </TableHeader>
          <TableBody>
            {connections.length === 0 && !isLoading && (
              <TableEmpty colSpan={4}>
                {t('admin.pages.settings.ai_agents.connections.empty')}
              </TableEmpty>
            )}
            {connections.map((connection) => (
              <ConnectionRow
                key={connection.id}
                application={application}
                connection={connection}
                canRevoke={canRevoke}
              />
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  )
}

interface ConnectionRowProps {
  application: OauthApplication
  connection: OauthAccessToken
  canRevoke: boolean
}

function ConnectionRow({ application, connection, canRevoke }: ConnectionRowProps) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const revoke = useRevokeOauthToken(application.id)

  const owner = connection.owner
  const name =
    owner?.full_name ||
    owner?.email ||
    t('admin.pages.settings.ai_agents.connections.unknown_person')
  const who = owner?.email ?? name

  async function handleRevoke() {
    const ok = await confirm({
      title: t('admin.pages.settings.ai_agents.revoke_confirm.title'),
      message: t('admin.pages.settings.ai_agents.revoke_confirm.message', {
        name: application.name,
        who,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.pages.settings.ai_agents.revoke'),
    })
    if (!ok) return

    await revoke.mutateAsync(connection.id).catch(() => undefined)
  }

  return (
    <TableRow>
      <TableCell>
        <div className="flex items-center gap-3">
          <Avatar className="size-8">
            {owner?.avatar_url && <AvatarImage src={owner.avatar_url} alt="" />}
            <AvatarFallback className="bg-muted text-xs">
              {getInitials(owner?.full_name, owner?.email ?? '?')}
            </AvatarFallback>
          </Avatar>
          <div className="flex flex-col leading-tight">
            <span className="font-medium text-foreground">{name}</span>
            {owner?.full_name && owner.email && (
              <span className="text-muted-foreground text-xs">{owner.email}</span>
            )}
          </div>
        </div>
      </TableCell>
      <TableCell>
        <ScopeList scopes={connection.scopes} previewCount={2} />
      </TableCell>
      <TableCell className="text-muted-foreground text-sm">
        <RelativeTime iso={connection.created_at} />
      </TableCell>
      <TableCell className="text-right">
        {canRevoke && (
          <RowActions
            actions={[
              {
                key: 'revoke',
                label: t('admin.pages.settings.ai_agents.revoke'),
                destructive: true,
                disabled: revoke.isPending,
                onSelect: handleRevoke,
              },
            ]}
          />
        )}
      </TableCell>
    </TableRow>
  )
}
