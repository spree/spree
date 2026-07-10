import type { Import, ImportRow } from '@spree/admin-sdk'
import { PageHeader } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  cn,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import {
  AlertTriangleIcon,
  CheckCircle2Icon,
  ChevronLeftIcon,
  ChevronRightIcon,
  RotateCcwIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  isImportActive,
  useCompleteMapping,
  useImport,
  useImportRows,
  useRetryFailedRows,
} from '@/hooks/use-imports'
import { importTypeIndexPath, importTypeLabel } from '@/lib/import-types'

export const Route = createFileRoute('/_authenticated/$storeId/settings/imports/$importId')({
  component: ImportWizardPage,
})

const NOT_MAPPED = '__not_mapped__'

function ImportWizardPage() {
  const { t } = useTranslation()
  const { importId, storeId } = Route.useParams()
  const { data: imp, isLoading } = useImport(importId)

  if (isLoading || !imp) {
    return (
      <div className="flex flex-col gap-4 p-4 md:p-6">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-40 w-full" />
      </div>
    )
  }

  const showFailedRows =
    imp.failed_rows_count > 0 && (isImportActive(imp.status) || imp.status === 'completed')

  return (
    <div className="flex flex-col gap-4 p-4 md:p-6">
      <PageHeader
        title={`${importTypeLabel(imp.type)} · ${imp.number}`}
        backTo={`/${storeId}/settings/imports`}
        badges={<StatusBadge status={imp.status} label={t(`admin.imports.status.${imp.status}`)} />}
      />

      <StepIndicator status={imp.status} />

      {imp.status === 'mapping' && <MappingStep imp={imp} />}
      {isImportActive(imp.status) && <ProcessingCard imp={imp} />}
      {imp.status === 'completed' && <ResultsCard imp={imp} storeId={storeId} />}
      {imp.status === 'failed' && <FailedCard imp={imp} />}
      {showFailedRows && <FailedRowsCard imp={imp} />}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Step indicator — Map fields → Process rows → Complete, mirroring the legacy
// wizard's three steps.
// ---------------------------------------------------------------------------

function StepIndicator({ status }: { status: string }) {
  const { t } = useTranslation()

  const activeIndex = status === 'mapping' ? 0 : isImportActive(status) ? 1 : 2
  const steps = ['map_fields', 'process_rows', 'complete'] as const

  return (
    <ol className="flex items-center gap-2">
      {steps.map((step, index) => (
        <li key={step} className="flex items-center gap-2">
          <span
            className={cn(
              'flex size-5 items-center justify-center rounded-full text-xs',
              index < activeIndex && 'bg-primary text-primary-foreground',
              index === activeIndex && 'bg-primary text-primary-foreground',
              index > activeIndex && 'bg-muted text-muted-foreground',
            )}
          >
            {index < activeIndex ? <CheckCircle2Icon className="size-3.5" /> : index + 1}
          </span>
          <span
            className={cn(
              'text-sm',
              index === activeIndex ? 'font-medium' : 'text-muted-foreground',
            )}
          >
            {t(`admin.imports.steps.${step}`)}
          </span>
          {index < steps.length - 1 && (
            <ChevronRightIcon className="size-4 text-muted-foreground" />
          )}
        </li>
      ))}
    </ol>
  )
}

// ---------------------------------------------------------------------------
// Mapping step
// ---------------------------------------------------------------------------

function MappingStep({ imp }: { imp: Import }) {
  const { t } = useTranslation()
  const completeMapping = useCompleteMapping(imp.id)
  const [assignments, setAssignments] = useState<Record<string, string | null>>(() =>
    Object.fromEntries(imp.mappings.map((m) => [m.schema_field, m.file_column])),
  )

  const missingRequired = imp.schema_fields.filter((f) => f.required && !assignments[f.name])

  function handleStart() {
    completeMapping.mutate({
      mappings: imp.schema_fields.map((field) => ({
        schema_field: field.name,
        file_column: assignments[field.name] ?? null,
      })),
    })
  }

  const headerOptions = (current: string | null) => [
    { value: NOT_MAPPED, label: t('admin.imports.mapping.not_mapped') },
    ...imp.csv_headers.map((header) => ({
      value: header,
      label: header,
      // A file column can feed only one field — mirror the server's
      // uniqueness validation instead of 422-ing on submit.
      disabled: header !== current && Object.values(assignments).includes(header),
    })),
  ]

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.imports.mapping.title')}</CardTitle>
        <p className="text-muted-foreground text-sm">
          {t('admin.imports.mapping.description', { type: importTypeLabel(imp.type) })}
        </p>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.imports.mapping.field')}</TableHead>
                <TableHead>{t('admin.imports.mapping.file_column')}</TableHead>
                <TableHead>{t('admin.imports.mapping.sample')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {imp.schema_fields.map((field) => {
                const current = assignments[field.name] ?? null
                const options = headerOptions(current)
                const sample = current ? (imp.sample_row[current] ?? '') : ''

                return (
                  <TableRow key={field.name}>
                    <TableCell>
                      <span className="inline-flex items-center gap-2">
                        {field.label}
                        {field.required && (
                          <Badge variant="outline">{t('admin.imports.mapping.required')}</Badge>
                        )}
                      </span>
                    </TableCell>
                    <TableCell className="w-72">
                      <Select
                        items={options}
                        value={current ?? NOT_MAPPED}
                        onValueChange={(value) =>
                          setAssignments((prev) => ({
                            ...prev,
                            [field.name]: value === NOT_MAPPED ? null : (value as string),
                          }))
                        }
                      >
                        <SelectTrigger className="w-full">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {options.map((option) => (
                            <SelectItem
                              key={option.value}
                              value={option.value}
                              disabled={'disabled' in option ? option.disabled : false}
                            >
                              {option.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </TableCell>
                    <TableCell className="max-w-48 truncate text-muted-foreground text-sm">
                      {sample}
                    </TableCell>
                  </TableRow>
                )
              })}
            </TableBody>
          </Table>
        </div>

        {missingRequired.length > 0 && (
          <p className="text-muted-foreground text-sm">
            {t('admin.imports.mapping.missing_required', {
              fields: missingRequired.map((f) => f.label).join(', '),
            })}
          </p>
        )}

        {completeMapping.isError && (
          <div className="flex items-start gap-2 rounded-md border border-destructive/40 bg-destructive/10 p-3 text-destructive text-sm">
            <AlertTriangleIcon className="size-4 shrink-0" />
            <span>
              {completeMapping.error instanceof Error
                ? completeMapping.error.message
                : String(completeMapping.error)}
            </span>
          </div>
        )}

        <div className="flex justify-end">
          <Button
            onClick={handleStart}
            disabled={missingRequired.length > 0 || completeMapping.isPending}
          >
            {completeMapping.isPending
              ? t('admin.imports.mapping.starting')
              : t('admin.imports.mapping.start')}
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Processing
// ---------------------------------------------------------------------------

function ProcessingCard({ imp }: { imp: Import }) {
  const { t } = useTranslation()

  const total = imp.rows_count
  const processed = imp.completed_rows_count + imp.failed_rows_count
  const preparing = total === 0
  // A retry pass re-processes failed rows, so every row is already terminal
  // and the bar would sit at 100% — show the shrinking failed count instead.
  const retryPass = !preparing && processed >= total && imp.failed_rows_count > 0
  const percent = preparing ? 0 : Math.min(100, Math.round((processed / total) * 100))

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.imports.processing.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <div className="h-2 w-full overflow-hidden rounded-full bg-muted">
          {preparing ? (
            <div className="h-full w-1/3 animate-pulse rounded-full bg-primary" />
          ) : (
            <div
              className="h-full rounded-full bg-primary transition-all"
              style={{ width: `${percent}%` }}
            />
          )}
        </div>

        <p className="text-sm">
          {preparing ? (
            t('admin.imports.processing.preparing')
          ) : retryPass ? (
            t('admin.imports.processing.retrying', { remaining: imp.failed_rows_count })
          ) : (
            <>
              {t('admin.imports.processing.progress', {
                processed: processed.toLocaleString(),
                total: total.toLocaleString(),
              })}
              {imp.failed_rows_count > 0 && (
                <span className="text-destructive">
                  {' · '}
                  {t('admin.imports.processing.failed_count', { failed: imp.failed_rows_count })}
                </span>
              )}
            </>
          )}
        </p>

        <p className="text-muted-foreground text-sm">{t('admin.imports.processing.note')}</p>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Results / file-level failure
// ---------------------------------------------------------------------------

function ResultsCard({ imp, storeId }: { imp: Import; storeId: string }) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const retryMutation = useRetryFailedRows(imp.id)

  return (
    <Card>
      <CardContent className="flex flex-col items-center gap-3 py-8 text-center">
        <CheckCircle2Icon className="size-10 text-success" />
        <p className="font-medium">{t('admin.imports.results.completed_title')}</p>
        <p className="text-muted-foreground text-sm">
          {t('admin.imports.results.summary', {
            completed: imp.completed_rows_count.toLocaleString(),
            failed: imp.failed_rows_count.toLocaleString(),
          })}
        </p>
        <div className="mt-2 flex items-center gap-2">
          {imp.failed_rows_count > 0 && (
            <Button
              variant="outline"
              onClick={() => retryMutation.mutate()}
              disabled={retryMutation.isPending}
            >
              <RotateCcwIcon className="size-4" />
              {retryMutation.isPending
                ? t('admin.imports.results.retrying')
                : t('admin.imports.results.retry_failed', { failed: imp.failed_rows_count })}
            </Button>
          )}
          <Button
            onClick={() => navigate({ to: importTypeIndexPath(imp.type), params: { storeId } })}
          >
            {t('admin.imports.results.view_records', { type: importTypeLabel(imp.type) })}
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

function FailedCard({ imp }: { imp: Import }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardContent className="flex flex-col items-center gap-3 py-8 text-center">
        <AlertTriangleIcon className="size-10 text-destructive" />
        <p className="font-medium">{t('admin.imports.failed.title')}</p>
        <p className="text-muted-foreground text-sm">{t('admin.imports.failed.description')}</p>
        {imp.processing_errors && (
          <code className="max-w-full overflow-x-auto rounded-md bg-muted p-3 text-left text-xs">
            {imp.processing_errors}
          </code>
        )}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Failed rows report
// ---------------------------------------------------------------------------

function FailedRowsCard({ imp }: { imp: Import }) {
  const { t } = useTranslation()
  const [page, setPage] = useState(1)
  const { data } = useImportRows(
    imp.id,
    { status_eq: 'failed', sort: 'row_number', page },
    { poll: isImportActive(imp.status) },
  )

  const rows = data?.data ?? []
  const meta = data?.meta

  if (rows.length === 0) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.imports.failed_rows.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-16">{t('admin.imports.failed_rows.row_number')}</TableHead>
                <TableHead>{t('admin.imports.failed_rows.error')}</TableHead>
                <TableHead className="w-32" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map((row) => (
                <FailedRow key={row.id} row={row} />
              ))}
            </TableBody>
          </Table>
        </div>

        {meta && meta.pages > 1 && (
          <div className="flex items-center justify-end gap-2">
            <Button
              variant="outline"
              size="sm"
              disabled={page <= 1}
              onClick={() => setPage((p) => Math.max(1, p - 1))}
            >
              <ChevronLeftIcon className="size-4" />
            </Button>
            <span className="text-muted-foreground text-sm">
              {page} / {meta.pages}
            </span>
            <Button
              variant="outline"
              size="sm"
              disabled={page >= meta.pages}
              onClick={() => setPage((p) => p + 1)}
            >
              <ChevronRightIcon className="size-4" />
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

function FailedRow({ row }: { row: ImportRow }) {
  const { t } = useTranslation()
  const [expanded, setExpanded] = useState(false)

  return (
    <>
      <TableRow>
        <TableCell className="text-muted-foreground">{row.row_number}</TableCell>
        <TableCell className="text-destructive text-sm">
          {String(row.validation_errors ?? '')}
        </TableCell>
        <TableCell className="text-right">
          <Button variant="ghost" size="sm" onClick={() => setExpanded((e) => !e)}>
            {expanded
              ? t('admin.imports.failed_rows.hide_data')
              : t('admin.imports.failed_rows.view_data')}
          </Button>
        </TableCell>
      </TableRow>
      {expanded && (
        <TableRow>
          <TableCell colSpan={3}>
            <div className="overflow-x-auto rounded-md bg-muted p-3">
              <code className="whitespace-pre-wrap text-xs">
                {JSON.stringify(row.data, null, 2)}
              </code>
            </div>
          </TableCell>
        </TableRow>
      )}
    </>
  )
}
