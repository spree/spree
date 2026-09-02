import {
  ExportButton,
  ImportButton,
  resourceSearchSchema,
  SectionHeading,
  Subject,
} from '@spree/dashboard-core'
import {
  Badge,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Empty,
  EmptyDescription,
  EmptyTitle,
  Pagination,
  Progress,
  ResourceNameCell,
  SearchInput,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { CheckIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useDeferredValue, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { ImportWizardDialog } from '../../../../components/spree/imports/import-wizard-dialog'
import { ResourceTranslationsDialog } from '../../../../components/spree/translations/resource-translations-dialog'
import {
  isTranslatableResourceType,
  useLocaleName,
  useTranslatableResources,
  useTranslationCoverage,
} from '../../../../hooks/use-translations'

const translationsSearchSchema = resourceSearchSchema.extend({
  /** Which translatable resource type the grid is showing. */
  resource: z.string().optional().default('product'),
  /** Prefixed id of the record whose editor is open. */
  edit: z.string().optional(),
  import: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/products/translations')({
  validateSearch: translationsSearchSchema,
  component: TranslationsPage,
})

function TranslationsPage() {
  const { t } = useTranslation()
  const navigate = useNavigate({ from: Route.fullPath })
  const search = Route.useSearch()
  const localeName = useLocaleName()

  const { page } = search
  // The URL is user-supplied: an unknown or non-editable `?resource=` would
  // otherwise reach the accessor map and throw inside the dialog's queryFn.
  const resourceType = isTranslatableResourceType(search.resource) ? search.resource : 'product'

  // The term is local state, never a URL param: writing it on each keystroke
  // re-renders the route component, which remounts the input and takes focus
  // away mid-word. Deferring it lets React coalesce fast typing into one
  // fetch, and only what reads `deferredSearch` re-renders.
  const [searchInput, setSearchInput] = useState(search.search ?? '')
  const deferredSearch = useDeferredValue(searchInput)

  const { data: resources } = useTranslatableResources()

  // A type needs both a dedicated read route and an SDK accessor before the
  // editor can open it — the registry reports the first, the type guard the
  // second. Offering a type without an accessor would open a dialog that
  // throws when it tries to fetch.
  const resourceOptions = (resources ?? [])
    .filter((resource) => resource.readable && isTranslatableResourceType(resource.resource_type))
    .map((resource) => ({
      value: resource.resource_type,
      label: t(`admin.pages.translations.resource_types.${resource.resource_type}`, {
        defaultValue: resource.resource_type,
      }),
    }))

  // A plain term rather than a predicate the client picks: which column to
  // match varies by resource type (an option type is displayed by
  // `presentation`, not `name`), and only the server knows which.
  const trimmedSearch = deferredSearch.trim()
  const coverageParams = useMemo(
    () => ({ page, ...(trimmedSearch ? { search: trimmedSearch } : {}) }),
    [page, trimmedSearch],
  )
  const { data, isLoading, isError } = useTranslationCoverage(resourceType, coverageParams)

  const coverage = data?.data
  const targetLocales = coverage?.locales ?? []
  const fieldCount = coverage?.field_count ?? 0

  const patchSearch = (patch: Record<string, unknown>, options?: { replace?: boolean }) =>
    navigate({
      search: (prev: Record<string, unknown>) => ({ ...prev, ...patch }) as never,
      replace: options?.replace,
    })

  // Only open the editor for a record the current grid actually lists. A URL
  // carrying an `edit` id from another resource type — a link shared after
  // switching types, or a hand-edited address — would otherwise open a dialog
  // that fetches an id its endpoint has never heard of.
  const editId = coverage?.records.some((record) => record.id === search.edit)
    ? search.edit
    : undefined

  useRowClickBridge('data-translation-record-id', (id: string) => patchSearch({ edit: id }))

  return (
    <>
      <div className="flex flex-col gap-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <SectionHeading
            title={t('admin.translations.title')}
            description={t('admin.pages.translations.description')}
          />
          {/* CSV covers product translations only, so the buttons appear on
              the products view rather than implying they would export
              whichever resource type the grid happens to be showing. */}
          {resourceType === 'product' && (
            <div className="flex items-center gap-2">
              <ImportButton
                type="product_translations"
                subject={Subject.Product}
                onCreated={(imp) => patchSearch({ import: imp.id })}
              />
              {/* `meta.count` follows the search, unlike the coverage totals,
                  which are deliberately store-wide — so the confirm dialog
                  reports the number of rows the file will actually contain. */}
              <ExportButton
                type="product_translations"
                filters={[]}
                search={deferredSearch}
                searchParam="name_cont"
                columns={[]}
                totalCount={data?.meta?.count}
              />
            </div>
          )}
        </div>

        {/* The cards and their headers stay mounted through every state, so
            the search box the merchant is typing in is never unmounted — only
            each card's content switches. */}
        <Card>
          <CardHeader>
            <CardTitle>{t('admin.pages.translations.coverage')}</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            {isError ? (
              <p className="px-6 py-10 text-center text-muted-foreground text-sm">
                {t('admin.pages.translations.load_error')}
              </p>
            ) : isLoading ? (
              <div className="px-6 py-6">
                <Skeleton className="h-28 w-full" />
              </div>
            ) : targetLocales.length === 0 ? (
              <Empty className="py-10">
                <EmptyTitle>{t('admin.pages.translations.no_locales_title')}</EmptyTitle>
                <EmptyDescription>
                  {t('admin.pages.translations.no_locales_description')}
                </EmptyDescription>
              </Empty>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t('admin.translations.locale')}</TableHead>
                    <TableHead className="text-center">
                      {t('admin.pages.translations.translated')}
                    </TableHead>
                    <TableHead className="text-center">
                      {t('admin.pages.translations.total')}
                    </TableHead>
                    <TableHead className="w-2/5">
                      {t('admin.pages.translations.progress')}
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {(coverage?.coverage ?? []).map((row) => {
                    const percentage = Math.round(row.coverage * 100)

                    return (
                      <TableRow key={row.locale}>
                        <TableCell>
                          <span className="font-medium">{localeName(row.locale)}</span>
                          <span className="ml-2 text-muted-foreground">{row.locale}</span>
                        </TableCell>
                        <TableCell className="text-center tabular-nums">{row.translated}</TableCell>
                        <TableCell className="text-center tabular-nums">{row.total}</TableCell>
                        <TableCell>
                          <div className="flex items-center gap-3">
                            <Progress value={percentage} className="flex-1" />
                            <span className="whitespace-nowrap text-muted-foreground text-sm tabular-nums">
                              {percentage}%
                            </span>
                          </div>
                        </TableCell>
                      </TableRow>
                    )
                  })}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row flex-wrap items-center justify-between gap-3 space-y-0">
            <CardTitle>{t('admin.pages.translations.records')}</CardTitle>
            <div className="flex items-center gap-2">
              <SearchInput
                value={searchInput}
                onValueChange={(value: string) => {
                  setSearchInput(value)
                  // A narrowed list rarely has the page the merchant was on;
                  // only touch the URL when there is one to leave.
                  if (page !== 1) patchSearch({ page: 1 }, { replace: true })
                }}
                placeholder={t('admin.common.search_placeholder')}
              />
              <Select
                items={resourceOptions}
                value={resourceType}
                onValueChange={(value: string) =>
                  patchSearch({ resource: value, page: 1, edit: undefined })
                }
              >
                {/* Sized to its content rather than a fixed width: a two-word
                    label ("Option types") wraps in a narrow trigger and grows
                    it taller than the search field beside it. */}
                <SelectTrigger className="w-auto min-w-40 whitespace-nowrap">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {resourceOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            {isError ? (
              <p className="px-6 py-10 text-center text-muted-foreground text-sm">
                {t('admin.pages.translations.load_error')}
              </p>
            ) : isLoading ? (
              <div className="px-6 py-6">
                <Skeleton className="h-40 w-full" />
              </div>
            ) : (
              <>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t('admin.pages.translations.record')}</TableHead>
                      {targetLocales.map((locale) => (
                        <TableHead key={locale} className="text-center">
                          {locale}
                        </TableHead>
                      ))}
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {(coverage?.records ?? []).map((record) => (
                      <TableRow key={record.id} className="cursor-pointer">
                        <TableCell>
                          <ResourceNameCell
                            id={record.id}
                            dataAttr="data-translation-record-id"
                            name={record.label ?? record.id}
                          />
                        </TableCell>
                        {targetLocales.map((locale) => (
                          <TableCell key={locale} className="text-center">
                            <CoverageCell
                              translated={record.locales[locale] ?? 0}
                              total={fieldCount}
                            />
                          </TableCell>
                        ))}
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
                {data?.meta && (
                  <Pagination
                    meta={data.meta}
                    onPageChange={(next: number) => patchSearch({ page: next })}
                  />
                )}
              </>
            )}
          </CardContent>
        </Card>
      </div>

      {editId && (
        <ResourceTranslationsDialog
          open
          onOpenChange={(open) => {
            if (!open) patchSearch({ edit: undefined })
          }}
          resourceType={resourceType}
          resourceId={editId}
        />
      )}

      <ImportWizardDialog
        importId={search.import ?? null}
        onClose={() => patchSearch({ import: undefined })}
      />
    </>
  )
}

/**
 * How much of one record is translated for one locale: a check at 100%, the
 * count while partial, a dash at zero.
 */
function CoverageCell({ translated, total }: { translated: number; total: number }) {
  const { t } = useTranslation()

  if (translated === 0) return <span className="text-muted-foreground">&mdash;</span>

  if (translated >= total) {
    return (
      <CheckIcon
        className="mx-auto size-4 text-green-600"
        aria-label={t('admin.pages.translations.complete')}
      />
    )
  }

  return (
    <Badge variant="secondary">
      {translated}/{total}
    </Badge>
  )
}
