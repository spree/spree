import { zodResolver } from '@hookform/resolvers/zod'
import type { Customer, CustomerGroup } from '@spree/admin-sdk'
import {
  extensionFormValues,
  extensionSubmitValues,
  HostFormSlot,
  mapSpreeErrorsToForm,
  PageHeader,
  Slot,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Empty,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  ErrorState,
  Field,
  FieldLabel,
  Pagination,
  ResourceLayout,
  RowActions,
  Section,
  SectionActions,
  SectionHeader,
  SectionTitle,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { PlusIcon, UsersIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useEffect, useState } from 'react'
import { FormProvider, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { NameDescriptionFields } from '../../../../../components/spree/customer-groups/customer-group-fields'
import { CustomerCombobox } from '../../../../../components/spree/customers/customer-combobox'
import {
  CustomerIdentity,
  customerHasName,
} from '../../../../../components/spree/customers/customer-identity'
import { ResourceDetailSkeleton } from '../../../../../components/spree/route-pending'
import {
  useAddCustomerGroupMember,
  useCustomerGroup,
  useCustomerGroupMembers,
  useDeleteCustomerGroup,
  useRemoveCustomerGroupMember,
  useUpdateCustomerGroup,
} from '../../../../../hooks/use-customer-groups'
import {
  CUSTOMER_GROUP_DEFAULTS,
  type CustomerGroupFormValues,
  customerGroupFormSchema,
  customerGroupValuesToParams,
} from '../../../../../schemas/customer-group'

export const Route = createFileRoute('/_authenticated/$storeId/customers/groups/$groupId')({
  component: CustomerGroupPage,
})

function CustomerGroupPage() {
  const { t } = useTranslation()
  const { groupId } = Route.useParams()
  const { data: group, isLoading, error, refetch } = useCustomerGroup(groupId)

  if (isLoading) return <ResourceDetailSkeleton />
  if (error || !group) {
    return (
      <ErrorState
        title={t('admin.customer_groups.messages.load_failed')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <CustomerGroupBody key={group.id} group={group} />
}

function CustomerGroupBody({ group }: { group: CustomerGroup }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const { permissions } = usePermissions()
  const deleteMutation = useDeleteCustomerGroup()
  const canEdit = permissions.can('update', Subject.CustomerGroup)

  async function handleDelete() {
    await deleteMutation.mutateAsync(group.id)
    navigate({ to: '/$storeId/customers/groups', params: { storeId } })
  }

  return (
    <ResourceLayout
      header={
        <PageHeader
          title={group.name}
          backTo="customers/groups"
          resource={group}
          endpoint={`/api/v3/admin/customer_groups/${group.id}`}
          onDelete={permissions.can('destroy', Subject.CustomerGroup) ? handleDelete : undefined}
          deleteConfirmTitle={t('admin.customers.groups.delete_confirm.title')}
          deleteConfirmMessage={t('admin.customers.groups.delete_confirm.message', {
            name: group.name,
          })}
        />
      }
      main={
        <>
          <MembersSection group={group} canEdit={canEdit} />
          <Slot name="customer_group.form_main" context={{ customerGroup: group, canEdit }} />
        </>
      }
      sidebar={
        <>
          <DetailsCard group={group} canEdit={canEdit} />
          <Slot name="customer_group.form_sidebar" context={{ customerGroup: group, canEdit }} />
        </>
      }
    />
  )
}

function DetailsCard({ group, canEdit }: { group: CustomerGroup; canEdit: boolean }) {
  const { t } = useTranslation()
  const updateMutation = useUpdateCustomerGroup(group.id)

  const form = useForm<CustomerGroupFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(customerGroupFormSchema) as any,
    defaultValues: CUSTOMER_GROUP_DEFAULTS,
  })

  useEffect(() => {
    form.reset({
      name: group.name,
      description: group.description ?? '',
      ...extensionFormValues('customer_group', group),
    })
  }, [group, form])

  async function onSubmit(values: CustomerGroupFormValues) {
    try {
      await updateMutation.mutateAsync({
        ...customerGroupValuesToParams(values),
        ...extensionSubmitValues('customer_group', form),
      })
      form.reset(values)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.customers.groups.detail.details')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <FormProvider {...form}>
          <fieldset disabled={!canEdit} className="flex flex-col gap-4">
            <NameDescriptionFields form={form} autoFocus={false} />
            <HostFormSlot
              form={form}
              name="customer_group.form_fields"
              context={{ customerGroup: group, mode: 'edit' }}
            />
          </fieldset>
        </FormProvider>
        {canEdit && (
          <div className="flex justify-end">
            {/* The page is not a form, but keep this a plain button so the
                card never nests one. */}
            <Button
              type="button"
              size="sm"
              disabled={form.formState.isSubmitting || !form.formState.isDirty}
              onClick={form.handleSubmit(onSubmit)}
            >
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

function MembersSection({ group, canEdit }: { group: CustomerGroup; canEdit: boolean }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const confirm = useConfirm()
  const [page, setPage] = useState(1)
  const { data, isLoading } = useCustomerGroupMembers(group.id, page)
  const removeMutation = useRemoveCustomerGroupMember(group.id)
  const [addOpen, setAddOpen] = useState(false)

  const members = data?.data ?? []
  const meta = data?.meta

  async function handleRemove(customer: Customer) {
    const ok = await confirm({
      title: t('admin.customers.groups.detail.remove_confirm.title'),
      message: t('admin.customers.groups.detail.remove_confirm.message', {
        name: customerHasName(customer) ? customer.full_name : customer.email,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.customers.groups.detail.remove_member'),
    })
    if (!ok) return
    await removeMutation.mutateAsync(customer.id).catch(() => undefined)
  }

  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <UsersIcon />
          {t('admin.customers.groups.detail.members')}
          {meta?.count ? <Badge variant="outline">{meta.count}</Badge> : null}
        </SectionTitle>
        {canEdit && (
          <SectionActions>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.customers.groups.detail.add_member')}
            </Button>
          </SectionActions>
        )}
      </SectionHeader>

      <Card>
        {isLoading || members.length === 0 ? (
          <CardContent>
            {isLoading ? (
              <p className="text-muted-foreground text-base">{t('admin.common.loading')}</p>
            ) : (
              <Empty className="p-4">
                <EmptyHeader>
                  <EmptyMedia variant="icon">
                    <UsersIcon />
                  </EmptyMedia>
                  <EmptyTitle>{t('admin.customers.groups.detail.members_empty')}</EmptyTitle>
                </EmptyHeader>
              </Empty>
            )}
          </CardContent>
        ) : (
          <>
            <Table roundedTop>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.customers.groups.detail.customer')}</TableHead>
                  {canEdit && <TableHead className="w-10" />}
                </TableRow>
              </TableHeader>
              <TableBody>
                {members.map((customer) => (
                  <TableRow key={customer.id}>
                    <TableCell>
                      <CustomerIdentity
                        customer={customer}
                        linkTo={{ storeId, customerId: customer.id }}
                      />
                    </TableCell>
                    {canEdit && (
                      <TableCell className="w-10 text-right">
                        <RowActions
                          actions={[
                            {
                              key: 'remove',
                              label: t('admin.customers.groups.detail.remove_member'),
                              destructive: true,
                              disabled: removeMutation.isPending,
                              onSelect: () => handleRemove(customer),
                            },
                          ]}
                        />
                      </TableCell>
                    )}
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            {meta && meta.pages > 1 && <Pagination inset meta={meta} onPageChange={setPage} />}
          </>
        )}
      </Card>

      {addOpen && <AddMemberDialog groupId={group.id} onOpenChange={setAddOpen} />}
    </Section>
  )
}

function AddMemberDialog({
  groupId,
  onOpenChange,
}: {
  groupId: string
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const addMutation = useAddCustomerGroupMember(groupId)
  const [customerId, setCustomerId] = useState<string | null>(null)

  async function handleAdd() {
    if (!customerId) return
    try {
      await addMutation.mutateAsync(customerId)
      onOpenChange(false)
    } catch {
      // The mutation toasts the failure; the dialog stays open to retry.
    }
  }

  return (
    <Dialog open onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.customers.groups.detail.add_member_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.customers.groups.detail.add_member_description')}
          </DialogDescription>
        </DialogHeader>
        <DialogBody>
          <Field>
            <FieldLabel htmlFor="group-member-customer">
              {t('admin.fields.customer_id.label')}
            </FieldLabel>
            <CustomerCombobox
              queryKey="customer-group-member"
              id="group-member-customer"
              value={customerId}
              onChange={(id) => setCustomerId(id)}
            />
          </Field>
        </DialogBody>
        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={addMutation.isPending}
          >
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" disabled={!customerId || addMutation.isPending} onClick={handleAdd}>
            {t('admin.customers.groups.detail.add_member')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
