import { zodResolver } from '@hookform/resolvers/zod'
import type { CustomFieldDefinition } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  useCreateCustomFieldDefinitionForSettings,
  useCustomFieldDefinition,
  useDeleteCustomFieldDefinitionForSettings,
  usePermissions,
  useUpdateCustomFieldDefinitionForSettings,
} from '@spree/dashboard-core'
import {
  Button,
  RowActions,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { DefinitionFormFields } from '@/components/spree/custom-fields/definition-form'
import {
  CUSTOM_FIELD_DEFINITION_DEFAULTS,
  type CustomFieldDefinitionFormValues,
  customFieldDefinitionSchema,
  customFieldDefinitionValuesToCreateParams,
  customFieldDefinitionValuesToUpdateParams,
} from '@/schemas/custom-field-definition'
import '@/tables/custom-field-definitions'

const searchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/custom-field-definitions')({
  validateSearch: searchSchema,
  component: CustomFieldDefinitionsPage,
})

function CustomFieldDefinitionsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof searchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteCustomFieldDefinitionForSettings()
  const { permissions } = usePermissions()
  const canCreate = permissions.can('create', Subject.CustomFieldDefinition)
  const canUpdate = permissions.can('update', Subject.CustomFieldDefinition)

  // Gate by permission *before* honoring `?edit=`/`?new=` so a hand-crafted
  // URL or row-click bridge can't open a sheet whose save the server will
  // reject. Action menus also gate visibility, but deep-links bypass them.
  const editId = canUpdate ? search.edit : undefined
  const isCreating = canCreate && !!search.new

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () => {
    if (!canCreate) return
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })
  }

  const openEdit = (id: string) => {
    if (!canUpdate) return
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, edit: id }) as never })
  }

  useRowClickBridge('data-custom-field-definition-id', openEdit)

  async function handleDelete(def: CustomFieldDefinition) {
    const ok = await confirm({
      title: t('admin.custom_field_definitions.delete_confirm.title'),
      message: t('admin.custom_field_definitions.delete_confirm.message', {
        label: def.label,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(def.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<CustomFieldDefinition>
        tableKey="custom-field-definitions"
        queryKey="custom-field-definitions"
        queryFn={(params) => adminClient.customFieldDefinitions.list(params)}
        searchParams={search}
        rowActions={(def) => (
          <RowActions
            actions={[
              {
                key: 'edit',
                visible: canUpdate,
                onSelect: () => openEdit(def.id),
              },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.CustomFieldDefinition),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(def),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.CustomFieldDefinition}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.custom_field_definitions.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreateSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateCustomFieldDefinitionForSettings()
  const form = useForm<CustomFieldDefinitionFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(customFieldDefinitionSchema) as any,
    defaultValues: CUSTOM_FIELD_DEFINITION_DEFAULTS,
  })

  async function onSubmit(values: CustomFieldDefinitionFormValues) {
    try {
      await createMutation.mutateAsync(customFieldDefinitionValuesToCreateParams(values))
      form.reset(CUSTOM_FIELD_DEFINITION_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(CUSTOM_FIELD_DEFINITION_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {t('admin.pages.settings.custom_field_definitions.add_sheet_title')}
          </SheetTitle>
          <SheetDescription>
            {t('admin.custom_field_definitions.create_description')}
          </SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <DefinitionFormFields form={form} showResourceType />
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
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.custom_field_definitions.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: definition, isLoading } = useCustomFieldDefinition(id)
  const updateMutation = useUpdateCustomFieldDefinitionForSettings(id)

  const form = useForm<CustomFieldDefinitionFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(customFieldDefinitionSchema) as any,
    defaultValues: CUSTOM_FIELD_DEFINITION_DEFAULTS,
  })

  useEffect(() => {
    if (definition) {
      form.reset({
        label: definition.label,
        namespace: definition.namespace,
        key: definition.key,
        field_type: definition.field_type,
        resource_type: definition.resource_type,
        storefront_visible: definition.storefront_visible,
      })
    }
  }, [definition, form])

  async function onSubmit(values: CustomFieldDefinitionFormValues) {
    try {
      await updateMutation.mutateAsync(customFieldDefinitionValuesToUpdateParams(values))
      form.reset(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {definition?.label ??
              t('admin.pages.settings.custom_field_definitions.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>
            {t('admin.custom_field_definitions.edit_description')}
          </SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <DefinitionFormFields
                form={form}
                showResourceType
                resourceTypeReadOnly
                fieldTypeReadOnly
              />
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
              <Button
                type="submit"
                size="sm"
                disabled={form.formState.isSubmitting || !form.formState.isDirty}
              >
                {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </SheetFooter>
          </form>
        )}
      </SheetContent>
    </Sheet>
  )
}
