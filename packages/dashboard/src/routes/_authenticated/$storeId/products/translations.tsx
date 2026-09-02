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
  ProgressIndicator,
  ProgressTrack,
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
} from '@spree/dashboard-ui'
import { CheckIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useDeferredValue, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { ImportWizardDialog } from '../../../../components/spree/imports/import-wizard-dialog'
import { ResourceTranslationsDialog } from '../../../../components/spree/translations/resource-translations-dialog'
import {
  type TranslatableResourceType,
  useLocales,
  useTranslatableResources,
  useTranslationCoverage,
} from '../../../../hooks/use-translations'

const translationsSearchSchema = resourceSearchSchema.extend({
  /** Which translatable resource type the grid is showing. */
  resource: z.string().optional(),
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

  const resourceType = search.resource ?? 'product'
  const page = search.page ?? 1
  const [searchInput, setSearchInput] = useState(search.search ?? '')
  const deferredSearch = useDeferredValue(search.search ?? '')

  const { data: resources } = useTranslatableResources()
  const { data: locales } = useLocales()

  // Only resources with a dedicated read route can open the editor, so those
  // are the only ones worth listing here.
  const readable = (resources ?? []).filter((resource) => resource.readable)

  const { data, isLoading } = useTranslationCoverage(resourceType, {
    page,
    ...(deferredSearch.trim() ? { name_cont: deferredSearch.trim() } : {}),
  })

  const coverage = data?.data
  const targetLocales = coverage?.locales ?? []

  const patchSearch = (patch: Record<string, unknown>) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, ...patch }) as never })

  const localeName = (code: string) => locales?.find((l) => l.code === code)?.name ?? code

  return (
    <>
      <div className="flex flex-col gap-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <SectionHeading
            title={t('admin.translations.title')}
            description={t('admin.pages.translations.description')}
          />
          <div className="flex items-center gap-2">
            <ImportButton
              type="product_translations"
              subject={Subject.Product}
              onCreated={(imp) => patchSearch({ import: imp.id })}
            />
            <ExportButton
              type="product_translations"
              filters={[]}
              search=""
              searchParam="name_cont"
              columns={[]}
              totalCount={coverage?.coverage[0]?.total ?? 0}
            />
          </div>
        </div>

        {targetLocales.length === 0 ? (
          <Empty>
            <EmptyTitle>{t('admin.pages.translations.no_locales_title')}</EmptyTitle>
            <EmptyDescription>
              {t('admin.pages.translations.no_locales_description')}
            </EmptyDescription>
          </Empty>
        ) : (
          <>
            <Card>
              <CardHeader>
                <CardTitle>{t('admin.pages.translations.coverage')}</CardTitle>
              </CardHeader>
              <CardContent>
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
                          <TableCell className="text-center">{row.translated}</TableCell>
                          <TableCell className="text-center">{row.total}</TableCell>
                          <TableCell>
                            <div className="flex items-center gap-3">
                              <Progress value={percentage} className="flex-1">
                                <ProgressTrack>
                                  <ProgressIndicator />
                                </ProgressTrack>
                              </Progress>
                              <span className="whitespace-nowrap text-muted-foreground text-sm">
                                {percentage}%
                              </span>
                            </div>
                          </TableCell>
                        </TableRow>
                      )
                    })}
                  </TableBody>
                </Table>
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
                      patchSearch({ search: value || undefined, page: undefined })
                    }}
                    placeholder={t('admin.common.search')}
                  />
                  <Select
                    items={readable.map((r) => ({
                      value: r.resource_type,
                      label: t(`admin.pages.translations.resource_types.${r.resource_type}`, {
                        defaultValue: r.resource_type,
                      }),
                    }))}
                    value={resourceType}
                    onValueChange={(value: string) =>
                      patchSearch({ resource: value, page: undefined })
                    }
                  >
                    <SelectTrigger className="w-48">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {readable.map((r) => (
                        <SelectItem key={r.resource_type} value={r.resource_type}>
                          {t(`admin.pages.translations.resource_types.${r.resource_type}`, {
                            defaultValue: r.resource_type,
                          })}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </CardHeader>
              <CardContent>
                {isLoading ? (
                  <Skeleton className="h-48 w-full" />
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
                          <TableRow
                            key={record.id}
                            className="cursor-pointer"
                            onClick={() => patchSearch({ edit: record.id })}
                          >
                            <TableCell className="font-medium">{record.label}</TableCell>
                            {targetLocales.map((locale) => (
                              <TableCell key={locale} className="text-center">
                                <CoverageCell
                                  translated={record.locales[locale] ?? 0}
                                  total={coverage?.field_count ?? 0}
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
          </>
        )}
      </div>

      {search.edit && (
        <ResourceTranslationsDialog
          open
          onOpenChange={(open) => {
            if (!open) patchSearch({ edit: undefined })
          }}
          resourceType={resourceType as TranslatableResourceType}
          resourceId={search.edit}
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
  if (translated === 0) return <span className="text-muted-foreground">&mdash;</span>

  if (translated >= total) {
    return <CheckIcon className="mx-auto size-4 text-green-600" aria-label="complete" />
  }

  return (
    <Badge variant="secondary">
      {translated}/{total}
    </Badge>
  )
}
