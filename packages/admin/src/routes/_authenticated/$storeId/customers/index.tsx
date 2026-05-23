import { useMutation } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon, UserMinusIcon, UserPlusIcon } from 'lucide-react'
import { useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import type { BulkAction, BulkActionFormProps } from '@/components/spree/bulk-action-bar'
import { ExportButton } from '@/components/spree/export-button'
import { ResourceMultiAutocomplete } from '@/components/spree/resource-multi-autocomplete'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { TagCombobox } from '@/components/spree/tag-combobox'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
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
import { mapSpreeErrorsToForm } from '@/lib/form-errors'
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

interface NewCustomerFormValues {
  email: string
  first_name: string
  last_name: string
  phone: string
  tags: string[]
  accepts_email_marketing: boolean
  internal_note: string
}

const NEW_CUSTOMER_DEFAULTS: NewCustomerFormValues = {
  email: '',
  first_name: '',
  last_name: '',
  phone: '',
  tags: [],
  accepts_email_marketing: false,
  internal_note: '',
}

function NewCustomerSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()

  const form = useForm<NewCustomerFormValues>({ defaultValues: NEW_CUSTOMER_DEFAULTS })

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

  async function onSubmit(values: NewCustomerFormValues) {
    const payload: Parameters<typeof adminClient.customers.create>[0] = {
      email: values.email.trim(),
      accepts_email_marketing: values.accepts_email_marketing,
    }
    if (values.first_name.trim()) payload.first_name = values.first_name.trim()
    if (values.last_name.trim()) payload.last_name = values.last_name.trim()
    if (values.phone.trim()) payload.phone = values.phone.trim()
    if (values.internal_note.trim()) payload.internal_note = values.internal_note.trim()
    if (values.tags.length) payload.tags = values.tags

    try {
      await createMutation.mutateAsync(payload)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
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
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="new-customer-email">
                  {t('admin.fields.email.label')}
                </FieldLabel>
                <Input
                  id="new-customer-email"
                  type="email"
                  autoFocus
                  aria-invalid={!!form.formState.errors.email || undefined}
                  {...form.register('email')}
                />
                <FieldError errors={[form.formState.errors.email]} />
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="new-customer-first-name">
                    {t('admin.fields.first_name.label')}
                  </FieldLabel>
                  <Input
                    id="new-customer-first-name"
                    aria-invalid={!!form.formState.errors.first_name || undefined}
                    {...form.register('first_name')}
                  />
                  <FieldError errors={[form.formState.errors.first_name]} />
                </Field>
                <Field>
                  <FieldLabel htmlFor="new-customer-last-name">
                    {t('admin.fields.last_name.label')}
                  </FieldLabel>
                  <Input
                    id="new-customer-last-name"
                    aria-invalid={!!form.formState.errors.last_name || undefined}
                    {...form.register('last_name')}
                  />
                  <FieldError errors={[form.formState.errors.last_name]} />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="new-customer-phone">
                  {t('admin.fields.phone.label')}
                </FieldLabel>
                <Input
                  id="new-customer-phone"
                  aria-invalid={!!form.formState.errors.phone || undefined}
                  {...form.register('phone')}
                />
                <FieldError errors={[form.formState.errors.phone]} />
              </Field>
              <Field>
                <FieldLabel>{t('admin.fields.customer.tags.label')}</FieldLabel>
                <Controller
                  name="tags"
                  control={form.control}
                  render={({ field }) => (
                    <TagCombobox
                      taggableType="Spree::User"
                      value={field.value}
                      onChange={field.onChange}
                    />
                  )}
                />
              </Field>
              <Field>
                <div className="flex items-start justify-between gap-4">
                  <FieldLabel htmlFor="new-customer-marketing" className="cursor-pointer">
                    {t('admin.fields.customer.accepts_email_marketing.label')}
                  </FieldLabel>
                  <Controller
                    name="accepts_email_marketing"
                    control={form.control}
                    render={({ field }) => (
                      <Checkbox
                        id="new-customer-marketing"
                        checked={!!field.value}
                        onCheckedChange={field.onChange}
                      />
                    )}
                  />
                </div>
              </Field>
              <Field>
                <FieldLabel htmlFor="new-customer-note">
                  {t('admin.fields.customer.internal_note.label')}
                </FieldLabel>
                <Textarea
                  id="new-customer-note"
                  rows={4}
                  placeholder={t('admin.fields.customer.internal_note.placeholder')}
                  aria-invalid={!!form.formState.errors.internal_note || undefined}
                  {...form.register('internal_note')}
                />
                <FieldError errors={[form.formState.errors.internal_note]} />
              </Field>
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
