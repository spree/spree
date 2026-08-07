import { PageHeader, usePermissions } from '@spree/dashboard-core'
import { Badge, Button, ErrorState, Skeleton } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { RoleFormFields, submitRole, useRoleForm } from '../../../../../components/spree/role-form'
import { useDeleteRole, useRole, useUpdateRole } from '../../../../../hooks/use-roles'

export const Route = createFileRoute('/_authenticated/$storeId/settings/roles/$roleId')({
  component: EditRolePage,
})

function EditRolePage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { storeId, roleId } = Route.useParams()
  const { permissions } = usePermissions()
  const { data: role, isLoading, isError } = useRole(roleId)
  const updateMutation = useUpdateRole()
  const deleteMutation = useDeleteRole()

  const form = useRoleForm()

  // Populate once the role loads (and after refetches while pristine).
  useEffect(() => {
    if (!role || form.formState.isDirty) return
    form.reset({
      name: role.name,
      description: role.description ?? '',
      permissions: role.name === 'admin' ? [] : role.permissions,
    })
  }, [role, form])

  const handleSubmit = submitRole(form, async (values) => {
    await updateMutation.mutateAsync({
      id: roleId,
      params: {
        name: values.name,
        description: values.description || null,
        permissions: values.permissions,
      },
    })
    toast.success(t('admin.roles.messages.updated'))
    form.reset(values)
  })

  async function handleDelete() {
    try {
      await deleteMutation.mutateAsync(roleId)
      toast.success(t('admin.roles.messages.deleted'))
      navigate({ to: '/$storeId/settings/roles', params: { storeId } })
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t('admin.roles.errors.failed_to_delete'))
    }
  }

  if (isError) {
    return <ErrorState />
  }

  if (isLoading || !role) {
    return (
      <div className="flex flex-col gap-4">
        <Skeleton className="h-10 w-64" />
        <Skeleton className="h-64 w-full" />
      </div>
    )
  }

  const readOnly = !role.mutable || permissions.cannot('update', 'Spree::Role')

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={<span className="capitalize">{role.name}</span>}
        subtitle={role.description ?? undefined}
        backTo={`/${storeId}/settings/roles`}
        badges={
          readOnly ? <Badge variant="secondary">{t('admin.roles.badges.protected')}</Badge> : null
        }
        resource={role}
        onDelete={
          role.mutable && role.users_count === 0 && permissions.can('destroy', 'Spree::Role')
            ? handleDelete
            : undefined
        }
        actions={
          !readOnly && (
            <Button
              size="sm"
              onClick={handleSubmit}
              disabled={form.formState.isSubmitting || !form.formState.isDirty}
            >
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          )
        }
      />

      <RoleFormFields form={form} role={role} readOnly={readOnly} />
    </div>
  )
}
