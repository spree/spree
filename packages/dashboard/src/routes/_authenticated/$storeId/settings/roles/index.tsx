import type { Role } from '@spree/admin-sdk'
import { PageHeader, usePermissions } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
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
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { CopyIcon, LockIcon, PlusIcon, ShieldIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useDeleteRole, useRoles } from '../../../../../hooks/use-roles'

export const Route = createFileRoute('/_authenticated/$storeId/settings/roles/')({
  component: RolesSettingsPage,
})

function RolesSettingsPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { storeId } = Route.useParams()
  const { data, isLoading } = useRoles()
  const roles = data?.data ?? []

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.pages.roles.title')}
        subtitle={t('admin.pages.roles.subtitle')}
        actions={
          <Button
            size="sm"
            onClick={() => navigate({ to: '/$storeId/settings/roles/new', params: { storeId } })}
          >
            <PlusIcon className="size-4" />
            {t('admin.pages.roles.add_cta')}
          </Button>
        }
      />

      <Card>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex flex-col gap-3 p-4">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </div>
          ) : roles.length === 0 ? (
            <Empty>
              <EmptyHeader>
                <EmptyMedia variant="icon">
                  <ShieldIcon />
                </EmptyMedia>
                <EmptyTitle>{t('admin.pages.roles.empty')}</EmptyTitle>
                <EmptyDescription>{t('admin.pages.roles.empty_description')}</EmptyDescription>
              </EmptyHeader>
            </Empty>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.pages.roles.table.role')}</TableHead>
                  <TableHead>{t('admin.pages.roles.table.permissions')}</TableHead>
                  <TableHead>{t('admin.pages.roles.table.members')}</TableHead>
                  <TableHead className="w-12" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {roles.map((role) => (
                  <RoleRow key={role.id} role={role} />
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

function RoleRow({ role }: { role: Role }) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { storeId } = Route.useParams()
  const { permissions } = usePermissions()
  const deleteMutation = useDeleteRole()
  const confirm = useConfirm()

  function openEditor() {
    navigate({
      to: '/$storeId/settings/roles/$roleId',
      params: { storeId, roleId: role.id },
    })
  }

  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.roles.confirm.delete_title'),
      message: t('admin.roles.confirm.delete_message', { name: role.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return

    try {
      await deleteMutation.mutateAsync(role.id)
      toast.success(t('admin.roles.messages.deleted'))
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t('admin.roles.errors.failed_to_delete'))
    }
  }

  return (
    <TableRow className="cursor-pointer" onClick={openEditor}>
      <TableCell>
        <div className="flex flex-col">
          <span className="flex items-center gap-1.5 font-medium capitalize">
            {role.name}
            {!role.mutable && <LockIcon className="size-3.5 text-muted-foreground" />}
          </span>
          {role.description && (
            <span className="text-xs text-muted-foreground">{role.description}</span>
          )}
        </div>
      </TableCell>
      <TableCell>
        <PermissionSummary role={role} />
      </TableCell>
      <TableCell>
        <Badge variant="secondary">{role.users_count}</Badge>
      </TableCell>
      <TableCell className="text-right" onClick={(event) => event.stopPropagation()}>
        <RowActions
          actions={[
            { key: 'edit', onSelect: openEditor },
            {
              key: 'duplicate',
              label: t('admin.actions.duplicate'),
              icon: <CopyIcon className="size-4" />,
              onSelect: () =>
                navigate({
                  to: '/$storeId/settings/roles/new',
                  params: { storeId },
                  search: { from: role.id },
                }),
            },
            {
              key: 'delete',
              label: t('admin.actions.delete'),
              destructive: true,
              disabled:
                !role.mutable ||
                role.users_count > 0 ||
                deleteMutation.isPending ||
                permissions.cannot('destroy', 'Spree::Role'),
              onSelect: handleDelete,
            },
          ]}
        />
      </TableCell>
    </TableRow>
  )
}

// Mirrors the API-keys page's scope badges: a compact preview with overflow.
const PERMISSION_PREVIEW_COUNT = 3

function PermissionSummary({ role }: { role: Role }) {
  const { t } = useTranslation()

  if (role.name === 'admin') {
    return <Badge>{t('admin.roles.badges.full_access')}</Badge>
  }
  if (role.permissions.length === 0) {
    return <span className="text-sm text-muted-foreground">{t('admin.roles.badges.none')}</span>
  }

  const preview = role.permissions.slice(0, PERMISSION_PREVIEW_COUNT)
  const overflow = role.permissions.length - preview.length
  return (
    <div className="flex flex-wrap items-center gap-1">
      {preview.map((key) => (
        <Badge key={key} className="font-mono text-[10px]">
          {key}
        </Badge>
      ))}
      {overflow > 0 && (
        <span className="text-xs text-muted-foreground">
          {t('admin.roles.badges.more', { count: overflow })}
        </span>
      )}
    </div>
  )
}
