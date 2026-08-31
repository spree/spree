import { zodResolver } from '@hookform/resolvers/zod'
import type { Address, Company, CompanyInvitation, CompanyMembership } from '@spree/admin-sdk'
import {
  adminClient,
  mapSpreeErrorsToForm,
  PageHeader,
  Slot,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  AddressBookRow,
  Badge,
  Button,
  Card,
  CardAction,
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
  useConfirm,
} from '@spree/dashboard-ui'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { EllipsisVerticalIcon, PlusIcon, TrashIcon } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { CompanyAddressSheet } from '../../../../components/spree/company-address-sheet'
import { CompanyKindBadge } from '../../../../components/spree/company-kind-badge'
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
import { spreeJsonLinkResolver } from '../../../../lib/json-link-resolver'
import {
  COMPANY_CHILD_DEFAULTS,
  COMPANY_DEFAULTS,
  COMPANY_KINDS,
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
          resource={{ id: company.id }}
          jsonPreview={{
            title: `Company ${company.name}`,
            fetch: () => adminClient.companies.get(company.id),
            endpoint: `/api/v3/admin/companies/${company.id}`,
            resolveLink: spreeJsonLinkResolver(storeId),
          }}
          onDelete={permissions.can('destroy', Subject.Company) ? handleDelete : undefined}
          deleteLabel={t('admin.companies.detail.delete_label')}
        />
      }
      main={
        <>
          <SubUnitsCard company={company} canEdit={canEdit} />
          <MembersCard company={company} canEdit={canEdit} />
          {!isDivision && <TaxExemptionCertificatesCard companyId={company.id} canEdit={canEdit} />}
          {/* Company-wide panels an extension owns: roles, purchase limits,
              approval settings (docs: Enterprise b2b-companies plan). */}
          <Slot name="company.form_main" context={{ company, kind: company.kind, canEdit }} />
        </>
      }
      sidebar={
        <>
          <CompanyProfileCard company={company} canEdit={canEdit} />
          <AddressBookCard company={company} canEdit={canEdit} />
          {isDivision ? (
            <DivisionTaxPointerCard legalEntity={legalEntity} />
          ) : (
            <CompanyTaxIdentifiersCard companyId={company.id} canEdit={canEdit} />
          )}
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
            <p className="text-destructive text-sm" role="alert">
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
        <p className="text-muted-foreground text-sm">
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
    <Card>
      <CardHeader>
        <CardTitle>
          {t('admin.companies.sub_units.title')}
          {meta?.count ? <Badge variant="outline">{meta.count}</Badge> : null}
        </CardTitle>
        {canEdit && (
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.companies.sub_units.add_cta')}
            </Button>
          </CardAction>
        )}
      </CardHeader>

      {isLoading ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        </CardContent>
      ) : children.length === 0 ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.companies.sub_units.empty')}</p>
        </CardContent>
      ) : (
        <CardContent className="p-0">
          <div className="flex flex-col">
            {children.map((child) => (
              <Link
                key={child.id}
                to={'/$storeId/companies/$companyId' as string}
                params={{ storeId, companyId: child.id }}
                className="flex items-center justify-between gap-3 border-b px-6 py-3 no-underline last:border-b-0 hover:bg-accent/50"
              >
                <span className="flex min-w-0 items-center gap-2">
                  <span className="truncate font-medium text-foreground text-sm">{child.name}</span>
                  <CompanyKindBadge kind={child.kind} />
                </span>
                <span className="shrink-0 text-muted-foreground text-xs">
                  {t('admin.companies.members_count', { count: child.members_count })}
                </span>
              </Link>
            ))}
          </div>
          {meta && meta.pages > 1 && <Pagination meta={meta} onPageChange={setPage} />}
        </CardContent>
      )}

      {addOpen && <AddSubUnitDialog parent={company} open onOpenChange={setAddOpen} />}
    </Card>
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
              <p className="text-destructive text-sm" role="alert">
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
    <Card>
      <CardHeader>
        <CardTitle>
          {t('admin.company_addresses.title')}
          {meta?.count ? <Badge variant="outline">{meta.count}</Badge> : null}
        </CardTitle>
        {canEdit && (
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setEditing('new')}>
              <PlusIcon className="size-4" />
              {t('admin.company_addresses.add_cta')}
            </Button>
          </CardAction>
        )}
      </CardHeader>

      {isLoading ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        </CardContent>
      ) : entries.length === 0 ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.company_addresses.empty')}</p>
        </CardContent>
      ) : (
        <CardContent className="flex flex-col gap-4">
          {entries.map((entry) => (
            <AddressBookRow
              key={entry.id}
              address={entry}
              canEdit={canEdit}
              onEdit={() => setEditing(entry)}
              onSetDefaultBilling={() => setDefault(entry.id, 'billing')}
              onSetDefaultShipping={() => setDefault(entry.id, 'shipping')}
              onRemove={() => handleRemove(entry)}
            />
          ))}
          {meta && meta.pages > 1 && <Pagination meta={meta} onPageChange={setPage} />}
        </CardContent>
      )}

      {editing && (
        <CompanyAddressSheet
          companyId={company.id}
          companyName={company.name}
          entry={editing === 'new' ? undefined : editing}
          open
          onOpenChange={(open) => !open && setEditing(null)}
        />
      )}
    </Card>
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
    <Card>
      <CardHeader>
        <CardTitle>
          {t('admin.company_memberships.title')}
          {meta?.count ? <Badge variant="outline">{meta.count}</Badge> : null}
        </CardTitle>
        {canEdit && (
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.company_memberships.add_cta')}
            </Button>
          </CardAction>
        )}
      </CardHeader>

      {isLoading ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        </CardContent>
      ) : memberships.length === 0 ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.company_memberships.empty')}</p>
        </CardContent>
      ) : (
        <CardContent className="p-0">
          <div className="flex flex-col">
            {memberships.map((membership) => (
              <div
                key={membership.id}
                className="flex items-center justify-between gap-3 border-b px-6 py-3 last:border-b-0"
              >
                <div className="flex min-w-0 flex-col">
                  <Link
                    to={'/$storeId/customers/$customerId' as string}
                    params={{ storeId, customerId: membership.customer_id }}
                    className="font-medium text-foreground text-sm no-underline hover:underline"
                  >
                    {membership.email ?? membership.customer_id}
                  </Link>
                  {/* Where the member's role renders once an extension owns
                      one; OSS grants every member the same standing, so there
                      is nothing to show without one. */}
                  <Slot
                    name="company_membership.row_meta"
                    context={{ membership, companyId: company.id, canEdit }}
                  />
                </div>
                {canEdit && (
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" size="icon-xs">
                        <EllipsisVerticalIcon className="size-4" />
                        <span className="sr-only">{t('admin.actions.actions_menu')}</span>
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      {/* Above the destructive item, so "change role" never
                          sits next to "remove member". */}
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
                )}
              </div>
            ))}
          </div>
          {meta && meta.pages > 1 && <Pagination meta={meta} onPageChange={setPage} />}
        </CardContent>
      )}

      <PendingInvitations company={company} canEdit={canEdit} />

      {addOpen && <AddMemberDialog companyId={company.id} open onOpenChange={setAddOpen} />}
    </Card>
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
    <CardContent className="border-t pt-4">
      <p className="mb-2 font-medium text-muted-foreground text-xs uppercase">
        {t('admin.company_invitations.pending_title')}
      </p>
      <div className="flex flex-col gap-2">
        {pending.map((invitation) => (
          <div key={invitation.id} className="flex items-center justify-between gap-3">
            <span className="min-w-0 truncate text-foreground text-sm">{invitation.email}</span>
            <span className="flex shrink-0 items-center gap-2">
              <Badge variant="secondary">{t('admin.company_invitations.status.pending')}</Badge>
              {canEdit && (
                <Button
                  variant="ghost"
                  size="icon-xs"
                  onClick={() => handleRevoke(invitation)}
                  aria-label={t('admin.company_invitations.revoke_action')}
                >
                  <TrashIcon className="size-4" />
                </Button>
              )}
            </span>
          </div>
        ))}
      </div>
      {meta && meta.pages > 1 && <Pagination meta={meta} onPageChange={setPage} />}
    </CardContent>
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
  const [email, setEmail] = useState('')
  // Written by whatever the `company_membership.form_fields` slot renders (the
  // Enterprise role picker); merged into the create payload untouched, so core
  // never needs to know which fields that plugin owns.
  const [extraParams, setExtraParams] = useState<Record<string, unknown>>({})

  async function handleSubmit() {
    if (!email) return
    await addMutation
      .mutateAsync({ ...extraParams, customer_email: email })
      .then(() => onOpenChange(false))
      .catch(() => undefined)
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
            <Field>
              <FieldLabel htmlFor="member-email">{t('admin.fields.email.label')}</FieldLabel>
              <Input
                id="member-email"
                type="email"
                autoFocus
                placeholder={t('admin.fields.company_membership.email.placeholder')}
                value={email}
                onChange={(event) => setEmail(event.target.value)}
              />
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
          <Button type="button" disabled={addMutation.isPending || !email} onClick={handleSubmit}>
            {addMutation.isPending ? t('admin.actions.saving') : t('admin.actions.add')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
