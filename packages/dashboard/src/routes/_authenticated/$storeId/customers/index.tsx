import type { Customer } from '@spree/admin-sdk'
import type { BulkAction, BulkActionFormProps } from '@spree/dashboard-core'
import {
  adminClient,
  ExportButton,
  ImportButton,
  ResourceMultiAutocomplete,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  TagCombobox,
  useStore,
} from '@spree/dashboard-core'
import { BulkDialog, Button, Field, FieldLabel, RowActions } from '@spree/dashboard-ui'
import { PlusIcon, TagsIcon, UserMinusIcon, UserPlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { NewCustomerSheet } from '../../../../components/spree/customers/new-customer-sheet'
import { ImportWizardDialog } from '../../../../components/spree/imports/import-wizard-dialog'
import {
  importWizardSearchSchema,
  useImportWizardSearch,
} from '../../../../components/spree/imports/import-wizard-search'
import {
  customerGroupAutocompleteProps,
  useCustomerGroups,
} from '../../../../hooks/use-customer-groups'
import {
  useBulkAddCustomersToGroups,
  useBulkAddCustomerTags,
  useBulkRemoveCustomersFromGroups,
  useBulkRemoveCustomerTags,
} from '../../../../hooks/use-customers'
import '../../../../tables/customers'

// Adds `?new=1` on top of the standard table search schema so the create sheet
// is deep-linkable (`/customers?new=1`) and back-button friendly. `import`
// carries the prefixed id of the import wizard dialog open over the table.
const customersSearchSchema = resourceSearchSchema.extend({
  new: z.coerce.boolean().optional(),
  ...importWizardSearchSchema.shape,
})

export const Route = createFileRoute('/_authenticated/$storeId/customers/')({
  validateSearch: customersSearchSchema,
  component: CustomersPage,
})

type GroupFormValues = { customer_group_ids: string[] }
type TagsFormValues = { tags: string[] }

// Bulk-mutating customers shifts `customers_count` on every affected group, so
// drop the groups cache to force a refetch when the user navigates back.
const GROUP_INVALIDATIONS = [['customer-groups']]

function CustomersPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch() as z.infer<typeof customersSearchSchema>
  const navigate = useNavigate()
  const bulkAddToGroups = useBulkAddCustomersToGroups()
  const bulkRemoveFromGroups = useBulkRemoveCustomersFromGroups()
  const bulkAddTags = useBulkAddCustomerTags()
  const bulkRemoveTags = useBulkRemoveCustomerTags()

  // BulkActionBar's `successMessage` runs through a `{n}` interpolation in the
  // bar itself; we pass i18next `{{count}}` as the literal `{n}` token so the
  // bar can substitute the real count at runtime.
  const bulkActions: BulkAction<GroupFormValues | TagsFormValues>[] = [
    {
      key: 'add-to-groups',
      label: t('admin.customers.groups.bulk_add_action'),
      icon: <UserPlusIcon className="size-4" />,
      subject: Subject.Customer,
      form: (props) => (
        <GroupPickerDialog
          {...(props as BulkActionFormProps<GroupFormValues>)}
          title={t('admin.customers.groups.picker.add_title')}
          description={t('admin.customers.groups.picker.add_description')}
          submitLabel={t('admin.actions.add')}
        />
      ),
      run: ({ ids, formValues }) =>
        bulkAddToGroups.mutateAsync({
          ids,
          customer_group_ids: (formValues as GroupFormValues).customer_group_ids ?? [],
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
      form: (props) => (
        <GroupPickerDialog
          {...(props as BulkActionFormProps<GroupFormValues>)}
          title={t('admin.customers.groups.picker.remove_title')}
          description={t('admin.customers.groups.picker.remove_description')}
          submitLabel={t('admin.actions.remove')}
        />
      ),
      run: ({ ids, formValues }) =>
        bulkRemoveFromGroups.mutateAsync({
          ids,
          customer_group_ids: (formValues as GroupFormValues).customer_group_ids ?? [],
        }),
      invalidate: GROUP_INVALIDATIONS,
      successMessage: t('admin.customers.groups.bulk_removed', {
        count: '{n}' as unknown as number,
      }),
      errorMessage: t('admin.customers.groups.bulk_remove_failed'),
    },
    {
      key: 'add-tags',
      label: t('admin.customers.tags.bulk_add_action'),
      icon: <TagsIcon className="size-4" />,
      subject: Subject.Customer,
      form: (props) => (
        <TagPickerDialog
          {...(props as BulkActionFormProps<TagsFormValues>)}
          title={t('admin.customers.tags.picker.add_title')}
          description={t('admin.customers.tags.picker.add_description')}
          submitLabel={t('admin.actions.add')}
        />
      ),
      run: ({ ids, formValues }) =>
        bulkAddTags.mutateAsync({ ids, tags: (formValues as TagsFormValues).tags ?? [] }),
      successMessage: t('admin.customers.tags.bulk_added'),
      errorMessage: t('admin.customers.tags.bulk_add_failed'),
    },
    {
      key: 'remove-tags',
      label: t('admin.customers.tags.bulk_remove_action'),
      icon: <TagsIcon className="size-4" />,
      subject: Subject.Customer,
      form: (props) => (
        <TagPickerDialog
          {...(props as BulkActionFormProps<TagsFormValues>)}
          title={t('admin.customers.tags.picker.remove_title')}
          description={t('admin.customers.tags.picker.remove_description')}
          submitLabel={t('admin.actions.remove')}
        />
      ),
      run: ({ ids, formValues }) =>
        bulkRemoveTags.mutateAsync({ ids, tags: (formValues as TagsFormValues).tags ?? [] }),
      successMessage: t('admin.customers.tags.bulk_removed'),
      errorMessage: t('admin.customers.tags.bulk_remove_failed'),
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

  const wizard = useImportWizardSearch(search)

  return (
    <>
      <ResourceTable<Customer>
        tableKey="customers"
        queryKey="customers"
        queryFn={(params) => adminClient.customers.list(params)}
        searchParams={search}
        // Erased accounts stay out of the list unless asked for. They keep
        // their orders, so the row still means something, but nobody can be
        // reached through it and leaving them in makes every search noisier.
        // The Erased filter overrides this: filters are applied over
        // the defaults.
        defaultParams={{ expand: ['customer_groups'], anonymized: 'false' }}
        bulkActions={bulkActions}
        rowActions={(customer) => <CustomerRowActions customer={customer} storeId={storeId} />}
        actions={(ctx) => (
          <>
            <ImportButton
              type="customers"
              subject={Subject.Customer}
              onCreated={(imp) => wizard.open(imp.id)}
            />
            <ExportButton type="customers" {...ctx} />
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.pages.customers.new_cta')}
            </Button>
          </>
        )}
      />
      {isCreating && (
        <NewCustomerSheet
          open
          onOpenChange={(o) => !o && closeSheet()}
          // Land on the new customer's page rather than the index — the next
          // step is almost always an address or a note.
          onCreated={(customer) =>
            navigate({
              to: '/$storeId/customers/$customerId',
              params: { storeId, customerId: customer.id },
              replace: true,
            })
          }
        />
      )}
      <ImportWizardDialog importId={wizard.importId} onClose={wizard.close} />
    </>
  )
}

/**
 * Per-row Edit kebab.
 *
 * No delete. Destroying the row and erasing the person were two destructive
 * actions that never both applied — deletion is refused once someone has
 * bought anything, which is exactly when a real erasure request arrives — and
 * the milder-sounding one was the destructive one, taking store credit and
 * gift cards with it. Erasing is on the customer's own page, where the record
 * being erased is in front of you.
 */
function CustomerRowActions({ customer, storeId }: { customer: Customer; storeId: string }) {
  const navigate = useNavigate()

  return (
    <RowActions
      actions={[
        {
          key: 'edit',
          onSelect: () =>
            navigate({
              to: '/$storeId/customers/$customerId',
              params: { storeId, customerId: customer.id },
            }),
        },
      ]}
    />
  )
}

/**
 * Multi-select group picker used by the bulk add/remove actions. Resolves
 * with `{ customer_group_ids }` so the same component drives both verbs;
 * the caller supplies the title/description/submit-label copy.
 */
function GroupPickerDialog({
  onSubmit,
  onCancel,
  title,
  description,
  submitLabel,
}: BulkActionFormProps<GroupFormValues> & {
  title: string
  description: string
  submitLabel: string
}) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const [groupIds, setGroupIds] = useState<string[]>([])
  // Surface the store's customer groups on focus so the merchant doesn't have
  // to type to discover them. The list is small and already cached by
  // +useCustomerGroups+ (5-min stale time).
  const { data: groupsData } = useCustomerGroups()

  return (
    <BulkDialog
      title={title}
      description={description}
      submitLabel={submitLabel}
      submitDisabled={groupIds.length === 0}
      onCancel={onCancel}
      onSubmit={() => onSubmit({ customer_group_ids: groupIds })}
    >
      <Field>
        <FieldLabel>{t('admin.fields.customer.customer_groups.label')}</FieldLabel>
        <ResourceMultiAutocomplete
          {...customerGroupAutocompleteProps(`customer-groups-picker-${storeId}`)}
          initialItems={groupsData?.data}
          value={groupIds}
          onChange={setGroupIds}
        />
      </Field>
    </BulkDialog>
  )
}

/**
 * Multi-select tag picker used by the bulk add/remove tag actions. Resolves
 * with `{ tags }` (raw tag names) so the same component drives both verbs.
 */
function TagPickerDialog({
  onSubmit,
  onCancel,
  title,
  description,
  submitLabel,
}: BulkActionFormProps<TagsFormValues> & {
  title: string
  description: string
  submitLabel: string
}) {
  const { t } = useTranslation()
  const [tags, setTags] = useState<string[]>([])

  return (
    <BulkDialog
      title={title}
      description={description}
      submitLabel={submitLabel}
      submitDisabled={tags.length === 0}
      onCancel={onCancel}
      onSubmit={() => onSubmit({ tags })}
    >
      <Field>
        <FieldLabel>{t('admin.fields.customer.tags.label')}</FieldLabel>
        <TagCombobox taggableType="customer" value={tags} onChange={setTags} />
      </Field>
    </BulkDialog>
  )
}
