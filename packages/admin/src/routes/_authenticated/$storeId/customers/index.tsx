import { zodResolver } from '@hookform/resolvers/zod'
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
import {
  NEW_CUSTOMER_DEFAULTS,
  type NewCustomerFormValues,
  newCustomerFormSchema,
} from '@/schemas/customer'
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

function CustomersPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof customersSearchSchema>
  const navigate = useNavigate()

  // BulkActionBar's `successMessage` runs through a `{n}` interpolation in the
  // bar itself; we pass i18next `{{count}}` as the literal `{n}` token so the
  // bar can substitute the real count at runtime.
  const bulkActions: BulkAction<GroupFormValues>[] = [
    {
      key: 'add-to-groups',
      label: t('admin.customers.groups.bulk_add_action'),
      icon: <UserPlusIcon className="size-4" />,
      subject: Subject.Customer,
      form: (props) => <GroupPickerSheet {...props} mode="add" />,
      run: ({ ids, formValues }) =>
        adminClient.customers.bulkAddToGroups({
          ids,
          customer_group_ids: formValues?.customer_group_ids ?? [],
        }),
      invalidate: GROUP_INVALIDATIONS,
      successMessage: t('admin.customers.groups.bulk_added', { count: '{n}' as unknown as number }),
      errorMessage: t('admin.customers.groups.bulk_add_failed'),
    },
    {
      key: 'remove-from-groups',
      label: t('admin.customers.groups.bulk_remove_action'),
      icon: <UserMinusIcon className="size-4" />,
      subject: Subject.Customer,
      form: (props) => <GroupPickerSheet {...props} mode="remove" />,
      run: ({ ids, formValues }) =>
        adminClient.customers.bulkRemoveFromGroups({
          ids,
          customer_group_ids: formValues?.customer_group_ids ?? [],
        }),
      invalidate: GROUP_INVALIDATIONS,
      successMessage: t('admin.customers.groups.bulk_removed', {
        count: '{n}' as unknown as number,
      }),
      errorMessage: t('admin.customers.groups.bulk_remove_failed'),
    },
  ]

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
        bulkActions={bulkActions}
        actions={(ctx) => (
          <>
            <ExportButton type="Spree::Exports::Customers" {...ctx} />
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.pages.customers.new_cta')}
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
  onSubmit,
  onCancel,
  mode,
}: BulkActionFormProps<GroupFormValues> & { mode: 'add' | 'remove' }) {
  const { t } = useTranslation()
  const [groupIds, setGroupIds] = useState<string[]>([])

  return (
    <Sheet open onOpenChange={(o) => !o && onCancel()}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {mode === 'add'
              ? t('admin.customers.groups.picker.add_title')
              : t('admin.customers.groups.picker.remove_title')}
          </SheetTitle>
          <SheetDescription>
            {mode === 'add'
              ? t('admin.customers.groups.picker.add_description')
              : t('admin.customers.groups.picker.remove_description')}
          </SheetDescription>
        </SheetHeader>
        <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
          <FieldGroup>
            <Field>
              <FieldLabel>{t('admin.pages.customers.groups_cta')}</FieldLabel>
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
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            size="sm"
            disabled={groupIds.length === 0}
            onClick={() => onSubmit({ customer_group_ids: groupIds })}
          >
            {mode === 'add' ? t('admin.actions.add') : t('admin.actions.remove')}
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
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()

  const form = useForm<NewCustomerFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(newCustomerFormSchema) as any,
    defaultValues: NEW_CUSTOMER_DEFAULTS,
  })

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
          <SheetTitle>{t('admin.pages.customers.new_cta')}</SheetTitle>
          <SheetDescription>{t('admin.customers.new_sheet_description')}</SheetDescription>
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
                <FieldLabel htmlFor="email">{t('admin.fields.email.label')}</FieldLabel>
                <Input
                  id="email"
                  type="email"
                  autoFocus
                  aria-invalid={!!form.formState.errors.email || undefined}
                  {...form.register('email')}
                />
                <FieldError errors={[form.formState.errors.email]} />
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="first_name">{t('admin.fields.first_name.label')}</FieldLabel>
                  <Input
                    id="first_name"
                    aria-invalid={!!form.formState.errors.first_name || undefined}
                    {...form.register('first_name')}
                  />
                  <FieldError errors={[form.formState.errors.first_name]} />
                </Field>
                <Field>
                  <FieldLabel htmlFor="last_name">{t('admin.fields.last_name.label')}</FieldLabel>
                  <Input
                    id="last_name"
                    aria-invalid={!!form.formState.errors.last_name || undefined}
                    {...form.register('last_name')}
                  />
                  <FieldError errors={[form.formState.errors.last_name]} />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="phone">{t('admin.fields.phone.label')}</FieldLabel>
                <Input
                  id="phone"
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
                  <FieldLabel htmlFor="accepts_email_marketing" className="cursor-pointer">
                    {t('admin.fields.customer.accepts_email_marketing.label')}
                  </FieldLabel>
                  <Controller
                    name="accepts_email_marketing"
                    control={form.control}
                    render={({ field }) => (
                      <Checkbox
                        id="accepts_email_marketing"
                        checked={!!field.value}
                        onCheckedChange={field.onChange}
                      />
                    )}
                  />
                </div>
              </Field>
              <Field>
                <FieldLabel htmlFor="internal_note">
                  {t('admin.fields.customer.internal_note.label')}
                </FieldLabel>
                <Textarea
                  id="internal_note"
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
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" size="sm" disabled={createMutation.isPending}>
              {createMutation.isPending
                ? t('admin.actions.creating')
                : t('admin.pages.customers.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
