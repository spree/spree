import { adminClient, Can, mapSpreeErrorsToForm, ResourceTable, Subject, usePermissions } from '@spree/dashboard-core'
import {
  Button,
  Checkbox,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
  Sheet,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Textarea,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  useCreateZone,
  useDeleteZone,
  useZone,
  useZones,
  useUpdateZone,
  useCountries,
} from '@/hooks/use-zones'

const zonesSearchSchema = z.object({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
  q: z.string().optional(),
  page: z.coerce.number().optional(),
  limit: z.coerce.number().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/zones')({
  validateSearch: zonesSearchSchema,
  component: ZonesPage,
})

function ZonesPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof zonesSearchSchema>
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const confirm = useConfirm()
  const deleteMutation = useDeleteZone()
  const { permissions } = usePermissions()

  const editId = search.edit
  const isCreating = !!search.new

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  const openEdit = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, edit: id }) as never })

  useRowClickBridge('data-zone-id', openEdit)

  async function handleDelete(zone: { id: string; name: string }) {
    const ok = await confirm({
      title: t('admin.zones.delete_confirm.title'),
      message: t('admin.zones.delete_confirm.message', { name: zone.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(zone.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable
        tableKey="zones"
        queryKey="zones"
        queryFn={(params) => adminClient.request('GET', '/zones', { params: { ...params, per_page: 100 } })}
        searchParams={search}
        rowActions={(zone) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(zone.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.Zone),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(zone),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.Zone}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.zones.add_cta', 'New Zone')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateZoneSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditZoneSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreateZoneSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateZone()
  const { data: countriesResponse } = useCountries()
  const countries = countriesResponse?.data ?? []
  const form = useForm({
    defaultValues: { name: '', description: '', default_tax: false },
  })

  async function onSubmit(values: Record<string, unknown>) {
    try {
      await createMutation.mutateAsync(values)
      form.reset()
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset()
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.zones.new', 'New Zone')}</SheetTitle>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="name">{t('admin.zones.name', 'Name')}</FieldLabel>
                <Input id="name" autoFocus {...form.register('name', { required: true })} />
                <FieldError errors={[form.formState.errors.name]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="description">{t('admin.zones.description', 'Description')}</FieldLabel>
                <Textarea id="description" {...form.register('description')} />
                <FieldError errors={[form.formState.errors.description]} />
              </Field>

              <Field>
                <div className="flex items-center gap-2">
                  <Controller
                    name="default_tax"
                    control={form.control}
                    render={({ field }) => (
                      <Checkbox id="default_tax" checked={!!field.value} onCheckedChange={field.onChange} />
                    )}
                  />
                  <FieldLabel htmlFor="default_tax" className="cursor-pointer mb-0">
                    {t('admin.zones.default_tax', 'Default Tax Zone')}
                  </FieldLabel>
                </div>
              </Field>
            </FieldGroup>
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
              {form.formState.isSubmitting ? t('admin.actions.creating') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditZoneSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: zone, isLoading } = useZone(id)
  const updateMutation = useUpdateZone()
  const { data: countriesResponse } = useCountries()
  const countries = countriesResponse?.data ?? []
  const form = useForm({
    defaultValues: { name: '', description: '', default_tax: false },
  })

  useEffect(() => {
    if (zone) {
      form.reset({
        name: zone.name,
        description: zone.description,
        default_tax: zone.default_tax,
      })
    }
  }, [zone, form])

  async function onSubmit(values: Record<string, unknown>) {
    try {
      await updateMutation.mutateAsync({
        id,
        ...values,
      })
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
          <SheetTitle>{zone?.name ?? t('admin.zones.edit', 'Edit Zone')}</SheetTitle>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              {form.formState.errors.root?.message && (
                <p className="text-sm text-destructive" role="alert">
                  {form.formState.errors.root.message}
                </p>
              )}
              <FieldGroup>
                <Field>
                  <FieldLabel htmlFor="name">{t('admin.zones.name', 'Name')}</FieldLabel>
                  <Input id="name" {...form.register('name', { required: true })} />
                  <FieldError errors={[form.formState.errors.name]} />
                </Field>

                <Field>
                  <FieldLabel htmlFor="description">{t('admin.zones.description', 'Description')}</FieldLabel>
                  <Textarea id="description" {...form.register('description')} />
                  <FieldError errors={[form.formState.errors.description]} />
                </Field>

                <Field>
                  <div className="flex items-center gap-2">
                    <Controller
                      name="default_tax"
                      control={form.control}
                      render={({ field }) => (
                        <Checkbox id="default_tax" checked={!!field.value} onCheckedChange={field.onChange} />
                      )}
                    />
                    <FieldLabel htmlFor="default_tax" className="cursor-pointer mb-0">
                      {t('admin.zones.default_tax', 'Default Tax Zone')}
                    </FieldLabel>
                  </div>
                </Field>
              </FieldGroup>
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
