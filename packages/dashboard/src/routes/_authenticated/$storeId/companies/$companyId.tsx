import { zodResolver } from '@hookform/resolvers/zod'
import type { Company, CompanyLocation } from '@spree/admin-sdk'
import {
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
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  ErrorState,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Pagination,
  ResourceLayout,
} from '@spree/dashboard-ui'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { CompanyLocationSheet } from '../../../../components/spree/company-location-sheet'
import { ResourceDetailSkeleton } from '../../../../components/spree/route-pending'
import { TaxExemptionCertificatesCard } from '../../../../components/spree/tax-exemption-certificates-card'
import { TaxIdentifiersCard } from '../../../../components/spree/tax-identifiers-card'
import {
  useCompany,
  useCompanyLocations,
  useCompanyTaxIdentifiers,
  useCreateCompanyTaxIdentifier,
  useDeleteCompany,
  useDeleteCompanyTaxIdentifier,
  useUpdateCompany,
  useUpdateCompanyTaxIdentifier,
  useValidateCompanyTaxIdentifier,
} from '../../../../hooks/use-companies'
import { spreeJsonLinkResolver } from '../../../../lib/json-link-resolver'
import {
  COMPANY_DEFAULTS,
  type CompanyFormValues,
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

  return <CompanyBody company={company} />
}

function CompanyBody({ company }: { company: Company }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const { permissions } = usePermissions()
  const deleteMutation = useDeleteCompany()

  const canEdit = permissions.can('update', Subject.Company)

  async function handleDelete() {
    await deleteMutation.mutateAsync(company.id)
    navigate({ to: '/$storeId/companies', params: { storeId } })
  }

  return (
    <ResourceLayout
      header={
        <PageHeader
          title={company.name}
          backTo="companies"
          resource={{ id: company.id }}
          onDelete={permissions.can('destroy', Subject.Company) ? handleDelete : undefined}
          jsonPreview={{
            title: `Company ${company.name}`,
            // Reuse what `useCompany` already loaded — opening the drawer
            // shouldn't trigger a duplicate fetch.
            fetch: () => Promise.resolve(company),
            endpoint: `/api/v3/admin/companies/${company.id}`,
            resolveLink: spreeJsonLinkResolver(storeId),
          }}
          deleteLabel={t('admin.companies.detail.delete_label')}
        />
      }
      main={
        <>
          <CompanyLocationsCard company={company} canEdit={canEdit} />
          <TaxExemptionCertificatesCard companyId={company.id} canEdit={canEdit} />
          {/* Company-wide panels an extension owns: roles, purchase limits,
              approval settings (docs: Enterprise b2b-companies plan). */}
          <Slot name="company.form_main" context={{ company, canEdit }} />
        </>
      }
      sidebar={
        <>
          <CompanyProfileCard company={company} canEdit={canEdit} />
          <CompanyTaxIdentifiersCard companyId={company.id} canEdit={canEdit} />
          <Slot name="company.form_sidebar" context={{ company, canEdit }} />
        </>
      }
    />
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
    form.reset({ name: company.name })
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

function CompanyLocationsCard({ company, canEdit }: { company: Company; canEdit: boolean }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const [page, setPage] = useState(1)
  const { data, isLoading } = useCompanyLocations(company.id, page)
  const [addOpen, setAddOpen] = useState(false)

  const locations = data?.data ?? []
  const meta = data?.meta

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          {t('admin.company_locations.title')}
          {meta?.count ? <Badge variant="outline">{meta.count}</Badge> : null}
        </CardTitle>
        {canEdit && (
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.company_locations.add_cta')}
            </Button>
          </CardAction>
        )}
      </CardHeader>

      {isLoading ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        </CardContent>
      ) : locations.length === 0 ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.company_locations.empty')}</p>
        </CardContent>
      ) : (
        <CardContent className="p-0">
          <div className="flex flex-col">
            {locations.map((location: CompanyLocation) => (
              <Link
                key={location.id}
                to={'/$storeId/companies/locations/$locationId' as string}
                params={{ storeId, locationId: location.id }}
                className="flex items-start justify-between gap-3 border-b px-6 py-3 no-underline last:border-b-0 hover:bg-muted/50"
              >
                <div className="flex min-w-0 flex-col">
                  <span className="font-medium text-foreground text-sm">{location.name}</span>
                  <span className="text-muted-foreground text-xs">
                    {[location.billing_address?.city, location.billing_address?.country_name]
                      .filter(Boolean)
                      .join(', ')}
                  </span>
                </div>
                <span className="shrink-0 text-muted-foreground text-xs">
                  {t('admin.company_locations.contacts_count', {
                    count: location.contacts_count,
                  })}
                </span>
              </Link>
            ))}
          </div>
          {meta && <Pagination meta={meta} onPageChange={setPage} />}
        </CardContent>
      )}

      {addOpen && <CompanyLocationSheet companyId={company.id} open onOpenChange={setAddOpen} />}
    </Card>
  )
}
