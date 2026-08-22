import type {
  CompanyContact,
  CompanyContactParams,
  CompanyLocation,
  Customer,
} from '@spree/admin-sdk'
import {
  adminClient,
  PageHeader,
  ResourceCombobox,
  Slot,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  AddressBlock,
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
  FieldGroup,
  FieldLabel,
  Pagination,
  ResourceLayout,
  useConfirm,
} from '@spree/dashboard-ui'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { EllipsisVerticalIcon, PencilIcon, PlusIcon, TrashIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CompanyLocationSheet } from '../../../../components/spree/company-location-sheet'
import { EnterpriseUpsell } from '../../../../components/spree/enterprise-upsell'
import { ResourceDetailSkeleton } from '../../../../components/spree/route-pending'
import {
  useCompanyLocation,
  useCompanyLocationContacts,
  useCreateCompanyContact,
  useDeleteCompanyContact,
  useDeleteCompanyLocation,
} from '../../../../hooks/use-companies'
import { customerAutocompleteProps } from '../../../../hooks/use-customers'
import { spreeJsonLinkResolver } from '../../../../lib/json-link-resolver'

export const Route = createFileRoute('/_authenticated/$storeId/companies/locations/$locationId')({
  component: CompanyLocationDetailPage,
})

function CompanyLocationDetailPage() {
  const { t } = useTranslation()
  const { locationId } = Route.useParams()
  const { data: location, isLoading, error, refetch } = useCompanyLocation(locationId)

  if (isLoading) return <ResourceDetailSkeleton />
  if (error || !location) {
    return (
      <ErrorState
        title={t('admin.company_locations.detail.load_error')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <CompanyLocationBody location={location} />
}

function CompanyLocationBody({ location }: { location: CompanyLocation }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const { permissions } = usePermissions()
  const deleteMutation = useDeleteCompanyLocation(location.company_id)
  const [editOpen, setEditOpen] = useState(false)

  const canEdit = permissions.can('update', Subject.CompanyLocation)

  async function handleDelete() {
    await deleteMutation.mutateAsync(location.id)
    navigate({
      to: '/$storeId/companies/$companyId',
      params: { storeId, companyId: location.company_id },
    })
  }

  return (
    <>
      <ResourceLayout
        header={
          <PageHeader
            title={location.name}
            backTo={`companies/${location.company_id}`}
            resource={{ id: location.id }}
            jsonPreview={{
              title: `Location ${location.name}`,
              fetch: () => adminClient.companyLocations.get(location.id),
              endpoint: `/api/v3/admin/company_locations/${location.id}`,
              resolveLink: spreeJsonLinkResolver(storeId),
            }}
            actions={
              canEdit ? (
                <Button
                  variant="ghost"
                  size="icon-sm"
                  onClick={() => setEditOpen(true)}
                  aria-label={t('admin.actions.edit')}
                >
                  <PencilIcon className="size-4" />
                </Button>
              ) : undefined
            }
            onDelete={
              permissions.can('destroy', Subject.CompanyLocation) ? handleDelete : undefined
            }
            deleteLabel={t('admin.company_locations.detail.delete_label')}
          />
        }
        main={
          <>
            <ContactsCard location={location} canEdit={canEdit} />
            {/* Per-branch panels an extension owns: approval rules, spending
                limits (docs: Enterprise b2b-companies plan). */}
            <Slot name="company_location.form_main" context={{ location, canEdit }} />
          </>
        }
        sidebar={
          <>
            <AddressesCard location={location} />
            <Slot name="company_location.form_sidebar" context={{ location, canEdit }} />
          </>
        }
      />

      {editOpen && (
        <CompanyLocationSheet
          companyId={location.company_id}
          location={location}
          open
          onOpenChange={setEditOpen}
        />
      )}
    </>
  )
}

function AddressesCard({ location }: { location: CompanyLocation }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.company_locations.addresses')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <AddressBlock
          title={t('admin.company_locations.billing_address')}
          address={location.billing_address}
        />
        <AddressBlock
          title={t('admin.company_locations.shipping_address')}
          address={location.shipping_address}
        />
      </CardContent>
    </Card>
  )
}

function ContactsCard({ location, canEdit }: { location: CompanyLocation; canEdit: boolean }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const confirm = useConfirm()
  const [page, setPage] = useState(1)
  const { data, isLoading } = useCompanyLocationContacts(location.id, page)
  const deleteMutation = useDeleteCompanyContact(location.id)
  const [addOpen, setAddOpen] = useState(false)

  const contacts = data?.data ?? []
  const meta = data?.meta

  async function handleRemove(contact: CompanyContact) {
    const ok = await confirm({
      title: t('admin.company_contacts.remove_confirm.title'),
      message: t('admin.company_contacts.remove_confirm.message', {
        email: contact.email ?? contact.customer_id,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.company_contacts.remove_action'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(contact.id).catch(() => undefined)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          {t('admin.company_contacts.title')}
          {meta?.count ? <Badge variant="outline">{meta.count}</Badge> : null}
        </CardTitle>
        {canEdit && (
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.company_contacts.add_cta')}
            </Button>
          </CardAction>
        )}
      </CardHeader>

      {isLoading ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        </CardContent>
      ) : contacts.length === 0 ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.company_contacts.empty')}</p>
        </CardContent>
      ) : (
        <CardContent className="p-0">
          <div className="flex flex-col">
            {contacts.map((contact) => (
              <div
                key={contact.id}
                className="flex items-center justify-between gap-3 border-b px-6 py-3 last:border-b-0"
              >
                <div className="flex min-w-0 flex-col">
                  <Link
                    to={'/$storeId/customers/$customerId' as string}
                    params={{ storeId, customerId: contact.customer_id }}
                    className="font-medium text-foreground text-sm no-underline hover:underline"
                  >
                    {contact.email ?? contact.customer_id}
                  </Link>
                  {/* An extension owning roles renders the buyer's real role
                      here; the fallback is the cosmetic label OSS stores. */}
                  <Slot
                    name="company_contact.row_meta"
                    context={{ contact, locationId: location.id, canEdit }}
                    fallback={
                      contact.role ? (
                        <span className="text-muted-foreground text-xs">{contact.role}</span>
                      ) : null
                    }
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
                          sits next to "remove buyer". */}
                      <Slot
                        name="company_contact.row_actions"
                        context={{ contact, locationId: location.id }}
                      />
                      <DropdownMenuItem
                        className="text-destructive focus:text-destructive"
                        onClick={() => handleRemove(contact)}
                      >
                        <TrashIcon className="size-4" />
                        {t('admin.company_contacts.remove_action')}
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                )}
              </div>
            ))}
          </div>
          {meta && <Pagination meta={meta} onPageChange={setPage} />}
        </CardContent>
      )}

      {addOpen && <AddContactDialog locationId={location.id} open onOpenChange={setAddOpen} />}
    </Card>
  )
}

function AddContactDialog({
  locationId,
  open,
  onOpenChange,
}: {
  locationId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateCompanyContact(locationId)
  const [customerId, setCustomerId] = useState('')
  // Written by whatever the `company_contact.form_fields` slot renders (the
  // Enterprise role picker); merged into the create payload untouched, so core
  // never needs to know which fields that plugin owns.
  const [extraParams, setExtraParams] = useState<CompanyContactParams>({})

  async function handleSubmit() {
    if (!customerId) return
    await createMutation
      .mutateAsync({ ...extraParams, customer_id: customerId })
      .then(() => onOpenChange(false))
      .catch(() => undefined)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.company_contacts.add_title')}</DialogTitle>
          <DialogDescription>{t('admin.company_contacts.dialog_description')}</DialogDescription>
        </DialogHeader>
        <DialogBody>
          <FieldGroup>
            <Field>
              <FieldLabel>{t('admin.fields.customer.label')}</FieldLabel>
              <ResourceCombobox<Customer>
                {...customerAutocompleteProps('company-contact-customers')}
                value={customerId || undefined}
                onChange={(id) => setCustomerId(id ?? '')}
              />
            </Field>

            {/* Roles are an Enterprise capability. The slot is where its role
                picker mounts; with no plugin installed the fallback names the
                limit rather than leaving a gap. */}
            <Slot
              name="company_contact.form_fields"
              context={{ locationId, onChange: setExtraParams }}
              fallback={
                <EnterpriseUpsell
                  title={t('admin.company_contacts.roles_enterprise_title')}
                  description={t('admin.company_contacts.roles_enterprise_help')}
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
            disabled={createMutation.isPending}
          >
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={createMutation.isPending || !customerId}
            onClick={handleSubmit}
          >
            {createMutation.isPending ? t('admin.actions.saving') : t('admin.actions.add')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
