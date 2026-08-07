import { zodResolver } from '@hookform/resolvers/zod'
import type { Role } from '@spree/admin-sdk'
import { SpreeError } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, usePermissions } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
  Skeleton,
  Textarea,
} from '@spree/dashboard-ui'
import i18n from 'i18next'
import { LockIcon } from 'lucide-react'
import { useMemo } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { z } from 'zod/v4'
import { usePermissionCatalog } from '../../hooks/use-roles'
import { useStaff } from '../../hooks/use-staff'
import { allReadKeys, allWriteKeys, PermissionGrid } from './permission-picker'

const roleSchema = z.object({
  name: z.string().min(1, { error: () => i18n.t('admin.roles.validation.name_required') }),
  description: z.string(),
  permissions: z.array(z.string()),
})

export type RoleFormValues = z.infer<typeof roleSchema>

/**
 * Quick-start permission sets offered on the create page. Dashboard constants
 * only — nothing is seeded; a template just pre-fills the grid before saving.
 */
export const ROLE_TEMPLATES: Array<{ key: string; permissions: string[] }> = [
  {
    key: 'order_manager',
    permissions: [
      'write_orders',
      'write_payments',
      'write_fulfillments',
      'write_refunds',
      'write_gift_cards',
      'write_store_credits',
      'read_customers',
    ],
  },
  {
    key: 'merchandiser',
    permissions: ['write_products', 'write_categories', 'write_collections', 'write_stock'],
  },
  {
    key: 'support',
    permissions: ['read_orders', 'read_customers', 'read_dashboard'],
  },
]

export function useRoleForm(initial?: Partial<RoleFormValues>) {
  return useForm<RoleFormValues>({
    resolver: zodResolver(roleSchema),
    defaultValues: {
      name: initial?.name ?? '',
      description: initial?.description ?? '',
      permissions: initial?.permissions ?? [],
    },
  })
}

/** Wraps a submit handler with the standard 422 → form-error mapping. */
export function submitRole(
  form: ReturnType<typeof useRoleForm>,
  action: (values: RoleFormValues) => Promise<void>,
) {
  return form.handleSubmit(async (values) => {
    try {
      await action(values)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) {
        toast.error(err.message)
        return
      }
      throw err
    }
  })
}

/**
 * The role editor body — name/description, the permission grid with presets,
 * and the summary sidebar. Shared by the create and edit pages; the pages own
 * the header, submit wiring, and navigation.
 */
export function RoleFormFields({
  form,
  role,
  readOnly = false,
}: {
  form: ReturnType<typeof useRoleForm>
  /** Present on the edit page — drives the members panel and immutable state. */
  role?: Role
  readOnly?: boolean
}) {
  const { t } = useTranslation()
  const { data: catalog } = usePermissionCatalog()
  const { permissionKeys } = usePermissions()
  const permissions = form.watch('permissions')

  // Keys the current admin cannot grant (the API rejects them) render
  // disabled. An admin holding the full catalog is never restricted.
  const blockedKeys = useMemo(() => {
    if (!catalog) return undefined
    const blocked = new Set(
      catalog.data.filter((entry) => !permissionKeys.includes(entry.key)).map((entry) => entry.key),
    )
    return blocked.size > 0 ? blocked : undefined
  }, [catalog, permissionKeys])

  function applyPreset(keys: string[]) {
    form.setValue(
      'permissions',
      keys.filter((key) => permissionKeys.includes(key)),
      { shouldDirty: true },
    )
  }

  return (
    <div className="flex flex-col gap-6 lg:flex-row">
      <div className="flex min-w-0 flex-1 flex-col gap-6">
        <Card>
          <CardHeader>
            <CardTitle>{t('admin.roles.form.details_section')}</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col gap-4">
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}
            <Field>
              <FieldLabel htmlFor="role-name">{t('admin.fields.role.name.label')}</FieldLabel>
              <Input
                id="role-name"
                placeholder={t('admin.fields.role.name.placeholder')}
                disabled={readOnly}
                aria-invalid={!!form.formState.errors.name || undefined}
                {...form.register('name')}
              />
              <FieldError errors={[form.formState.errors.name]} />
            </Field>
            <Field>
              <FieldLabel htmlFor="role-description">
                {t('admin.fields.role.description.label')}
              </FieldLabel>
              <Textarea
                id="role-description"
                rows={2}
                placeholder={t('admin.fields.role.description.placeholder')}
                disabled={readOnly}
                {...form.register('description')}
              />
            </Field>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle>{t('admin.roles.form.permissions_section')}</CardTitle>
            {!readOnly && catalog && (
              <div className="flex gap-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => applyPreset(allReadKeys(catalog.data))}
                >
                  {t('admin.roles.presets.read_only')}
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => applyPreset(allWriteKeys(catalog.data))}
                >
                  {t('admin.roles.presets.full_access')}
                </Button>
                <Button type="button" variant="ghost" size="sm" onClick={() => applyPreset([])}>
                  {t('admin.roles.presets.clear')}
                </Button>
              </div>
            )}
          </CardHeader>
          <CardContent>
            {catalog ? (
              <Controller
                name="permissions"
                control={form.control}
                render={({ field }) => (
                  <PermissionGrid
                    entries={catalog.data}
                    value={field.value}
                    onChange={field.onChange}
                    disabled={readOnly}
                    disabledKeys={blockedKeys}
                  />
                )}
              />
            ) : (
              <div className="flex flex-col gap-2">
                <Skeleton className="h-8 w-full" />
                <Skeleton className="h-8 w-full" />
                <Skeleton className="h-8 w-full" />
              </div>
            )}
            {form.formState.errors.permissions && (
              <p className="mt-2 text-sm text-destructive">
                {form.formState.errors.permissions.message}
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      <div className="flex w-full flex-col gap-6 lg:w-72">
        <Card>
          <CardHeader>
            <CardTitle>{t('admin.roles.form.summary_section')}</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col gap-3 text-sm">
            {readOnly && (
              <p className="flex items-start gap-2 text-muted-foreground">
                <LockIcon className="mt-0.5 size-4 shrink-0" />
                {t('admin.roles.form.locked_hint')}
              </p>
            )}
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">
                {t('admin.roles.form.permissions_count')}
              </span>
              <Badge>
                {role?.name === 'admin' ? t('admin.roles.badges.full_access') : permissions.length}
              </Badge>
            </div>
            {role && <RoleMembers role={role} />}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

function RoleMembers({ role }: { role: Role }) {
  const { t } = useTranslation()
  const { data: staff } = useStaff()

  const members = (staff?.data ?? []).filter((member) =>
    member.roles.some((memberRole) => memberRole.id === role.id),
  )

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <span className="text-muted-foreground">{t('admin.roles.form.members')}</span>
        <Badge variant="secondary">{role.users_count}</Badge>
      </div>
      {members.length > 0 && (
        <ul className="flex flex-col gap-1">
          {members.slice(0, 8).map((member) => (
            <li key={member.id} className="truncate text-muted-foreground">
              {member.full_name || member.email}
            </li>
          ))}
          {members.length > 8 && (
            <li className="text-xs text-muted-foreground">
              {t('admin.roles.form.more_members', { count: members.length - 8 })}
            </li>
          )}
        </ul>
      )}
    </div>
  )
}
