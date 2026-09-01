import { zodResolver } from '@hookform/resolvers/zod'
import type { Company } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { useCreateCompany, useDeleteCompany } from '../../../../hooks/use-companies'
import {
  COMPANY_DEFAULTS,
  type CompanyFormValues,
  companyFormSchema,
  companyValuesToParams,
} from '../../../../schemas/company'
import '../../../../tables/companies'

const companiesSearchSchema = resourceSearchSchema.extend({
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/companies/')({
  validateSearch: companiesSearchSchema,
  component: CompaniesPage,
})

function CompaniesPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch() as z.infer<typeof companiesSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteCompany()
  const { permissions } = usePermissions()

  const isCreating = !!search.new

  function openDetail(id: string) {
    navigate({ to: '/$storeId/companies/$companyId', params: { storeId, companyId: id } })
  }

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  useRowClickBridge('data-company-id', openDetail)

  async function handleDelete(company: Company) {
    const ok = await confirm({
      title: t('admin.companies.delete_confirm.title'),
      message: t('admin.companies.delete_confirm.message', { name: company.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(company.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<Company>
        tableKey="companies"
        queryKey="companies"
        queryFn={(params) => adminClient.companies.list(params)}
        searchParams={search}
        rowActions={(company) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openDetail(company.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.Company),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(company),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.Company}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.companies.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateCompanySheet open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreateCompanySheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const createMutation = useCreateCompany()
  const form = useForm<CompanyFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(companyFormSchema) as any,
    defaultValues: COMPANY_DEFAULTS,
  })

  // A new root is always a legal entity; sub-units are added from the node
  // page, where the parent is unambiguous. Members, addresses and tax
  // registrations also live there — so that is where the merchant is headed.
  async function onSubmit(values: CompanyFormValues) {
    try {
      const company = await createMutation.mutateAsync(companyValuesToParams(values))
      form.reset(COMPANY_DEFAULTS)
      onOpenChange(false)
      navigate({
        to: '/$storeId/companies/$companyId',
        params: { storeId, companyId: company.id },
      })
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(COMPANY_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.companies.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.companies.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FieldGroup>
              {errors.root?.message && (
                <p className="text-destructive text-sm" role="alert">
                  {errors.root.message}
                </p>
              )}
              <Field>
                <FieldLabel htmlFor="name">{t('admin.fields.name.label')}</FieldLabel>
                <Input
                  id="name"
                  autoFocus
                  placeholder={t('admin.fields.company.name.placeholder')}
                  aria-invalid={!!errors.name || undefined}
                  {...form.register('name')}
                />
                <FieldError errors={[errors.name]} />
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.companies.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
