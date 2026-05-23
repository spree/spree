import { zodResolver } from '@hookform/resolvers/zod'
import type { CustomerGroup, CustomerGroupCreateParams } from '@spree/admin-sdk'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { PlusIcon, UsersIcon } from 'lucide-react'
import { useEffect } from 'react'
import { type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import { Can } from '@/components/spree/can'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { useRowClickBridge } from '@/components/spree/row-click-bridge'
import { Button } from '@/components/ui/button'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Textarea } from '@/components/ui/textarea'
import {
  useCreateCustomerGroup,
  useCustomerGroup,
  useDeleteCustomerGroup,
  useUpdateCustomerGroup,
} from '@/hooks/use-customer-groups'
import { mapSpreeErrorsToForm } from '@/lib/form-errors'
import { Subject } from '@/lib/permissions'
import {
  CUSTOMER_GROUP_DEFAULTS,
  type CustomerGroupFormValues,
  customerGroupFormSchema,
  customerGroupValuesToParams,
} from '@/schemas/customer-group'
import '@/tables/customer-groups'

const customerGroupsSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/customers/groups')({
  validateSearch: customerGroupsSearchSchema,
  component: CustomerGroupsPage,
})

function CustomerGroupsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof customerGroupsSearchSchema>
  const navigate = useNavigate()

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

  useRowClickBridge('data-customer-group-id', openEdit)

  return (
    <>
      <ResourceTable<CustomerGroup>
        tableKey="customer-groups"
        queryKey="customer-groups"
        queryFn={(params) => adminClient.customerGroups.list(params)}
        searchParams={search}
        actions={
          <Can I="create" a={Subject.CustomerGroup}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.pages.customers.groups.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateCustomerGroupSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && (
        <EditCustomerGroupSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />
      )}
    </>
  )
}

function CreateCustomerGroupSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateCustomerGroup()
  const form = useForm<CustomerGroupFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(customerGroupFormSchema) as any,
    defaultValues: CUSTOMER_GROUP_DEFAULTS,
  })

  async function onSubmit(values: CustomerGroupFormValues) {
    try {
      await createMutation.mutateAsync(
        customerGroupValuesToParams(values) as CustomerGroupCreateParams,
      )
      form.reset(CUSTOMER_GROUP_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(CUSTOMER_GROUP_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.customers.groups.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.customers.groups.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <NameDescriptionFields form={form} />
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
                : t('admin.customers.groups.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditCustomerGroupSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const { data: group, isLoading } = useCustomerGroup(id)
  const updateMutation = useUpdateCustomerGroup(id)
  const deleteMutation = useDeleteCustomerGroup()
  const confirm = useConfirm()

  const form = useForm<CustomerGroupFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(customerGroupFormSchema) as any,
    defaultValues: CUSTOMER_GROUP_DEFAULTS,
  })

  useEffect(() => {
    if (group) {
      form.reset({
        name: group.name,
        description: group.description ?? '',
      })
    }
  }, [group, form])

  async function onSubmit(values: CustomerGroupFormValues) {
    try {
      await updateMutation.mutateAsync(customerGroupValuesToParams(values))
      form.reset(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  async function onDelete() {
    const ok = await confirm({
      title: t('admin.customers.groups.delete_confirm.title'),
      message: t('admin.customers.groups.delete_confirm.message', {
        name: group?.name ?? 'This group',
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(id)
    onOpenChange(false)
  }

  // Filter the /customers index by this group's id. Ransack join filter on the
  // `customer_groups` association — server uses `customer_groups_id_in`.
  const membersFilter = JSON.stringify([
    { id: 'group', field: 'customer_groups_id', operator: 'in', value: id },
  ])

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {group?.name ?? t('admin.pages.customers.groups.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.customers.groups.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <NameDescriptionFields form={form} />
              <MembersSummary
                count={group?.customers_count ?? 0}
                href={`/${storeId}/customers?filters=${encodeURIComponent(membersFilter)}`}
              />
            </div>
            <SheetFooter>
              <Can I="destroy" a={Subject.CustomerGroup}>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={onDelete}
                  disabled={form.formState.isSubmitting || deleteMutation.isPending}
                  className="mr-auto text-destructive hover:bg-destructive/10 hover:text-destructive"
                >
                  {t('admin.actions.delete')}
                </Button>
              </Can>
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

function NameDescriptionFields({ form }: { form: UseFormReturn<CustomerGroupFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  return (
    <FieldGroup>
      {errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {errors.root.message}
        </p>
      )}
      <Field>
        <FieldLabel htmlFor="name">{t('admin.fields.name.label')}</FieldLabel>
        <Input
          id="name"
          autoFocus
          placeholder={t('admin.fields.customer_group.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        {errors.name && <p className="text-sm text-destructive">{errors.name.message}</p>}
      </Field>

      <Field>
        <FieldLabel htmlFor="description">{t('admin.fields.description.label')}</FieldLabel>
        <Textarea
          id="description"
          rows={3}
          placeholder={t('admin.fields.customer_group.description.placeholder')}
          aria-invalid={!!errors.description || undefined}
          {...form.register('description')}
        />
        {errors.description && (
          <p className="text-sm text-destructive">{errors.description.message}</p>
        )}
      </Field>
    </FieldGroup>
  )
}

function MembersSummary({ count, href }: { count: number; href: string }) {
  const { t } = useTranslation()
  return (
    <div className="flex items-center justify-between rounded-md border bg-muted/40 px-3 py-2">
      <div className="flex items-center gap-2 text-sm">
        <UsersIcon className="size-4 text-muted-foreground" />
        <span>{t('admin.customers.groups.count', { count })}</span>
      </div>
      <Link to={href as never} className="text-sm font-medium text-primary hover:underline">
        {t('admin.customers.groups.view_members')}
      </Link>
    </div>
  )
}
