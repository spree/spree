import { useMutation } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon, UserMinusIcon, UserPlusIcon } from 'lucide-react'
import { type FormEvent, useState } from 'react'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import type { BulkAction, BulkActionFormProps } from '@/components/spree/bulk-action-bar'
import { ExportButton } from '@/components/spree/export-button'
import { ResourceMultiAutocomplete } from '@/components/spree/resource-multi-autocomplete'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { TagCombobox } from '@/components/spree/tag-combobox'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
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
import { customerGroupAutocompleteProps } from '@/hooks/use-customer-groups'
import { Subject } from '@/lib/permissions'
import '@/tables/customers'

// Adds `?new=1` on top of the standard table search schema so the create sheet
// is deep-linkable (`/customers?new=1`) and back-button friendly.
const customersSearchSchema = resourceSearchSchema.extend({
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/customers/')({
  validateSearch: customersSearchSchema,
  component: CustomersPage,
})

type GroupFormValues = { customer_group_ids: string[] }

// Bulk-mutating customers shifts `customers_count` on every affected group, so
// drop the groups cache to force a refetch when the user navigates back.
const GROUP_INVALIDATIONS = [['customer-groups']]

const BULK_ACTIONS: BulkAction<GroupFormValues>[] = [
  {
    key: 'add-to-groups',
    label: 'Add to group…',
    icon: <UserPlusIcon className="size-4" />,
    subject: Subject.Customer,
    form: (props) => <GroupPickerSheet {...props} mode="add" />,
    run: ({ ids, formValues }) =>
      adminClient.customers.bulkAddToGroups({
        ids,
        customer_group_ids: formValues?.customer_group_ids ?? [],
      }),
    invalidate: GROUP_INVALIDATIONS,
    successMessage: 'Added {n} customers to groups',
    errorMessage: 'Failed to add customers to groups',
  },
  {
    key: 'remove-from-groups',
    label: 'Remove from group…',
    icon: <UserMinusIcon className="size-4" />,
    subject: Subject.Customer,
    form: (props) => <GroupPickerSheet {...props} mode="remove" />,
    run: ({ ids, formValues }) =>
      adminClient.customers.bulkRemoveFromGroups({
        ids,
        customer_group_ids: formValues?.customer_group_ids ?? [],
      }),
    invalidate: GROUP_INVALIDATIONS,
    successMessage: 'Removed {n} customers from groups',
    errorMessage: 'Failed to remove customers from groups',
  },
]

function CustomersPage() {
  const search = Route.useSearch() as z.infer<typeof customersSearchSchema>
  const navigate = useNavigate()

  const isCreating = !!search.new

  function openCreate() {
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })
  }

  function closeSheet() {
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _n, ...rest } = prev
        return rest as never
      },
    })
  }

  return (
    <>
      <ResourceTable
        tableKey="customers"
        queryKey="customers"
        queryFn={(params) => adminClient.customers.list(params)}
        searchParams={search}
        defaultParams={{ expand: ['customer_groups'] }}
        bulkActions={BULK_ACTIONS}
        actions={(ctx) => (
          <>
            <ExportButton type="Spree::Exports::Customers" {...ctx} />
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              New Customer
            </Button>
          </>
        )}
      />
      {isCreating && <NewCustomerSheet open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

/**
 * Multi-select group picker used by the bulk add/remove actions. Resolves
 * with `{ customer_group_ids }` so the same component drives both verbs.
 */
function GroupPickerSheet({
  ids,
  onSubmit,
  onCancel,
  mode,
}: BulkActionFormProps<GroupFormValues> & { mode: 'add' | 'remove' }) {
  const [groupIds, setGroupIds] = useState<string[]>([])
  const verb = mode === 'add' ? 'Add' : 'Remove'

  return (
    <Sheet open onOpenChange={(o) => !o && onCancel()}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {verb} {ids.length} customers to groups
          </SheetTitle>
          <SheetDescription>
            {mode === 'add'
              ? 'Selected customers will be added to every group you pick. Already-members are skipped.'
              : 'Selected customers will be removed from every group you pick. Non-members are skipped.'}
          </SheetDescription>
        </SheetHeader>
        <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
          <FieldGroup>
            <Field>
              <FieldLabel>Customer groups</FieldLabel>
              <ResourceMultiAutocomplete
                {...customerGroupAutocompleteProps('customer-groups-picker')}
                value={groupIds}
                onChange={setGroupIds}
              />
            </Field>
          </FieldGroup>
        </div>
        <SheetFooter>
          <Button type="button" variant="outline" size="sm" onClick={onCancel}>
            Cancel
          </Button>
          <Button
            type="button"
            size="sm"
            disabled={groupIds.length === 0}
            onClick={() => onSubmit({ customer_group_ids: groupIds })}
          >
            {verb}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

// ============================================================================
// Create Sheet
// ============================================================================

function NewCustomerSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const [tags, setTags] = useState<string[]>([])
  const [acceptsMarketing, setAcceptsMarketing] = useState(false)

  const createMutation = useMutation({
    mutationFn: (params: Parameters<typeof adminClient.customers.create>[0]) =>
      adminClient.customers.create(params),
    onSuccess: (customer) => {
      // Land on the new customer's detail page rather than leaving the user on
      // the index — they almost always want to add an address or note next.
      navigate({
        to: '/$storeId/customers/$customerId',
        params: { storeId, customerId: customer.id },
      })
    },
  })

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    const email = String(fd.get('email') ?? '').trim()
    if (!email) return

    const payload: Parameters<typeof adminClient.customers.create>[0] = { email }
    const firstName = String(fd.get('first_name') ?? '').trim()
    const lastName = String(fd.get('last_name') ?? '').trim()
    const phone = String(fd.get('phone') ?? '').trim()
    const internalNote = String(fd.get('internal_note') ?? '').trim()

    if (firstName) payload.first_name = firstName
    if (lastName) payload.last_name = lastName
    if (phone) payload.phone = phone
    if (internalNote) payload.internal_note = internalNote
    if (tags.length) payload.tags = tags
    payload.accepts_email_marketing = acceptsMarketing

    createMutation.mutate(payload)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>New Customer</SheetTitle>
          <SheetDescription>
            No password is set and no email is sent. Trigger a password reset from the customer's
            page if they need to sign in.
          </SheetDescription>
        </SheetHeader>
        <form onSubmit={handleSubmit} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="email">Email</FieldLabel>
                <Input id="email" name="email" type="email" required autoFocus />
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="first_name">First name</FieldLabel>
                  <Input id="first_name" name="first_name" />
                </Field>
                <Field>
                  <FieldLabel htmlFor="last_name">Last name</FieldLabel>
                  <Input id="last_name" name="last_name" />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="phone">Phone</FieldLabel>
                <Input id="phone" name="phone" />
              </Field>
              <Field>
                <FieldLabel>Tags</FieldLabel>
                <TagCombobox taggableType="Spree::User" value={tags} onChange={setTags} />
              </Field>
              <Field>
                <label
                  htmlFor="accepts_email_marketing"
                  className="flex items-center gap-2 text-sm"
                >
                  <Checkbox
                    id="accepts_email_marketing"
                    name="accepts_email_marketing"
                    checked={acceptsMarketing}
                    onCheckedChange={setAcceptsMarketing}
                  />
                  Subscribed to marketing
                </label>
              </Field>
              <Field>
                <FieldLabel htmlFor="internal_note">Internal note</FieldLabel>
                <Textarea
                  id="internal_note"
                  name="internal_note"
                  rows={4}
                  placeholder="Staff-only context about this customer…"
                />
              </Field>
              {createMutation.error && (
                <p className="text-sm text-destructive">
                  {(createMutation.error as Error).message}
                </p>
              )}
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={createMutation.isPending}
            >
              Cancel
            </Button>
            <Button type="submit" size="sm" disabled={createMutation.isPending}>
              {createMutation.isPending ? 'Creating…' : 'Create Customer'}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
