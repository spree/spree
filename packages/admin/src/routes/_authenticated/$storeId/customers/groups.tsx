import { zodResolver } from '@hookform/resolvers/zod'
import type {
  CustomerGroup,
  CustomerGroupCreateParams,
  CustomerGroupUpdateParams,
} from '@spree/admin-sdk'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { PlusIcon, UsersIcon } from 'lucide-react'
import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
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
import { Subject } from '@/lib/permissions'
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
              Add customer group
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

const formSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  description: z.string().optional(),
})

type FormValues = z.infer<typeof formSchema>

const DEFAULT_VALUES: FormValues = { name: '', description: '' }

function valuesToParams(v: FormValues): CustomerGroupCreateParams & CustomerGroupUpdateParams {
  return {
    name: v.name,
    description: v.description && v.description.length > 0 ? v.description : null,
  }
}

function CreateCustomerGroupSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const createMutation = useCreateCustomerGroup()
  const form = useForm<FormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(formSchema) as any,
    defaultValues: DEFAULT_VALUES,
  })

  async function onSubmit(values: FormValues) {
    await createMutation.mutateAsync(valuesToParams(values) as CustomerGroupCreateParams)
    form.reset(DEFAULT_VALUES)
    onOpenChange(false)
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(DEFAULT_VALUES)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>Add customer group</SheetTitle>
          <SheetDescription>
            Groups segment customers for targeted promotions and reporting. After creating, assign
            customers from the Customers screen using bulk actions.
          </SheetDescription>
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
              Cancel
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? 'Creating…' : 'Create customer group'}
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
  const { storeId } = Route.useParams()
  const { data: group, isLoading } = useCustomerGroup(id)
  const updateMutation = useUpdateCustomerGroup(id)
  const deleteMutation = useDeleteCustomerGroup()
  const confirm = useConfirm()

  const form = useForm<FormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(formSchema) as any,
    defaultValues: DEFAULT_VALUES,
  })

  useEffect(() => {
    if (group) {
      form.reset({
        name: group.name,
        description: group.description ?? '',
      })
    }
  }, [group, form])

  async function onSubmit(values: FormValues) {
    await updateMutation.mutateAsync(valuesToParams(values))
    form.reset(values)
    onOpenChange(false)
  }

  async function onDelete() {
    const ok = await confirm({
      title: 'Delete customer group?',
      message: `${group?.name ?? 'This group'} will be removed. Customers in it will not be deleted.`,
      variant: 'destructive',
      confirmLabel: 'Delete',
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
          <SheetTitle>{group?.name ?? 'Edit customer group'}</SheetTitle>
          <SheetDescription>Update the name or description.</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">Loading…</div>
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
                  Delete
                </Button>
              </Can>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={form.formState.isSubmitting || !form.formState.isDirty}
              >
                {form.formState.isSubmitting ? 'Saving…' : 'Save'}
              </Button>
            </SheetFooter>
          </form>
        )}
      </SheetContent>
    </Sheet>
  )
}

function NameDescriptionFields({
  form,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: any
}) {
  return (
    <FieldGroup>
      <Field>
        <FieldLabel htmlFor="name">Name</FieldLabel>
        <Input
          id="name"
          autoFocus
          placeholder="e.g. VIP customers"
          {...form.register('name')}
          aria-invalid={!!form.formState.errors.name}
        />
        {form.formState.errors.name && (
          <p className="text-sm text-destructive">{form.formState.errors.name.message}</p>
        )}
      </Field>

      <Field>
        <FieldLabel htmlFor="description">Description</FieldLabel>
        <Textarea
          id="description"
          rows={3}
          placeholder="Optional internal description"
          {...form.register('description')}
        />
      </Field>
    </FieldGroup>
  )
}

function MembersSummary({ count, href }: { count: number; href: string }) {
  return (
    <div className="flex items-center justify-between rounded-md border bg-muted/40 px-3 py-2">
      <div className="flex items-center gap-2 text-sm">
        <UsersIcon className="size-4 text-muted-foreground" />
        <span>
          <span className="font-medium">{count}</span> {count === 1 ? 'customer' : 'customers'} in
          this group
        </span>
      </div>
      <Link to={href as never} className="text-sm font-medium text-primary hover:underline">
        View members
      </Link>
    </div>
  )
}
