import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, usePermissions } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Field,
  FieldError,
  FieldLabel,
  Input,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Skeleton,
  Textarea,
} from '@spree/dashboard-ui'
import i18n from 'i18next'
import { useEffect, useMemo } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { z } from 'zod/v4'
import { useCreateRole, usePermissionCatalog, useRole, useUpdateRole } from '../../hooks/use-roles'
import { allReadKeys, allWriteKeys, PermissionGrid } from './permission-picker'

const roleSchema = z.object({
  name: z.string().min(1, { error: () => i18n.t('admin.roles.validation.name_required') }),
  description: z.string(),
  permissions: z.array(z.string()),
})

type RoleFormValues = z.infer<typeof roleSchema>

const ROLE_DEFAULTS: RoleFormValues = { name: '', description: '', permissions: [] }

/**
 * Quick-start permission sets offered when creating a role. Dashboard
 * constants only — nothing is seeded; a template just pre-fills the grid
 * before saving.
 */
const ROLE_TEMPLATES: Array<{ key: string; permissions: string[] }> = [
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

/**
 * Create / duplicate / edit a staff role. One sheet drives all three: pass
 * `roleId` to edit, `duplicateFromId` to pre-fill a new role from an existing
 * one, or neither for a blank role.
 */
export function RoleSheet({
  open,
  roleId,
  duplicateFromId,
  onOpenChange,
}: {
  open: boolean
  roleId?: string
  duplicateFromId?: string
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: catalog } = usePermissionCatalog()
  const { permissions, permissionKeys } = usePermissions()
  const { data: role, isLoading } = useRole(roleId ?? '')
  const { data: source } = useRole(duplicateFromId ?? '')
  const createMutation = useCreateRole()
  const updateMutation = useUpdateRole()

  const form = useForm<RoleFormValues>({
    resolver: zodResolver(roleSchema),
    defaultValues: ROLE_DEFAULTS,
  })

  const isEditing = !!roleId
  // Protected roles (admin, host-locked) and callers without update authority
  // get a read-only sheet — the server enforces both independently.
  const readOnly = isEditing
    ? !role?.mutable || permissions.cannot('update', 'Spree::Role')
    : permissions.cannot('create', 'Spree::Role')

  // Populate from the edited role, or from the duplicate source.
  useEffect(() => {
    if (role) {
      form.reset({
        name: role.name,
        description: role.description ?? '',
        permissions: role.name === 'admin' ? [] : role.permissions,
      })
      return
    }
    if (source) {
      form.reset({
        name: t('admin.roles.duplicate_name', { name: source.name }),
        description: source.description ?? '',
        // Drop keys the caller cannot grant — the grid renders them disabled,
        // so carrying them over would submit a role the API rejects.
        permissions: source.permissions.filter((key) => permissionKeys.includes(key)),
      })
    }
  }, [role, source, permissionKeys, form, t])

  // Keys the current admin cannot grant (the API would reject them) render
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

  async function onSubmit(values: RoleFormValues) {
    const params = {
      name: values.name,
      description: values.description || null,
      permissions: values.permissions,
    }

    try {
      if (roleId) {
        await updateMutation.mutateAsync({ id: roleId, params })
        toast.success(t('admin.roles.messages.updated'))
      } else {
        await createMutation.mutateAsync(params)
        toast.success(t('admin.roles.messages.created'))
      }
      form.reset(ROLE_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) {
        toast.error(err.message)
        return
      }
      toast.error(t('admin.roles.errors.failed_to_save'))
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(ROLE_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle className="flex items-center gap-2">
            <span className="capitalize">
              {isEditing
                ? (role?.name ?? t('admin.pages.roles.edit_sheet_title'))
                : t('admin.pages.roles.new_title')}
            </span>
            {readOnly && <Badge variant="secondary">{t('admin.roles.badges.protected')}</Badge>}
          </SheetTitle>
          <SheetDescription>
            {readOnly ? t('admin.roles.form.locked_hint') : t('admin.roles.form.description')}
          </SheetDescription>
        </SheetHeader>

        {isEditing && isLoading ? (
          <div className="flex flex-col gap-3 p-4">
            <Skeleton className="h-9 w-full" />
            <Skeleton className="h-32 w-full" />
          </div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              {form.formState.errors.root?.message && (
                <p className="text-sm text-destructive" role="alert">
                  {form.formState.errors.root.message}
                </p>
              )}

              {!isEditing && (
                <Field>
                  <FieldLabel>{t('admin.roles.templates.start_from')}</FieldLabel>
                  <div className="flex flex-wrap gap-2">
                    {ROLE_TEMPLATES.map((template) => (
                      <Button
                        key={template.key}
                        type="button"
                        variant="outline"
                        size="sm"
                        onClick={() => {
                          applyPreset(template.permissions)
                          if (!form.getValues('name')) {
                            form.setValue('name', t(`admin.roles.templates.${template.key}`))
                          }
                        }}
                      >
                        {t(`admin.roles.templates.${template.key}`)}
                      </Button>
                    ))}
                  </div>
                </Field>
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

              <Field>
                <div className="flex items-center justify-between">
                  <FieldLabel>{t('admin.roles.form.permissions_section')}</FieldLabel>
                  {!readOnly && catalog && (
                    <div className="flex gap-1">
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        onClick={() => applyPreset(allReadKeys(catalog.data))}
                      >
                        {t('admin.roles.presets.read_only')}
                      </Button>
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        onClick={() => applyPreset(allWriteKeys(catalog.data))}
                      >
                        {t('admin.roles.presets.full_access')}
                      </Button>
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        onClick={() => applyPreset([])}
                      >
                        {t('admin.roles.presets.clear')}
                      </Button>
                    </div>
                  )}
                </div>
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
                  </div>
                )}
              </Field>
            </div>

            <SheetFooter>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                {t('admin.actions.cancel')}
              </Button>
              {!readOnly && (
                <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
                  {form.formState.isSubmitting
                    ? t('admin.actions.saving')
                    : t('admin.actions.save')}
                </Button>
              )}
            </SheetFooter>
          </form>
        )}
      </SheetContent>
    </Sheet>
  )
}
