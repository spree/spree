import { adminClient, Can, mapSpreeErrorsToForm, ResourceTable, Subject, usePermissions } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
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
  useCreateShippingMethod,
  useDeleteShippingMethod,
  useShippingMethod,
  useShippingMethods,
  useUpdateShippingMethod,
} from '@/hooks/use-shipping-methods'

const shippingMethodsSearchSchema = z.object({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
  q: z.string().optional(),
  page: z.coerce.number().optional(),
  limit: z.coerce.number().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/shipping-methods')({
  validateSearch: shippingMethodsSearchSchema,
  component: ShippingMethodsPage,
})

function ShippingMethodsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof shippingMethodsSearchSchema>
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const confirm = useConfirm()
  const deleteMutation = useDeleteShippingMethod()
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

  useRowClickBridge('data-shipping-method-id', openEdit)

  async function handleDelete(method: { id: string; name: string }) {
    const ok = await confirm({
      title: t('admin.shipping_methods.delete_confirm.title'),
      message: t('admin.shipping_methods.delete_confirm.message', { name: method.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(method.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable
        tableKey="shipping-methods"
        queryKey="shipping-methods"
        queryFn={(params) => adminClient.request('GET', '/shipping_methods', { params: { ...params, per_page: 100 } })}
        searchParams={search}
        rowActions={(method) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(method.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.ShippingMethod),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(method),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.ShippingMethod}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.shipping_methods.add_cta', 'New Shipping Method')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateShippingMethodSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditShippingMethodSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreateShippingMethodSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateShippingMethod()
  const form = useForm({
    defaultValues: { name: '', display_on: '1' },
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
          <SheetTitle>{t('admin.shipping_methods.new', 'New Shipping Method')}</SheetTitle>
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
                <FieldLabel htmlFor="name">{t('admin.shipping_methods.name', 'Name')}</FieldLabel>
                <Input id="name" autoFocus {...form.register('name', { required: true })} />
                <FieldError errors={[form.formState.errors.name]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="display_on">{t('admin.shipping_methods.display_on', 'Display On')}</FieldLabel>
                <Controller
                  name="display_on"
                  control={form.control}
                  render={({ field }) => (
                    <Select value={field.value} onValueChange={field.onChange}>
                      <SelectTrigger id="display_on" className="w-full">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="1">{t('admin.shipping_methods.display_on_frontend', 'Frontend')}</SelectItem>
                        <SelectItem value="2">{t('admin.shipping_methods.display_on_backend', 'Backend')}</SelectItem>
                      </SelectContent>
                    </Select>
                  )}
                />
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

function EditShippingMethodSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: method, isLoading } = useShippingMethod(id)
  const updateMutation = useUpdateShippingMethod()
  const form = useForm({
    defaultValues: { name: '', display_on: '1' },
  })

  useEffect(() => {
    if (method) {
      form.reset({
        name: method.name,
        display_on: String(method.display_on),
      })
    }
  }, [method, form])

  async function onSubmit(values: Record<string, unknown>) {
    try {
      await updateMutation.mutateAsync({ id, ...values })
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
          <SheetTitle>{method?.name ?? t('admin.shipping_methods.edit', 'Edit Shipping Method')}</SheetTitle>
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
                  <FieldLabel htmlFor="name">{t('admin.shipping_methods.name', 'Name')}</FieldLabel>
                  <Input id="name" {...form.register('name', { required: true })} />
                  <FieldError errors={[form.formState.errors.name]} />
                </Field>

                <Field>
                  <FieldLabel htmlFor="display_on">{t('admin.shipping_methods.display_on', 'Display On')}</FieldLabel>
                  <Controller
                    name="display_on"
                    control={form.control}
                    render={({ field }) => (
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger id="display_on" className="w-full">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="1">{t('admin.shipping_methods.display_on_frontend', 'Frontend')}</SelectItem>
                          <SelectItem value="2">{t('admin.shipping_methods.display_on_backend', 'Backend')}</SelectItem>
                        </SelectContent>
                      </Select>
                    )}
                  />
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
