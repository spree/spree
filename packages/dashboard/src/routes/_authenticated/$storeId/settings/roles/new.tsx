import { PageHeader } from '@spree/dashboard-core'
import { Button } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { z } from 'zod/v4'
import {
  ROLE_TEMPLATES,
  RoleFormFields,
  submitRole,
  useRoleForm,
} from '../../../../../components/spree/role-form'
import { useCreateRole, useRole } from '../../../../../hooks/use-roles'

// `from` carries the prefixed ID of a role being duplicated — the form
// prefills with its name and permissions once it loads.
const newRoleSearchSchema = z.object({
  from: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/roles/new')({
  validateSearch: newRoleSearchSchema,
  component: NewRolePage,
})

function NewRolePage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { storeId } = Route.useParams()
  const { from } = Route.useSearch()
  const { data: sourceRole } = useRole(from ?? '')
  const createMutation = useCreateRole()

  const form = useRoleForm()

  // Duplicate flow: prefill once the source role arrives. Guarded on a
  // pristine form so a user's in-progress edits are never clobbered.
  useEffect(() => {
    if (!sourceRole || form.formState.isDirty) return
    form.reset({
      name: t('admin.roles.duplicate_name', { name: sourceRole.name }),
      description: sourceRole.description ?? '',
      permissions: sourceRole.permissions,
    })
  }, [sourceRole, form, t])

  const handleSubmit = submitRole(form, async (values) => {
    await createMutation.mutateAsync({
      name: values.name,
      description: values.description || null,
      permissions: values.permissions,
    })
    toast.success(t('admin.roles.messages.created'))
    navigate({ to: '/$storeId/settings/roles', params: { storeId } })
  })

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.pages.roles.new_title')}
        backTo={`/${storeId}/settings/roles`}
        actions={
          <Button size="sm" onClick={handleSubmit} disabled={form.formState.isSubmitting}>
            {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
          </Button>
        }
      />

      {!from && (
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-sm text-muted-foreground">
            {t('admin.roles.templates.start_from')}
          </span>
          {ROLE_TEMPLATES.map((template) => (
            <Button
              key={template.key}
              type="button"
              variant="outline"
              size="sm"
              onClick={() => {
                form.setValue('permissions', template.permissions, { shouldDirty: true })
                if (!form.getValues('name')) {
                  form.setValue('name', t(`admin.roles.templates.${template.key}`))
                }
              }}
            >
              {t(`admin.roles.templates.${template.key}`)}
            </Button>
          ))}
        </div>
      )}

      <RoleFormFields form={form} />
    </div>
  )
}
