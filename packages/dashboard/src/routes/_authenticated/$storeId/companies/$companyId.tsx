import { zodResolver } from '@hookform/resolvers/zod'
import type {
  Address,
  Company,
  CompanyInvitation,
  CompanyMembership,
  Customer,
} from '@spree/admin-sdk'
import { COMPANY_KINDS } from '@spree/core'
import {
  mapSpreeErrorsToForm,
  PageHeader,
  RecordMetadataCard,
  Slot,
  Subject,
  usePermissions,
  useServerErrors,
} from '@spree/dashboard-core'
import {
  AddressBookTable,
  AddressBookTableRow,
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
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Empty,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  ErrorState,
  Field,
  FieldContent,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Pagination,
  ResourceLayout,
  Section,
  SectionActions,
  SectionHeader,
  SectionTitle,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  Building2Icon,
  EllipsisVerticalIcon,
  MapPinIcon,
  PlusIcon,
  TrashIcon,
  UsersIcon,
} from '@spree/dashboard-ui/icons'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { useEffect, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { CompanyAddressSheet } from '../../../../components/spree/company-address-sheet'
import { CompanyKindBadge } from '../../../../components/spree/company-kind-badge'
import { ApiCustomFieldsCard } from '../../../../components/spree/custom-fields/custom-fields-inline'
import { CustomerCombobox } from '../../../../components/spree/customers/customer-combobox'
import { CustomerIdentity } from '../../../../components/spree/customers/customer-identity'
import { EnterpriseUpsell } from '../../../../components/spree/enterprise-upsell'
import { ResourceDetailSkeleton } from '../../../../components/spree/route-pending'
import { TaxExemptionCertificatesCard } from '../../../../components/spree/tax-exemption-certificates-card'
import { TaxIdentifiersCard } from '../../../../components/spree/tax-identifiers-card'
import {
  useAddCompanyMember,
  useCompany,
  useCompanyAddresses,
  useCompanyChildren,
  useCompanyInvitations,
  useCompanyMemberships,
  useCompanyTaxIdentifiers,
  useCreateCompany,
  useCreateCompanyTaxIdentifier,
  useDeleteCompany,
  useDeleteCompanyAddress,
  useDeleteCompanyMembership,
  useDeleteCompanyTaxIdentifier,
  useRevokeCompanyInvitation,
  useUpdateCompany,
  useUpdateCompanyAddress,
  useUpdateCompanyTaxIdentifier,
  useValidateCompanyTaxIdentifier,
} from '../../../../hooks/use-companies'
import {
  COMPANY_CHILD_DEFAULTS,
  COMPANY_DEFAULTS,
  type CompanyChildFormValues,
  type CompanyFormValues,
  companyChildFormSchema,
  companyFormSchema,
  companyValuesToParams,
} from '../../../../schemas/company'

export const Route = createFileRoute('/_authenticated/$storeId/companies/$companyId')({
  component: CompanyDetailPage,
})

function CompanyDetailPage() {
  const { t } = useTranslation()
  const { companyId } = Route.useParams()
  const { data: company, isLoading, error, refetch } = useCompany(companyId)

  if (isLoading) return <ResourceDetailSkeleton />
  if (error || !company) {
    return (
      <ErrorState
        title={t('admin.companies.detail.load_error')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <CompanyBody key={company.id} company={company} />
}

function CompanyBody({ company }: { company: Company }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const { permissions } = usePermissions()
  const deleteMutation = useDeleteCompany()

  const canEdit = permissions.can('update', Subject.Company)
  const isDivision = company.kind === 'division'
  // The nearest self-or-ancestor legal entity — where a division's tax
  // registrations actually live. Ancestors arrive root-first.
  const legalEntity = isDivision
    ? [...company.ancestors].reverse().find((ancestor) => ancestor.kind === 'company')
    : undefined

  async function handleDelete() {
    await deleteMutation.mutateAsync(company.id)
    navigate({ to: '/$storeId/companies', params: { storeId } })
  }

  return (
    <ResourceLayout
      header={
        <PageHeader
          title={company.name}
          subtitle={<AncestorBreadcrumb company={company} />}
          badges={<CompanyKindBadge kind={company.kind} />}
          backTo="companies"
          resource={company}
          endpoint={`/api/v3/admin/companies/${company.id}`}
          onDelete={permissions.can('destroy', Subject.Company) ? handleDelete : undefined}
          deleteLabel={t('admin.companies.detail.delete_label')}
        />
      }
      main={
        <>
          <SubUnitsCard company={company} canEdit={canEdit} />
          <MembersCard company={company} canEdit={canEdit} />
          {!isDivision && <TaxExemptionCertificatesCard companyId={company.id} canEdit={canEdit} />}
          <AddressBookCard company={company} canEdit={canEdit} />
          {!isDivision && <CompanyTaxIdentifiersCard companyId={company.id} canEdit={canEdit} />}
          <ApiCustomFieldsCard ownerType="company" ownerId={company.id} collapsible />
          <RecordMetadataCard
            metadata={company.metadata}
            externalReferences={company.external_references}
          />
          {/* Company-wide panels an extension owns: roles, purchase limits,
              approval settings (docs: Enterprise b2b-companies plan). */}
          <Slot name="company.form_main" context={{ company, kind: company.kind, canEdit }} />
        </>
      }
      sidebar={
        <>
          <CompanyProfileCard company={company} canEdit={canEdit} />
          {/* A sub-unit holds no registrations of its own; this points to the
              legal entity that does. */}
          {isDivision && <DivisionTaxPointerCard legalEntity={legalEntity} />}
          <Slot name="company.form_sidebar" context={{ company, kind: company.kind, canEdit }} />
        </>
      }
    />
  )
}

/** "Acme / EMEA" — the path above this node, each level a link. */
function AncestorBreadcrumb({ company }: { company: Company }) {
  const { storeId } = Route.useParams()

  if (company.ancestors.length === 0) return null

  return (
    <span className="flex flex-wrap items-center gap-1">
      {company.ancestors.map((ancestor, index) => (
        <span key={ancestor.id} className="flex items-center gap-1">
          {index > 0 && <span>/</span>}
          <Link
            to={'/$storeId/companies/$companyId' as string}
            params={{ storeId, companyId: ancestor.id }}
            className="no-underline hover:underline"
          >
            {ancestor.name}
          </Link>
        </span>
      ))}
    </span>
  )
}

function CompanyProfileCard({ company, canEdit }: { company: Company; canEdit: boolean }) {
  const { t } = useTranslation()
  const updateMutation = useUpdateCompany(company.id)

  const form = useForm<CompanyFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(companyFormSchema) as any,
    defaultValues: COMPANY_DEFAULTS,
  })

  useEffect(() => {
    form.reset({ name: company.name, po_number_required: company.po_number_required ?? false })
  }, [company, form])

  async function onSubmit(values: CompanyFormValues) {
    try {
      await updateMutation.mutateAsync(companyValuesToParams(values))
      form.reset(values)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.companies.detail.profile')}</CardTitle>
      </CardHeader>
      <CardContent>
        <FieldGroup>
          {errors.root?.message && (
            <p className="text-destructive text-base" role="alert">
              {errors.root.message}
            </p>
          )}
          <Field>
            <FieldLabel htmlFor="company-name">{t('admin.fields.name.label')}</FieldLabel>
            <Input
              id="company-name"
              disabled={!canEdit}
              aria-invalid={!!errors.name || undefined}
              {...form.register('name')}
            />
            <FieldError errors={[errors.name]} />
          </Field>
          {/* Hung on the company because it describes this buyer's own
              procurement process, not the merchant's agreement with them. */}
          <Field orientation="horizontal">
            <Controller
              control={form.control}
              name="po_number_required"
              render={({ field }) => (
                <Switch
                  id="company-po-number-required"
                  disabled={!canEdit}
                  checked={field.value}
                  onCheckedChange={field.onChange}
                />
              )}
            />
            <FieldContent>
              <FieldLabel htmlFor="company-po-number-required">
                {t('admin.fields.company.po_number_required.label')}
              </FieldLabel>
              <FieldDescription>
                {t('admin.fields.company.po_number_required.help')}
              </FieldDescription>
            </FieldContent>
          </Field>
          {canEdit && (
            <div className="flex justify-end">
              {/* This card sits inside a page that is not itself a form, but
                  keep it a button so nesting never becomes a problem. */}
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
        </FieldGroup>
      </CardContent>
    </Card>
  )
}

/** Where a division's registrations live: on its legal entity, one click away. */
function DivisionTaxPointerCard({ legalEntity }: { legalEntity?: { id: string; name: string } }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.tax_identifiers.title')}</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-muted-foreground text-base">
          {t('admin.companies.detail.division_tax_pointer')}{' '}
          {legalEntity && (
            <Link
              to={'/$storeId/companies/$companyId' as string}
              params={{ storeId, companyId: legalEntity.id }}
              className="font-medium text-foreground no-underline hover:underline"
            >
              {legalEntity.name}
            </Link>
          )}
        </p>
      </CardContent>
    </Card>
  )
}

function CompanyTaxIdentifiersCard({
  companyId,
  canEdit,
}: {
  companyId: string
  canEdit: boolean
}) {
  const { data, isLoading } = useCompanyTaxIdentifiers(companyId)
  const createMutation = useCreateCompanyTaxIdentifier(companyId)
  const updateMutation = useUpdateCompanyTaxIdentifier(companyId)
  const deleteMutation = useDeleteCompanyTaxIdentifier(companyId)
  const validateMutation = useValidateCompanyTaxIdentifier(companyId)

  return (
    <TaxIdentifiersCard
      identifiers={data?.data ?? []}
      isLoading={isLoading}
      canEdit={canEdit}
      mutations={{
        create: (params) => createMutation.mutateAsync(params),
        update: (id, params) => updateMutation.mutateAsync({ id, params }),
        remove: (id) => deleteMutation.mutateAsync(id),
        validate: (id) => validateMutation.mutateAsync(id),
        isValidating: validateMutation.isPending,
      }}
    />
  )
}

function SubUnitsCard({ company, canEdit }: { company: Company; canEdit: boolean }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const [page, setPage] = useState(1)
  const { data, isLoading } = useCompanyChildren(company.id, page)
  const [addOpen, setAddOpen] = useState(false)

  const children = data?.data ?? []
  const meta = data?.meta

  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <Building2Icon />
          {t('admin.companies.sub_units.title')}
          {meta?.count ? <Badge variant="outline">{meta.count}</Badge> : null}
        </SectionTitle>
        {canEdit && (
          <SectionActions>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.companies.sub_units.add_cta')}
            </Button>
          </SectionActions>
        )}
      </SectionHeader>

      <Card>
        {isLoading || children.length === 0 ? (
          <CardContent>
            {isLoading ? (
              <p className="text-muted-foreground text-base">{t('admin.common.loading')}</p>
            ) : (
              <Empty className="p-4">
                <EmptyHeader>
                  <EmptyMedia variant="icon">
                    <Building2Icon />
                  </EmptyMedia>
                  <EmptyTitle>{t('admin.companies.sub_units.empty')}</EmptyTitle>
                </EmptyHeader>
              </Empty>
            )}
          </CardContent>
        ) : (
          <>
            <Table roundedTop>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.fields.name.label')}</TableHead>
                  <TableHead className="text-right">
                    {t('admin.company_memberships.title')}
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {children.map((child) => (
                  <TableRow key={child.id}>
                    <TableCell>
                      <Link
                        to={'/$storeId/companies/$companyId' as string}
                        params={{ storeId, companyId: child.id }}
                        className="flex min-w-0 items-center gap-2 rounded-md text-foreground no-underline outline-none focus-visible:shadow-field-focus"
                      >
                        <span className="truncate font-medium text-base">{child.name}</span>
                        <CompanyKindBadge kind={child.kind} />
                      </Link>
                    </TableCell>
                    <TableCell className="text-right text-muted-foreground tabular-nums">
                      {child.members_count}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            {meta && meta.pages > 1 && <Pagination inset meta={meta} onPageChange={setPage} />}
          </>
        )}
      </Card>

      {addOpen && <AddSubUnitDialog parent={company} open onOpenChange={setAddOpen} />}
    </Section>
  )
}

function AddSubUnitDialog({
  parent,
  open,
  onOpenChange,
}: {
  parent: Company
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateCompany()

  const form = useForm<CompanyChildFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(companyChildFormSchema) as any,
    defaultValues: COMPANY_CHILD_DEFAULTS,
  })

  const kindOptions = COMPANY_KINDS.map((kind) => ({
    value: kind,
    label:
      kind === 'company' ? t('admin.companies.kind.company') : t('admin.companies.kind.division'),
  }))

  async function onSubmit(values: CompanyChildFormValues) {
    try {
      await createMutation.mutateAsync({ ...values, parent_id: parent.id })
      form.reset(COMPANY_CHILD_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {t('admin.companies.sub_units.add_title', { name: parent.name })}
          </DialogTitle>
          <DialogDescription>{t('admin.companies.sub_units.add_description')}</DialogDescription>
        </DialogHeader>
        <DialogBody>
          <FieldGroup>
            {errors.root?.message && (
              <p className="text-destructive text-base" role="alert">
                {errors.root.message}
              </p>
            )}
            <Field>
              <FieldLabel htmlFor="sub-unit-name">{t('admin.fields.name.label')}</FieldLabel>
              <Input
                id="sub-unit-name"
                autoFocus
                aria-invalid={!!errors.name || undefined}
                {...form.register('name')}
              />
              <FieldError errors={[errors.name]} />
            </Field>
            <Field>
              <FieldLabel htmlFor="sub-unit-kind">
                {t('admin.fields.company.kind.label')}
              </FieldLabel>
              <Controller
                control={form.control}
                name="kind"
                render={({ field }) => (
                  <Select
                    items={kindOptions}
                    value={field.value}
                    onValueChange={(value) => field.onChange(value)}
                  >
                    <SelectTrigger id="sub-unit-kind">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {kindOptions.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
              <FieldDescription>{t('admin.fields.company.kind.help')}</FieldDescription>
            </Field>
          </FieldGroup>
        </DialogBody>
        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={form.formState.isSubmitting}
          >
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={form.formState.isSubmitting}
            onClick={form.handleSubmit(onSubmit)}
          >
            {form.formState.isSubmitting ? t('admin.actions.creating') : t('admin.actions.create')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function AddressBookCard({ company, canEdit }: { company: Company; canEdit: boolean }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const [page, setPage] = useState(1)
  const { data, isLoading } = useCompanyAddresses(company.id, page)
  const deleteMutation = useDeleteCompanyAddress(company.id)
  const updateMutation = useUpdateCompanyAddress(company.id)
  const [editing, setEditing] = useState<Address | 'new' | null>(null)

  // The node points at one address per kind, so promoting simply moves the
  // pointer — nothing to demote.
  function setDefault(id: string, kind: 'billing' | 'shipping') {
    return updateMutation.mutate({
      id,
      params: { [kind === 'billing' ? 'default_billing' : 'default_shipping']: true },
    })
  }

  const entries = data?.data ?? []
  const meta = data?.meta

  async function handleRemove(entry: Address) {
    const ok = await confirm({
      title: t('admin.company_addresses.remove_confirm.title'),
      message: t('admin.company_addresses.remove_confirm.message', {
        label: entry.label || entry.address1 || '',
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(entry.id).catch(() => undefined)
  }

  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <MapPinIcon />
          {t('admin.company_addresses.title')}
          {meta?.count ? <Badge variant="outline">{meta.count}</Badge> : null}
        </SectionTitle>
        {canEdit && (
          <SectionActions>
            <Button size="sm" variant="outline" onClick={() => setEditing('new')}>
              <PlusIcon className="size-4" />
              {t('admin.company_addresses.add_cta')}
            </Button>
          </SectionActions>
        )}
      </SectionHeader>

      <Card>
        {isLoading || entries.length === 0 ? (
          <CardContent>
            {isLoading ? (
              <p className="text-muted-foreground text-base">{t('admin.common.loading')}</p>
            ) : (
              <Empty className="p-4">
                <EmptyHeader>
                  <EmptyMedia variant="icon">
                    <MapPinIcon />
                  </EmptyMedia>
                  <EmptyTitle>{t('admin.company_addresses.empty')}</EmptyTitle>
                </EmptyHeader>
              </Empty>
            )}
          </CardContent>
        ) : (
          <>
            <AddressBookTable>
              {entries.map((entry) => (
                <AddressBookTableRow
                  key={entry.id}
                  address={entry}
                  canEdit={canEdit}
                  inheritedFrom={
                    entry.owner && entry.owner.id !== company.id ? (entry.owner.name ?? '') : null
                  }
                  onEdit={() => setEditing(entry)}
                  onSetDefaultBilling={() => setDefault(entry.id, 'billing')}
                  onSetDefaultShipping={() => setDefault(entry.id, 'shipping')}
                  onRemove={() => handleRemove(entry)}
                />
              ))}
            </AddressBookTable>
            {meta && meta.pages > 1 && <Pagination inset meta={meta} onPageChange={setPage} />}
          </>
        )}
      </Card>

      {editing && (
        <CompanyAddressSheet
          companyId={company.id}
          companyName={company.name}
          entry={editing === 'new' ? undefined : editing}
          open
          onOpenChange={(open) => !open && setEditing(null)}
        />
      )}
    </Section>
  )
}

function MembersCard({ company, canEdit }: { company: Company; canEdit: boolean }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const confirm = useConfirm()
  const [page, setPage] = useState(1)
  const { data, isLoading } = useCompanyMemberships(company.id, page)
  const deleteMutation = useDeleteCompanyMembership(company.id)
  const [addOpen, setAddOpen] = useState(false)

  const memberships = data?.data ?? []
  const meta = data?.meta

  async function handleRemove(membership: CompanyMembership) {
    const ok = await confirm({
      title: t('admin.company_memberships.remove_confirm.title'),
      message: t('admin.company_memberships.remove_confirm.message', {
        email: membership.email ?? membership.customer_id,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.company_memberships.remove_action'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(membership.id).catch(() => undefined)
  }

  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <UsersIcon />
          {t('admin.company_memberships.title')}
          {meta?.count ? <Badge variant="outline">{meta.count}</Badge> : null}
        </SectionTitle>
        {canEdit && (
          <SectionActions>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.company_memberships.add_cta')}
            </Button>
          </SectionActions>
        )}
      </SectionHeader>

      {/* One card: the members as a table, then any pending invitations. */}
      <Card>
        {isLoading || memberships.length === 0 ? (
          <CardContent>
            {isLoading ? (
              <p className="text-muted-foreground text-base">{t('admin.common.loading')}</p>
            ) : (
              <Empty className="p-4">
                <EmptyHeader>
                  <EmptyMedia variant="icon">
                    <UsersIcon />
                  </EmptyMedia>
                  <EmptyTitle>{t('admin.company_memberships.empty')}</EmptyTitle>
                </EmptyHeader>
              </Empty>
            )}
          </CardContent>
        ) : (
          <>
            <Table roundedTop>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.company_memberships.columns.member')}</TableHead>
                  {canEdit && <TableHead className="w-10" />}
                </TableRow>
              </TableHeader>
              <TableBody>
                {memberships.map((membership) => (
                  <TableRow key={membership.id}>
                    <TableCell>
                      <CustomerIdentity
                        customer={membership.customer}
                        email={membership.email}
                        linkTo={{ storeId, customerId: membership.customer_id }}
                      />
                      {/* Where the member's role renders once an extension
                          owns one; OSS grants every member the same standing,
                          so there is nothing to show without one. */}
                      <Slot
                        name="company_membership.row_meta"
                        context={{ membership, companyId: company.id, canEdit }}
                      />
                    </TableCell>
                    {canEdit && (
                      <TableCell className="w-10 text-right">
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="icon-xs">
                              <EllipsisVerticalIcon className="size-4" />
                              <span className="sr-only">{t('admin.actions.actions_menu')}</span>
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            {/* Above the destructive item, so "change role"
                                never sits next to "remove member". */}
                            <Slot
                              name="company_membership.row_actions"
                              context={{ membership, companyId: company.id }}
                            />
                            <DropdownMenuItem
                              variant="destructive"
                              onClick={() => handleRemove(membership)}
                            >
                              <TrashIcon className="size-4" />
                              {t('admin.company_memberships.remove_action')}
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </TableCell>
                    )}
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            {meta && meta.pages > 1 && <Pagination inset meta={meta} onPageChange={setPage} />}
          </>
        )}
        <PendingInvitations company={company} canEdit={canEdit} />
      </Card>

      {addOpen && <AddMemberDialog companyId={company.id} open onOpenChange={setAddOpen} />}
    </Section>
  )
}

function PendingInvitations({ company, canEdit }: { company: Company; canEdit: boolean }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const [page, setPage] = useState(1)
  const { data } = useCompanyInvitations(company.id, page)
  const revokeMutation = useRevokeCompanyInvitation(company.id)

  // The endpoint returns pending invitations only, so the count and pages
  // describe the same set the panel renders.
  const pending = data?.data ?? []
  const meta = data?.meta

  if (pending.length === 0) return null

  async function handleRevoke(invitation: CompanyInvitation) {
    const ok = await confirm({
      title: t('admin.company_invitations.revoke_confirm.title'),
      message: t('admin.company_invitations.revoke_confirm.message', { email: invitation.email }),
      variant: 'destructive',
      confirmLabel: t('admin.company_invitations.revoke_action'),
    })
    if (!ok) return
    await revokeMutation.mutateAsync(invitation.id).catch(() => undefined)
  }

  return (
    <div className="border-border-subtle border-t">
      <p className="px-3.5 pt-3 pb-1 font-medium text-muted-foreground text-xs">
        {t('admin.company_invitations.pending_title')}
      </p>
      <Table>
        <TableBody>
          {pending.map((invitation) => (
            <TableRow key={invitation.id}>
              <TableCell>
                <CustomerIdentity email={invitation.email} />
              </TableCell>
              <TableCell className="w-px whitespace-nowrap text-right">
                <span className="inline-flex items-center gap-2">
                  <Badge variant="secondary">{t('admin.company_invitations.status.pending')}</Badge>
                  {canEdit && (
                    <Button
                      variant="destructive-ghost"
                      size="icon-xs"
                      onClick={() => handleRevoke(invitation)}
                      aria-label={t('admin.company_invitations.revoke_action')}
                    >
                      <TrashIcon className="size-4" />
                    </Button>
                  )}
                </span>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
      {meta && meta.pages > 1 && <Pagination inset meta={meta} onPageChange={setPage} />}
    </div>
  )
}

function AddMemberDialog({
  companyId,
  open,
  onOpenChange,
}: {
  companyId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const addMutation = useAddCompanyMember(companyId)
  // An existing customer, who joins straight away, or an email to invite.
  const [customer, setCustomer] = useState<Customer | null>(null)
  const [email, setEmail] = useState('')
  // Written by whatever the `company_membership.form_fields` slot renders (the
  // Enterprise role picker); merged into the create payload untouched, so core
  // never needs to know which fields that plugin owns.
  const [extraParams, setExtraParams] = useState<Record<string, unknown>>({})
  const serverErrors = useServerErrors()
  const { errors } = serverErrors
  const customerError = errors.customer_id ?? errors.customer
  const emailError = errors.email ?? errors.customer_email
  // A role field from the plugin, or a refusal of the whole record.
  const summary = serverErrors.offscreenSummary([
    'customer_id',
    'customer',
    'email',
    'customer_email',
  ])

  async function handleSubmit() {
    if (!customer && !email) return
    await addMutation
      .mutateAsync({
        ...extraParams,
        ...(customer ? { customer_id: customer.id } : { customer_email: email }),
      })
      .then(() => onOpenChange(false))
      .catch(serverErrors.capture)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.company_memberships.add_title')}</DialogTitle>
          <DialogDescription>{t('admin.company_memberships.dialog_description')}</DialogDescription>
        </DialogHeader>
        <DialogBody>
          <FieldGroup>
            {summary && (
              <p className="text-base text-destructive" role="alert">
                {summary}
              </p>
            )}
            <Field>
              <FieldLabel htmlFor="member-customer">
                {t('admin.fields.customer_id.label')}
              </FieldLabel>
              <CustomerCombobox
                queryKey="company-member-customer"
                id="member-customer"
                allowCreate={false}
                value={customer?.id}
                onChange={(_id, record) => {
                  setCustomer(record)
                  if (record) setEmail('')
                  serverErrors.reset()
                }}
              />
              {customerError && <FieldError>{customerError}</FieldError>}
            </Field>
            <Field>
              <FieldLabel htmlFor="member-email">
                {t('admin.fields.company_membership.email.label')}
              </FieldLabel>
              <Input
                id="member-email"
                type="email"
                placeholder={t('admin.fields.company_membership.email.placeholder')}
                value={email}
                onChange={(event) => {
                  setEmail(event.target.value)
                  if (event.target.value) setCustomer(null)
                  serverErrors.reset()
                }}
                aria-invalid={!!emailError || undefined}
              />
              {emailError && <FieldError>{emailError}</FieldError>}
              <FieldDescription>{t('admin.fields.company_membership.email.help')}</FieldDescription>
            </Field>

            {/* Roles are an Enterprise capability. The slot is where its role
                picker mounts; with no plugin installed the fallback names the
                limit rather than leaving a gap. */}
            <Slot
              name="company_membership.form_fields"
              context={{ companyId, onChange: setExtraParams }}
              fallback={
                <EnterpriseUpsell
                  title={t('admin.company_memberships.roles_enterprise_title')}
                  description={t('admin.company_memberships.roles_enterprise_help')}
                />
              }
            />
          </FieldGroup>
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
          <Button
            type="button"
            disabled={addMutation.isPending || (!customer && !email)}
            onClick={handleSubmit}
          >
            {addMutation.isPending ? t('admin.actions.saving') : t('admin.actions.add')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
