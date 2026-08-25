import { zodResolver } from '@hookform/resolvers/zod'
import type { Company } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  PageHeader,
  Subject,
  useResourceKey,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  cn,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Pagination,
  SearchInput,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Skeleton,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { Building2Icon, ChevronDownIcon, ChevronRightIcon, PlusIcon } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { CompanyKindBadge } from '../../../../components/spree/company-kind-badge'
import { useCompanyChildren, useCreateCompany } from '../../../../hooks/use-companies'
import {
  COMPANY_DEFAULTS,
  type CompanyFormValues,
  companyFormSchema,
  companyValuesToParams,
} from '../../../../schemas/company'

const companiesSearchSchema = z.object({
  new: z.coerce.boolean().optional(),
  q: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/companies/')({
  validateSearch: companiesSearchSchema,
  component: CompaniesPage,
})

function CompaniesPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof companiesSearchSchema>
  const navigate = useNavigate()

  const isCreating = !!search.new
  const query = search.q ?? ''

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  const setQuery = (value: string) =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { q: _q, ...rest } = prev
        return (value ? { ...rest, q: value } : rest) as never
      },
      replace: true,
    })

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        title={t('admin.nav.companies')}
        actions={
          <Can I="create" a={Subject.Company}>
            <Button size="sm" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.companies.add_cta')}
            </Button>
          </Can>
        }
      />

      <SearchInput
        value={query}
        onValueChange={setQuery}
        placeholder={t('admin.companies.search_placeholder')}
      />

      <Card>
        <CardContent className="p-0">
          {query ? <CompanySearchResults query={query} /> : <CompanyTreeLevel depth={0} />}
        </CardContent>
      </Card>

      {isCreating && <CreateCompanySheet open onOpenChange={(o) => !o && closeSheet()} />}
    </div>
  )
}

/**
 * One level of the tree: the roots, or a node's children when `parentId` is
 * set. Children load lazily on expand (`?q[parent_id_eq]` drives it), so a
 * large directory never loads whole.
 */
function CompanyTreeLevel({ parentId, depth }: { parentId?: string; depth: number }) {
  const { t } = useTranslation()
  const [page, setPage] = useState(1)
  const { data, isLoading } = useCompanyChildren(parentId, page)

  const companies = data?.data ?? []
  const meta = data?.meta

  if (isLoading && !data) {
    return (
      <div className="flex flex-col gap-2 p-4" style={{ paddingLeft: `${depth * 1.5 + 1}rem` }}>
        <Skeleton className="h-5 w-1/2" />
        <Skeleton className="h-5 w-1/3" />
      </div>
    )
  }

  if (companies.length === 0 && depth === 0) {
    return (
      <div className="flex flex-col items-center gap-2 p-10 text-center">
        <Building2Icon className="size-8 text-muted-foreground" />
        <p className="text-muted-foreground text-sm">{t('admin.companies.empty')}</p>
      </div>
    )
  }

  return (
    <div className="flex flex-col">
      {companies.map((company) => (
        <CompanyTreeRow key={company.id} company={company} depth={depth} />
      ))}
      {depth === 0 && meta && meta.pages > 1 && <Pagination meta={meta} onPageChange={setPage} />}
      {depth > 0 && meta && meta.pages > 1 && page < meta.pages && (
        <button
          type="button"
          className="px-6 py-2 text-left text-muted-foreground text-xs hover:text-foreground"
          style={{ paddingLeft: `${depth * 1.5 + 1.5}rem` }}
          onClick={() => setPage(page + 1)}
        >
          {t('admin.companies.load_more')}
        </button>
      )}
    </div>
  )
}

function CompanyTreeRow({ company, depth }: { company: Company; depth: number }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const [expanded, setExpanded] = useState(false)
  const hasChildren = company.children_count > 0

  return (
    <>
      <div
        className="flex items-center gap-2 border-b px-4 py-2.5 last:border-b-0 hover:bg-muted/50"
        style={{ paddingLeft: `${depth * 1.5 + 1}rem` }}
      >
        <button
          type="button"
          onClick={() => setExpanded((prev) => !prev)}
          disabled={!hasChildren}
          aria-label={
            expanded ? t('admin.companies.collapse_node') : t('admin.companies.expand_node')
          }
          aria-expanded={hasChildren ? expanded : undefined}
          className={cn(
            'flex size-5 shrink-0 items-center justify-center rounded text-muted-foreground',
            hasChildren ? 'hover:bg-muted hover:text-foreground' : 'opacity-0',
          )}
        >
          {expanded ? (
            <ChevronDownIcon className="size-4" />
          ) : (
            <ChevronRightIcon className="size-4" />
          )}
        </button>

        <Link
          to={'/$storeId/companies/$companyId' as string}
          params={{ storeId, companyId: company.id }}
          className="flex min-w-0 flex-1 items-center gap-2 no-underline"
        >
          <span className="truncate font-medium text-foreground text-sm">{company.name}</span>
          <CompanyKindBadge kind={company.kind} />
        </Link>

        <span className="shrink-0 text-muted-foreground text-xs">
          {t('admin.companies.members_count', { count: company.members_count })}
        </span>
      </div>
      {expanded && <CompanyTreeLevel parentId={company.id} depth={depth + 1} />}
    </>
  )
}

/** Flat, path-annotated results — the tree does not compose with search. */
function CompanySearchResults({ query }: { query: string }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const [page, setPage] = useState(1)
  const { data, isLoading } = useQuery({
    queryKey: useResourceKey('companies', 'search', `${query}:${page}`),
    queryFn: () => adminClient.companies.list({ page, limit: 25, name_cont: query, sort: 'name' }),
    placeholderData: (previous) => previous,
  })

  const companies = data?.data ?? []
  const meta = data?.meta

  if (isLoading && !data) {
    return (
      <div className="flex flex-col gap-2 p-4">
        <Skeleton className="h-5 w-1/2" />
      </div>
    )
  }

  if (companies.length === 0) {
    return (
      <div className="flex flex-col items-center gap-2 p-10 text-center">
        <Building2Icon className="size-8 text-muted-foreground" />
        <p className="text-muted-foreground text-sm">{t('admin.companies.search_empty')}</p>
      </div>
    )
  }

  return (
    <div className="flex flex-col">
      {companies.map((company) => (
        <Link
          key={company.id}
          to={'/$storeId/companies/$companyId' as string}
          params={{ storeId, companyId: company.id }}
          className="flex items-center gap-2 border-b px-6 py-2.5 no-underline last:border-b-0 hover:bg-muted/50"
        >
          <span className="min-w-0 flex-col">
            <span className="flex items-center gap-2">
              <span className="truncate font-medium text-foreground text-sm">{company.name}</span>
              <CompanyKindBadge kind={company.kind} />
            </span>
            {company.ancestors.length > 0 && (
              <span className="block truncate text-muted-foreground text-xs">
                {company.ancestors.map((ancestor) => ancestor.name).join(' / ')}
              </span>
            )}
          </span>
        </Link>
      ))}
      {meta && meta.pages > 1 && <Pagination meta={meta} onPageChange={setPage} />}
    </div>
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
  // page, where the parent is unambiguous.
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
