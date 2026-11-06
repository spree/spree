import { zodResolver } from '@hookform/resolvers/zod'
import type { CustomerGroup, CustomerGroupCreateParams } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  extensionFormValues,
  extensionSubmitValues,
  HostFormSlot,
  mapSpreeErrorsToForm,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
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
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, Navigate, useNavigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { NameDescriptionFields } from '../../../../../components/spree/customer-groups/customer-group-fields'
import {
  useCreateCustomerGroup,
  useDeleteCustomerGroup,
} from '../../../../../hooks/use-customer-groups'
import {
  CUSTOMER_GROUP_DEFAULTS,
  type CustomerGroupFormValues,
  customerGroupFormSchema,
  customerGroupValuesToParams,
} from '../../../../../schemas/customer-group'
import '../../../../../tables/customer-groups'

const customerGroupsSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/customers/groups/')({
  validateSearch: customerGroupsSearchSchema,
  component: CustomerGroupsPage,
})

function CustomerGroupsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof customerGroupsSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteCustomerGroup()
  const { permissions } = usePermissions()

  const { storeId } = Route.useParams()
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

  const openGroup = (id: string) =>
    navigate({
      to: '/$storeId/customers/groups/$groupId',
      params: { storeId, groupId: id },
    })

  useRowClickBridge('data-customer-group-id', openGroup)

  async function handleDelete(group: CustomerGroup) {
    const ok = await confirm({
      title: t('admin.customers.groups.delete_confirm.title'),
      message: t('admin.customers.groups.delete_confirm.message', {
        name: group.name ?? t('admin.customers.groups.default_name'),
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    // `useDeleteCustomerGroup` toasts on success/error via `onError`; the
    // `.catch` only swallows the rethrow so the row-action callback doesn't
    // surface an unhandled rejection.
    await deleteMutation.mutateAsync(group.id).catch(() => undefined)
  }

  // The group used to open in a sheet at `?edit=`; old links land on its page.
  if (search.edit) {
    return (
      <Navigate
        to="/$storeId/customers/groups/$groupId"
        params={{ storeId, groupId: search.edit }}
        replace
      />
    )
  }

  return (
    <>
      <ResourceTable<CustomerGroup>
        tableKey="customer-groups"
        queryKey="customer-groups"
        queryFn={(params) => adminClient.customerGroups.list(params)}
        searchParams={search}
        rowActions={(group) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openGroup(group.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.CustomerGroup),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(group),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.CustomerGroup}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.pages.customers.groups.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && (
        <CreateCustomerGroupSheet
          open
          onOpenChange={(o) => !o && closeSheet()}
          onCreated={openGroup}
        />
      )}
    </>
  )
}

function CreateCustomerGroupSheet({
  open,
  onOpenChange,
  onCreated,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Opens the new group's page, where its members are added. */
  onCreated: (id: string) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateCustomerGroup()
  const form = useForm<CustomerGroupFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(customerGroupFormSchema) as any,
    defaultValues: { ...CUSTOMER_GROUP_DEFAULTS, ...extensionFormValues('customer_group', null) },
  })

  async function onSubmit(values: CustomerGroupFormValues) {
    try {
      const created = await createMutation.mutateAsync({
        ...(customerGroupValuesToParams(values) as CustomerGroupCreateParams),
        ...extensionSubmitValues('customer_group', form),
      })
      form.reset(CUSTOMER_GROUP_DEFAULTS)
      onCreated(created.id)
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
            <HostFormSlot
              form={form}
              name="customer_group.form_fields"
              context={{ customerGroup: undefined, mode: 'new' }}
            />
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
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
